import logging
import os
import re
import shlex
from base64 import b64decode, b64encode
from binascii import Error as BinasciiError
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryDirectory
from time import monotonic, sleep, time

import ebstemplate.scheduler.job_template as scheduler_job_module
from ebcommon.models_job import JobRunStatusEnum
from ebsclient import EbClientAPI, RuntimeJobError, RuntimeService
from ebstemplate.hpc.remote import RemoteExecutor
from ebstemplate.scheduler import ClientSchedulerTemplate, JobSchedulerTemplate
from ebstemplate.scheduler.shared import PIPELINE_TERMINAL
from remotemanager import URL


ROOT = Path(__file__).resolve().parent
TAG = "nxc-e2e"
TEMPLATE_TAG = "template::slurm"

SLURM_TERMINAL_STATES = {
    "BOOT_FAIL",
    "CANCELLED",
    "COMPLETED",
    "DEADLINE",
    "FAILED",
    "NODE_FAIL",
    "OUT_OF_MEMORY",
    "PREEMPTED",
    "REVOKED",
    "SPECIAL_EXIT",
    "TIMEOUT",
}


@dataclass(frozen=True)
class E2EApplication:
    """Contract implemented by each application-specific E2E module."""

    name: str
    microservice_name: str
    mime_type: str
    job_config: Path
    input_files: tuple[Path, ...]
    output_name: str
    diagnostic_files: tuple[str, ...]
    default_timeout: int
    success_message: str
    scheduler_core: Callable[[Path, Path], str]
    validate_output: Callable[[str], tuple[str, ...]]

    @property
    def input_names(self) -> tuple[str, ...]:
        return tuple(path.name for path in self.input_files)


class TunnelRemoteExecutor(RemoteExecutor):
    """Adapt the upstream executor to the local NXC frontend tunnel."""

    def __init__(self, hpc_config):
        self.hpc_config = hpc_config
        identity_file = str(Path(os.environ["NXC_IDENTITY_FILE"]).expanduser().resolve())
        ssh_command = shlex.join(
            (
                "ssh",
                "-q",
                "-o",
                "HostName=127.0.0.1",
                "-o",
                "IdentitiesOnly=yes",
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "UserKnownHostsFile=/dev/null",
                "-p",
                "2222",
                "-i",
                identity_file,
                f"{hpc_config.ssh_user}@{hpc_config.ssh_host}",
            )
        )
        self.url = URL(
            host=hpc_config.ssh_host,
            user=hpc_config.ssh_user,
            port=2222,
            shell="bash",
            max_timeouts=1,
            ssh_override=ssh_command,
        )

    def write_bytes(self, path, content: bytes) -> bool:
        """Write bytes through the working SSH command channel."""
        target = shlex.quote(str(path))
        encoded = b64encode(content).decode("ascii")
        result = self.run(
            f"printf %s {shlex.quote(encoded)} | base64 -d > {target}",
            timeout=self.hpc_config.submit_timeout,
        )
        if result.returncode != 0:
            logging.error("could not write remote file %s: %s", path, result.stderr)
            return False
        return True

    def write_file(self, path, content: str) -> bool:
        # The upstream heredoc crosses nested local and SSH shells. Encoding the
        # E2E script prevents its substitutions from running during transfer.
        return self.write_bytes(path, content.encode())


# JobSchedulerTemplate resolves this module global when each job is created.
scheduler_job_module.RemoteExecutor = TunnelRemoteExecutor


class ApplicationJob(JobSchedulerTemplate):
    """Shared RemoteManager/SLURM lifecycle for an application contract."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        application = self.context.get("application")
        if not isinstance(application, E2EApplication):
            raise ValueError("runtime context does not contain an E2E application")
        self.application = application
        self._scheduler_terminal = False
        self._submission_attempted = False

    def run(self) -> bool:
        """Run the SDK lifecycle and always finalize the remote job directory."""
        succeeded = False
        try:
            succeeded = super().run()
            return succeeded
        finally:
            if not succeeded and self.job_dir is not None:
                diagnostics = self._diagnostics()
                if diagnostics:
                    logging.error("remote diagnostics before cleanup:\n%s", diagnostics)
            self._cleanup_remote_job_dir()

    def ebinput(self, index: int, ebin_name: str, ebin: str) -> None:
        try:
            expected_name = self.application.input_names[index]
        except IndexError as error:
            raise RuntimeJobError(f"unexpected input ebuffer {ebin_name}") from error
        if ebin_name != expected_name:
            raise RuntimeJobError(
                f"input ebuffer {index} is named {ebin_name!r}, expected {expected_name!r}"
            )

        destination = self.job_dir / ebin_name
        try:
            content = self.api.buffers.get(ebin).fetch()
        except Exception as error:
            raise RuntimeJobError(f"could not fetch {ebin_name}: {error}") from error
        if not isinstance(content, bytes):
            raise RuntimeJobError(f"ebuffer returned non-binary data for {ebin_name}")
        if not self.remote.write_bytes(destination, content):
            raise RuntimeJobError(f"could not stage {ebin_name} on the frontend")

    def get_scheduler_core(self) -> str:
        if not self.job_config.app_name:
            raise RuntimeJobError("application name is missing from the job configuration")
        executable = Path(self.app_dir) / self.job_config.app_name
        return self.application.scheduler_core(Path(self.job_dir), executable)

    def _diagnostics(self) -> str:
        sections = []
        names = (
            "job_main_error.err",
            "job_main_output.out",
            "STARTUP_ERROR",
            *self.application.diagnostic_files,
        )
        for name in dict.fromkeys(names):
            path = shlex.quote(str(self.job_dir / name))
            try:
                result = self.remote.run(
                    f"tail -n 80 {path}",
                    timeout=self.hpc_config.quick_timeout,
                )
            except Exception as error:
                logging.warning("could not read remote diagnostic %s: %s", name, error)
                continue
            output = result.stdout or ""
            if result.returncode == 0 and output.strip():
                sections.append(f"--- {name} ---\n{output.strip()}")
        return "\n".join(sections)

    def _write_scheduler_info(self, state: str, exit_code: str | None = None) -> None:
        try:
            self.seb.write_info(
                {
                    "last_update": {
                        "set": True,
                        "infinite": False,
                        "number": int(time()),
                    },
                    "job_state": [state],
                    "job_id": int(self.scheduler_job_id),
                    "exit_code": exit_code,
                    "errors": [],
                    "warnings": [],
                }
            )
        except Exception as error:
            raise RuntimeJobError(
                f"could not update scheduler ebuffer for job {self.scheduler_job_id}: {error}"
            ) from error

    def _wait_for_scheduler_terminal(self) -> bool:
        if self.scheduler_job_id is None or self._scheduler_terminal:
            return True

        job_id = shlex.quote(str(self.scheduler_job_id))
        deadline = monotonic() + self.hpc_config.quick_timeout
        while monotonic() < deadline:
            try:
                status = self.remote.run(
                    f"scontrol show job --oneliner {job_id}",
                    timeout=self.hpc_config.quick_timeout,
                )
            except Exception as error:
                logging.error(
                    "could not confirm SLURM job %s termination: %s",
                    self.scheduler_job_id,
                    error,
                )
                return False

            status_output = status.stdout or ""
            if status.returncode != 0:
                if "invalid job id" in f"{status_output}\n{status.stderr}".lower():
                    self._scheduler_terminal = True
                    return True
                logging.error(
                    "could not confirm SLURM job %s termination: %s",
                    self.scheduler_job_id,
                    status.stderr,
                )
                return False

            state_match = re.search(r"\bJobState=(\S+)", status_output)
            exit_match = re.search(r"\bExitCode=(\S+)", status_output)
            state = state_match.group(1).upper().rstrip("+") if state_match else None
            exit_code = exit_match.group(1) if exit_match else None
            if state is not None:
                try:
                    self._write_scheduler_info(state, exit_code)
                except RuntimeJobError as error:
                    logging.warning("%s", error)
            if state in SLURM_TERMINAL_STATES:
                self._scheduler_terminal = True
                return True
            sleep(min(self.hpc_config.poll_interval, 1))
        return False

    def _cancel_scheduler_job(self) -> bool:
        if self.scheduler_job_id is None:
            return True
        if self._scheduler_terminal:
            return True
        job_id = shlex.quote(str(self.scheduler_job_id))
        try:
            result = self.remote.run(
                f"{self.hpc_config.cancel_cmd} {job_id}",
                timeout=self.hpc_config.quick_timeout,
            )
        except Exception as error:
            logging.error("could not cancel SLURM job %s: %s", self.scheduler_job_id, error)
            return False
        if result.returncode != 0:
            logging.error(
                "could not cancel SLURM job %s: %s",
                self.scheduler_job_id,
                result.stderr,
            )
            return False
        return self._wait_for_scheduler_terminal()

    def _cleanup_remote_job_dir(self) -> None:
        if self.job_dir is None:
            return
        if self._submission_attempted and self.scheduler_job_id is None:
            logging.warning(
                "retaining remote job directory %s because SLURM submission "
                "was attempted but no job id was recovered",
                self.job_dir,
            )
            return
        if self.scheduler_job_id is not None and not self._scheduler_terminal:
            if not self._cancel_scheduler_job():
                logging.warning(
                    "retaining remote job directory %s because SLURM termination "
                    "could not be confirmed",
                    self.job_dir,
                )
                return

        job_dir = shlex.quote(str(self.job_dir))
        try:
            cleanup = self.remote.run(
                f"rm -rf -- {job_dir}",
                timeout=self.hpc_config.quick_timeout,
            )
        except Exception as error:
            logging.warning("could not remove remote job directory %s: %s", self.job_dir, error)
            return
        if cleanup.returncode != 0:
            logging.warning("could not remove remote job directory %s", self.job_dir)

    def on_stop(self) -> None:
        self._cancel_scheduler_job()

    def execute(self) -> None:
        script = shlex.quote(str(self.job_dir / self.script_name))
        job_dir = shlex.quote(str(self.job_dir))
        self._submission_attempted = True
        try:
            result = self.remote.run(
                f"{self.hpc_config.submit_cmd} --parsable --chdir={job_dir} {script}",
                timeout=self.hpc_config.quick_timeout,
            )
        except Exception as error:
            raise RuntimeJobError(
                f"SLURM submission outcome is unknown: {error}"
            ) from error
        if result.returncode != 0:
            raise RuntimeJobError(
                f"SLURM submission failed (rc={result.returncode}): {result.stderr}"
            )

        submit_output = result.stdout or ""
        job_match = re.fullmatch(r"\s*(\d+)(?:;[^\s;]+)?\s*", submit_output)
        if job_match is None:
            raise RuntimeJobError(f"could not parse SLURM job id from {submit_output!r}")
        job_id = job_match.group(1)
        self.scheduler_job_id = job_id

        deadline = monotonic() + self.hpc_config.submit_timeout
        try:
            while monotonic() < deadline:
                if self.is_stopping():
                    self._cancel_scheduler_job()
                    return
                if self._pipeline_cancelled():
                    logging.info("pipeline job %s was cancelled by the client", self.job.uuid)
                    self._cancel_scheduler_job()
                    self._stop_event.set()
                    return

                status = self.remote.run(
                    f"scontrol show job --oneliner {job_id}",
                    timeout=self.hpc_config.quick_timeout,
                )
                if status.returncode != 0:
                    self._cancel_scheduler_job()
                    diagnostics = self._diagnostics()
                    raise RuntimeJobError(
                        f"could not query SLURM job {job_id}: {status.stderr}"
                        f"\n{diagnostics}"
                    )

                status_output = status.stdout or ""
                state_match = re.search(r"\bJobState=(\S+)", status_output)
                exit_match = re.search(r"\bExitCode=(\S+)", status_output)
                if state_match is None:
                    self._cancel_scheduler_job()
                    diagnostics = self._diagnostics()
                    raise RuntimeJobError(
                        f"could not parse SLURM job {job_id} state from {status_output!r}"
                        f"\n{diagnostics}"
                    )

                state = state_match.group(1).upper().rstrip("+")
                exit_code = exit_match.group(1) if exit_match else None
                self._write_scheduler_info(state, exit_code)
                if state in SLURM_TERMINAL_STATES:
                    self._scheduler_terminal = True
                    if state == "COMPLETED" and exit_code == "0:0":
                        return
                    diagnostics = self._diagnostics()
                    raise RuntimeJobError(
                        f"SLURM job {job_id} ended in {state} "
                        f"(exit {exit_code})\n{diagnostics}"
                    )
                self.interruptible_sleep(self.hpc_config.poll_interval)
        except RuntimeJobError:
            raise
        except Exception as error:
            self._cancel_scheduler_job()
            diagnostics = self._diagnostics()
            raise RuntimeJobError(
                f"could not monitor SLURM job {job_id}: {error}\n{diagnostics}"
            ) from error

        self._cancel_scheduler_job()
        diagnostics = self._diagnostics()
        raise RuntimeJobError(
            f"SLURM job {job_id} exceeded {self.hpc_config.submit_timeout} seconds"
            f"\n{diagnostics}"
        )

    def eboutput(self, index: int, ebout_name: str, ebout: str) -> None:
        if index != 0 or ebout_name != self.application.output_name:
            raise RuntimeJobError(f"unexpected output ebuffer {index}: {ebout_name}")

        source = shlex.quote(str(self.job_dir / ebout_name))
        result = self.remote.run(
            f"base64 -w0 {source}",
            timeout=self.hpc_config.submit_timeout,
        )
        if result.returncode != 0:
            raise RuntimeJobError(f"could not fetch {ebout_name}: {result.stderr}")
        try:
            content = b64decode(result.stdout or "", validate=True)
        except (BinasciiError, ValueError) as error:
            raise RuntimeJobError(f"could not decode {ebout_name}: {error}") from error
        if not self.api.buffers.get(ebout).fill(content):
            raise RuntimeJobError(f"could not fill output ebuffer for {ebout_name}")


class TrackedClientSchedulerTemplate(ClientSchedulerTemplate):
    """Track each created ebuffer before an optional initial fill can fail."""

    def __init__(self, *args, tracked_buffer_uuids: list[str], **kwargs):
        super().__init__(*args, **kwargs)
        self._tracked_buffer_uuids = tracked_buffer_uuids

    def _create_ebuffer(self, size: int, path_file=None):
        buffer = super()._create_ebuffer(size=size, path_file=None)
        self._tracked_buffer_uuids.append(buffer.uuid)
        if path_file:
            buffer.fill(path_file)
        return buffer


def stop_runtime_service(service: RuntimeService) -> None:
    """Stop the SDK service and wait for its nested runner and job threads."""
    service.stop()
    service.join(timeout=20)

    with service._ms_lock:
        runners = list(service.active_ms.values())
    for runner in runners:
        runner.stop()
    for runner in runners:
        if runner.is_alive():
            runner.join(timeout=20)

    workers = []
    for runner in runners:
        with runner._jobs_lock:
            workers.extend(runner.active_jobs.values())
    for worker in workers:
        if worker.is_alive():
            worker.join(timeout=20)

    live_threads = []
    if service.is_alive():
        live_threads.append(service.name)
    live_threads.extend(runner.name for runner in runners if runner.is_alive())
    live_threads.extend(worker.name for worker in workers if worker.is_alive())
    if live_threads:
        raise RuntimeError(
            "runtime did not become quiescent; refusing API cleanup while these "
            f"threads are active: {', '.join(live_threads)}"
        )


def e2e_timeout(application: E2EApplication) -> int:
    value = int(os.getenv("E2E_TIMEOUT", str(application.default_timeout)))
    if value <= 0:
        raise ValueError("E2E_TIMEOUT must be greater than zero")
    return value


def job_status_description(client: ClientSchedulerTemplate) -> str | None:
    try:
        client.job.refresh()
        _, description = client.job.run_status
        return description
    except Exception:
        logging.exception("could not read the failed E2E job description")
        return None


def validate_scheduler_info(client: ClientSchedulerTemplate) -> int:
    """Require the scheduler ebuffer to contain a successful terminal record."""
    info = client.seb.last_info()
    states = info.get("job_state")
    state = states[-1].upper() if states else None
    if state != "COMPLETED" or info.get("exit_code") != "0:0":
        raise RuntimeError(f"scheduler ebuffer has no successful terminal record: {info}")

    job_id = info.get("job_id")
    if not isinstance(job_id, int) or job_id <= 0:
        raise RuntimeError(f"scheduler ebuffer has an invalid job id: {job_id!r}")

    last_update = info.get("last_update")
    if (
        not isinstance(last_update, dict)
        or not last_update.get("set")
        or last_update.get("infinite")
        or not isinstance(last_update.get("number"), int)
    ):
        raise RuntimeError(f"scheduler ebuffer has an invalid timestamp: {last_update!r}")
    return job_id


def run_e2e(application: E2EApplication) -> None:
    """Run one application contract through the shared API/SLURM workflow."""
    timeout = e2e_timeout(application)

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
    app_tag = f"e2e-app::{application.name}"
    try:
        microservice = api.mservices.create(
            {
                "name": application.microservice_name,
                "mime_type": application.mime_type,
                "code": "",
                "argument_names": [],
                "result_names": [],
                "ebin_names": list(application.input_names),
                "ebout_names": [application.output_name],
                "runtime_uuid": "",
                "policy_uid": "",
                "tags": [TEMPLATE_TAG, TAG, app_tag],
            }
        )
        runtime = api.runtimes.create(
            {
                "name": f"nxc-e2e-{application.name}-slurm",
                "accepted_mime_type": application.mime_type,
                "policy_uid": "",
                "tags": [TEMPLATE_TAG, TAG, app_tag],
            }
        )
        service = RuntimeService(
            runtime=runtime,
            RuntimeJobType=ApplicationJob,
            hpc_config=os.getenv("E2E_HPC_CONFIG", ROOT / "minimal-hpc.ini"),
            job_config=application.job_config,
            context={"application": application},
            polltime=1,
            keep_going=False,
            max_workers=1,
        )
        service.start()

        client = TrackedClientSchedulerTemplate(
            api,
            microservice.uuid,
            tracked_buffer_uuids=buffer_uuids,
        )
        client.monitoring_poll_interval = 1
        client.set_inputs(args=[], ebin_files=list(application.input_files))
        buffer_uuids.extend(client.ebin_uuid)
        client.submit()
        buffer_uuids.extend([client.seb._buffer.uuid, *client.ebout_uuid])
        deadline = monotonic() + timeout
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
            raise TimeoutError(
                f"{application.name} E2E job did not finish within {timeout} seconds"
            )

        if status != JobRunStatusEnum.completed:
            description = job_status_description(client)
            suffix = f": {description}" if description else ""
            raise RuntimeError(f"E2E job finished with {status.name}{suffix}")

        with TemporaryDirectory(prefix=f"nxc-e2e-{application.name}-output-") as output_dir:
            client.download_data(output_dir)
            returned_output = (Path(output_dir) / application.output_name).read_text()

        summary_lines = application.validate_output(returned_output)
        scheduler_job_id = validate_scheduler_info(client)

        output_buffer = api.buffers.get(client.ebout_uuid[0])
        print(f"E2E passed: {application.success_message}")
        for line in summary_lines:
            print(line)
        print(f"Scheduler job:     {scheduler_job_id}")
        print(f"Scheduler ebuffer: {client.seb._buffer.uuid} (COMPLETED, exit 0:0)")
        print(f"Output ebuffer:    {output_buffer.uuid} ({output_buffer.size} bytes)")
        print(f"Returned {application.output_name}:")
        print(returned_output.rstrip())
    finally:
        if service is not None:
            stop_runtime_service(service)
        if client is not None:
            buffer_uuids.extend(client.ebin_uuid)
            buffer_uuids.extend(client.ebout_uuid)
            if client.seb is not None:
                buffer_uuids.append(client.seb._buffer.uuid)
        if client is not None and client.job is not None:
            try:
                client.job.delete()
            except Exception:
                logging.exception("could not delete E2E job")
        for buffer_uuid in dict.fromkeys(buffer_uuids):
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
