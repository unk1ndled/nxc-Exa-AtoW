import logging
import os
import shlex
from base64 import b64decode, b64encode
from pathlib import Path
from tempfile import TemporaryDirectory
from time import monotonic, sleep

import ebstemplate.scheduler.job_template as scheduler_job_module
from ebcommon.models_job import JobRunStatusEnum
from ebsclient import EbClientAPI, RuntimeJobError, RuntimeService
from ebstemplate.hpc.remote import RemoteExecutor
from ebstemplate.scheduler import ClientSchedulerTemplate, JobSchedulerTemplate
from ebstemplate.scheduler.shared import PIPELINE_TERMINAL
from remotemanager import URL


ROOT = Path(__file__).resolve().parent
TAG = "nxc-minimal-e2e"
E2E_TIMEOUT = int(os.getenv("E2E_TIMEOUT", "180"))


class TunnelRemoteExecutor(RemoteExecutor):
    """Adapt the upstream executor to the local NXC frontend tunnel."""

    def __init__(self, hpc_config):
        self.hpc_config = hpc_config
        self.url = URL(
            host=hpc_config.ssh_host,
            user=hpc_config.ssh_user,
            port=2222,
            keyfile=os.environ["NXC_IDENTITY_FILE"],
            passfile=hpc_config.passfile,
            shell="bash",
            ssh_insert=" ".join(
                (
                    "-o HostName=127.0.0.1",
                    "-o IdentitiesOnly=yes",
                    "-o StrictHostKeyChecking=no",
                    "-o UserKnownHostsFile=/dev/null",
                )
            ),
        )

    def write_file(self, path, content: str) -> bool:
        # The upstream heredoc crosses nested local and SSH shells. Encoding the
        # E2E script prevents its substitutions from running during transfer.
        target = shlex.quote(str(path))
        encoded = b64encode(content.encode()).decode("ascii")
        result = self.run(
            f"printf %s {shlex.quote(encoded)} | base64 -d > {target}",
            timeout=self.hpc_config.submit_timeout,
        )
        if result.returncode != 0:
            logging.error("could not write remote E2E script: %s", result.stderr)
            return False
        return True


# JobSchedulerTemplate resolves this module global when each job is created.
scheduler_job_module.RemoteExecutor = TunnelRemoteExecutor


class MinimalMpiJob(JobSchedulerTemplate):
    """Submit one MPI rank per compute node and verify both ranks in SLURM."""

    def get_scheduler_core(self) -> str:
        output_file = shlex.quote(str(self.job_dir / "mpi-hello.out"))
        return (
            'output=$(srun --mpi=pmix mpi-hello) && '
            f'printf "%s\\n" "$output" > {output_file} && '
            'test "$(printf "%s\\n" "$output" | grep -c "Hello from rank")" -eq 2 && '
            'printf "%s\\n" "$output" | grep -q "rank 0 of 2" && '
            'printf "%s\\n" "$output" | grep -q "rank 1 of 2"'
        )

    def execute(self) -> None:
        script = self.job_dir / self.script_name
        result = self.remote.run(
            f"sbatch --wait {script}",
            timeout=self.hpc_config.submit_timeout,
        )
        if result.returncode != 0:
            raise RuntimeJobError(
                f"SLURM job failed (rc={result.returncode}): {result.stderr}"
            )

    def eboutput(self, index: int, ebout_name: str, ebout: str) -> None:
        source = shlex.quote(str(self.job_dir / ebout_name))
        result = self.remote.run(
            f"base64 -w0 {source}",
            timeout=self.hpc_config.submit_timeout,
        )
        if result.returncode != 0:
            raise RuntimeJobError(f"could not fetch {ebout_name}: {result.stderr}")
        self.api.buffers.get(ebout).fill(b64decode(result.stdout))


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    api = EbClientAPI(
        username=os.getenv("EB_USERNAME", "admin"),
        password=os.getenv("EB_PASSWORD", "admin"),
        ebservice_url="http://localhost:8001/api/v1",
        ebuffer_url="http://localhost:8000/api/v1",
    )

    microservice = None
    runtime = None
    service = None
    client = None
    buffer_uuids = []
    try:
        microservice = api.mservices.create(
            {
                "name": "nxc-minimal-mpi",
                "mime_type": "application/x-nxc-minimal-mpi",
                "code": "",
                "argument_names": [],
                "result_names": [],
                "ebin_names": [],
                "ebout_names": ["mpi-hello.out"],
                "runtime_uuid": "",
                "policy_uid": "",
                "tags": ["template::slurm", TAG],
            }
        )
        runtime = api.runtimes.create(
            {
                "name": "nxc-minimal-slurm",
                "accepted_mime_type": "application/x-nxc-minimal-mpi",
                "policy_uid": "",
                "tags": ["template::slurm", TAG],
            }
        )
        service = RuntimeService(
            runtime=runtime,
            RuntimeJobType=MinimalMpiJob,
            hpc_config=os.getenv("E2E_HPC_CONFIG", ROOT / "minimal-hpc.ini"),
            job_config=ROOT / "minimal-job.ini",
            polltime=1,
            keep_going=False,
            max_workers=1,
        )
        service.start()

        client = ClientSchedulerTemplate(api, microservice.uuid)
        client.monitoring_poll_interval = 1
        client.set_inputs(args=[], ebin_files=[])
        client.submit()
        buffer_uuids = [client.seb._buffer.uuid, *client.ebout_uuid]
        deadline = monotonic() + E2E_TIMEOUT
        previous_status = None
        while monotonic() < deadline:
            if service.critical_error is not None:
                raise RuntimeError("runtime service failed") from service.critical_error
            if not service.is_alive():
                raise RuntimeError("runtime service stopped before the job completed")

            status = client.get_status()
            if status != previous_status:
                print(status.name.upper())
                previous_status = status
            if status in PIPELINE_TERMINAL:
                break
            sleep(client.monitoring_poll_interval)
        else:
            raise TimeoutError(f"E2E job did not finish within {E2E_TIMEOUT} seconds")

        if status != JobRunStatusEnum.completed:
            raise RuntimeError(f"E2E job finished with {status.name}")

        with TemporaryDirectory(prefix="nxc-e2e-output-") as output_dir:
            client.download_data(output_dir)
            returned_output = (Path(output_dir) / "mpi-hello.out").read_text()

        if returned_output.count("Hello from rank") != 2:
            raise RuntimeError("output ebuffer did not return both MPI ranks")
        if "rank 0 of 2" not in returned_output or "rank 1 of 2" not in returned_output:
            raise RuntimeError("output ebuffer contains unexpected MPI rank data")

        output_buffer = api.buffers.get(client.ebout_uuid[0])
        print("E2E passed: API registration -> runtime -> SLURM -> two MPI ranks")
        print(f"Scheduler ebuffer: {client.seb._buffer.uuid}")
        print(f"Output ebuffer:    {output_buffer.uuid} ({output_buffer.size} bytes)")
        print("Returned mpi-hello.out:")
        print(returned_output.rstrip())
    finally:
        if service is not None:
            service.stop()
            service.join(timeout=15)
        if client is not None and client.job is not None:
            try:
                client.job.delete()
            except Exception:
                logging.exception("could not delete E2E job")
        for buffer_uuid in buffer_uuids:
            try:
                api.buffers.delete(buffer_uuid)
            except Exception:
                logging.exception("could not delete E2E buffer %s", buffer_uuid)
        for resource in (runtime, microservice):
            if resource is not None:
                try:
                    resource.delete()
                except Exception:
                    logging.exception("could not delete E2E resource")


if __name__ == "__main__":
    main()
