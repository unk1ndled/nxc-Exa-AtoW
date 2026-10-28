import asyncio
import hashlib
import logging
import os
import uuid

import docker
import httpx
from docker.errors import ImageNotFound, NotFound
from docker.types import Ulimit

logger = logging.getLogger(__name__)

# Pinned by digest, not :latest, so a registry-side image swap can't change
# what we ship. Bump via:
#   docker pull quay.io/jupyter/base-notebook:latest
#   docker inspect quay.io/jupyter/base-notebook:latest \
#       --format '{{index .RepoDigests 0}}'
JUPYTER_IMAGE = os.getenv(
    "JUPYTER_IMAGE",
    "quay.io/jupyter/base-notebook"
    "@sha256:0b358e9ec57a1562f78ec63b13895e9a72f3fe245fb29ba59f1dc6005607ff7c",
)

KERNEL_NETWORK = os.getenv("KERNEL_NETWORK", "exa-kernels")
EGRESS_PROXY_HOST = os.getenv("EGRESS_PROXY_HOST", "exa-egress-proxy")
EGRESS_PROXY_PORT = int(os.getenv("EGRESS_PROXY_PORT", "8888"))
# Optional explicit image override . When unset we
# build a content-addressed image so edits to the allow-list force a rebuild.
EGRESS_PROXY_IMAGE = os.getenv("EGRESS_PROXY_IMAGE")  # None unless overridden
PROXY_BUILD_CONTEXT = os.path.join(os.path.dirname(__file__), "proxy")
# Files whose contents define the proxy image; any change must rebuild it.
PROXY_CONTEXT_FILES = ("Dockerfile", "tinyproxy.conf", "allowlist.txt")

# Resource ceilings per kernel container. Overridable via env so ops can tune
# without a code change.
KERNEL_MEM_LIMIT = os.getenv("KERNEL_MEM_LIMIT", "1g")
KERNEL_CPU_QUOTA = int(os.getenv("KERNEL_CPU_QUOTA", "50000"))  # 50% of 1 CPU
KERNEL_CPU_PERIOD = int(os.getenv("KERNEL_CPU_PERIOD", "100000"))
KERNEL_PIDS_LIMIT = int(os.getenv("KERNEL_PIDS_LIMIT", "256"))
KERNEL_NOFILE_LIMIT = int(os.getenv("KERNEL_NOFILE_LIMIT", "1024"))
KERNEL_TMP_SIZE = os.getenv("KERNEL_TMP_SIZE", "64m")
KERNEL_HOME_SIZE = os.getenv("KERNEL_HOME_SIZE", "512m")

# Jovyan uid:gid from the upstream jupyter/base-notebook image.
JOVYAN_UID_GID = "1000:100"


class SessionManager:
    def __init__(self, max_sessions: int = 5):
        self.docker = docker.from_env()
        self.max_sessions = max_sessions
        self.sessions: dict[str, dict] = {}
        self._client_map: dict[str, str] = {}
        self._network = self._ensure_kernel_network()
        self._proxy = self._ensure_egress_proxy()

    # Network setup
    def _ensure_kernel_network(self):
        """Get or create the internal bridge that kernel containers attach to.

        `internal=True` removes the bridge's NAT/egress route — kernels cannot
        reach the public internet directly. The FastAPI server (running on the
        host) still reaches kernels via the bridge's gateway interface, so no
        port publishing is needed.
        """
        try:
            net = self.docker.networks.get(KERNEL_NETWORK)
            logger.info("Using existing kernel network %s", KERNEL_NETWORK)
            return net
        except NotFound:
            net = self.docker.networks.create(
                KERNEL_NETWORK,
                driver="bridge",
                internal=True,
                check_duplicate=True,
            )
            logger.info("Created internal kernel network %s", KERNEL_NETWORK)
            return net

    def _ensure_egress_proxy(self):
        """Build (if needed) and run the allow-list HTTP proxy as a singleton.

        The proxy sits on two networks: the default bridge (for outbound to
        whitelisted hosts) and the internal kernel network (for inbound from
        kernel containers via the `exa-egress-proxy` hostname).

        Gated by START_EGRESS_PROXY env (default on). Set to "false" when the
        proxy is provisioned out-of-band (compose, systemd, k8s, etc.).
        """
        if os.getenv("START_EGRESS_PROXY", "true").lower() in ("0", "false", "no"):
            logger.info("START_EGRESS_PROXY=off — assuming proxy is managed externally")
            return None

        image_tag = self._proxy_image_tag()

        if EGRESS_PROXY_IMAGE is None:
            try:
                self.docker.images.get(image_tag)
            except ImageNotFound:
                logger.info("Building egress proxy image %s from %s", image_tag, PROXY_BUILD_CONTEXT)
                self.docker.images.build(
                    path=PROXY_BUILD_CONTEXT, tag=image_tag, rm=True
                )

        try:
            existing = self.docker.containers.get(EGRESS_PROXY_HOST)
            up_to_date = (
                existing.status == "running"
                and image_tag in (existing.image.tags or [])
            )
            if up_to_date:
                logger.info("Egress proxy already running with current allow-list (%s)", existing.short_id)
                self._prune_old_proxy_images(image_tag)
                return existing
            logger.info("Egress proxy stale or stopped — recreating (%s)", existing.short_id)
            existing.remove(force=True)
        except NotFound:
            pass

        proxy = self.docker.containers.run(
            image_tag,
            name=EGRESS_PROXY_HOST,
            detach=True,
            restart_policy={"Name": "unless-stopped"},
            cap_drop=["ALL"],
            security_opt=["no-new-privileges:true"],
            mem_limit="128m",
            pids_limit=64,
            # Let the proxy resolve host-published services (e.g. the eBuffer /
            # ebservice API the notebooks call via host.docker.internal). The
            # kernel must NOT get this mapping (T4 regression) — only the proxy.
            extra_hosts={"host.docker.internal": "host-gateway"},
        )
        self._network.connect(proxy, aliases=[EGRESS_PROXY_HOST])
        logger.info("Started egress proxy %s (%s)", proxy.short_id, image_tag)
        self._prune_old_proxy_images(image_tag)
        return proxy

    def _prune_old_proxy_images(self, keep_tag: str) -> None:
        """Remove superseded exa-egress-proxy images, keeping only keep_tag.

        Each allow-list edit yields a new content-addressed tag, so the previous
        images would otherwise accumulate. The image backing the running proxy
        (keep_tag) is never touched, and an explicit EGRESS_PROXY_IMAGE override
        means images are managed out of band — skip pruning entirely.
        """
        if EGRESS_PROXY_IMAGE is not None:
            return
        try:
            images = self.docker.images.list(name="exa-egress-proxy")
        except Exception:
            logger.warning("Could not list egress proxy images for pruning", exc_info=True)
            return
        for image in images:
            stale = [
                t for t in (image.tags or [])
                if t.startswith("exa-egress-proxy:") and t != keep_tag
            ]
            if not stale or keep_tag in (image.tags or []):
                continue  # current image, or not one of ours — leave it
            for tag in stale:
                try:
                    self.docker.images.remove(tag, force=True)
                    logger.info("Pruned superseded egress proxy image %s", tag)
                except Exception:
                    logger.warning("Could not prune egress proxy image %s", tag, exc_info=True)

    def _proxy_image_tag(self) -> str:
        """Content-addressed tag for the locally built egress proxy image.

        Hashing the build context (Dockerfile + tinyproxy.conf + allowlist.txt)
        means any edit yields a new tag, which forces both a rebuild and a
        container recreate above. Without this, editing the allow-list silently
        has no effect because a cached image / long-lived container is reused.
        An explicit EGRESS_PROXY_IMAGE override always wins.
        """
        if EGRESS_PROXY_IMAGE is not None:
            return EGRESS_PROXY_IMAGE

        digest = hashlib.sha256()
        for fname in PROXY_CONTEXT_FILES:
            try:
                with open(os.path.join(PROXY_BUILD_CONTEXT, fname), "rb") as f:
                    digest.update(f.read())
            except FileNotFoundError:
                pass
        return f"exa-egress-proxy:{digest.hexdigest()[:12]}"

    # Client-map helpers
    def get_session_by_client(self, client_id: str) -> dict | None:
        sid = self._client_map.get(client_id)
        return self.sessions.get(sid) if sid else None

    def clear_client(self, client_id: str) -> None:
        self._client_map.pop(client_id, None)

    # Public API
    def create_session(self, client_id: str | None = None) -> dict:
        active = [s for s in self.sessions.values() if s["status"] != "stopped"]
        if len(active) >= self.max_sessions:
            raise RuntimeError(
                f"Max concurrent sessions ({self.max_sessions}) reached. "
                "Stop an existing session before creating a new one."
            )

        session_id = uuid.uuid4().hex[:8]
        token = uuid.uuid4().hex

        container = self._run_hardened_kernel(session_id, token)

        container.reload()
        ip = container.attrs["NetworkSettings"]["Networks"][KERNEL_NETWORK]["IPAddress"]

        session: dict = {
            "id": session_id,
            "token": token,
            "container_id": container.id,
            "ip": ip,
            "port": 8888,
            "base_url": f"http://{ip}:8888",
            "status": "starting",
            "kernel_id": None,
            "error": None,
        }
        self.sessions[session_id] = session

        if client_id:
            self._client_map[client_id] = session_id

        logger.info(
            "Created session %s on %s (client: %s)",
            session_id,
            ip,
            client_id or "anonymous",
        )
        return session

    def _run_hardened_kernel(self, session_id: str, token: str):
        """Spawn a Jupyter container with industry-baseline hardening.
        TODO : doc
        - dropped capabilities + no-new-privileges + default seccomp
        - non-root explicit user
        - read-only root with sized tmpfs for the writable paths Jupyter needs
        - mem / cpu / pids / nofile ceilings
        - attached only to the internal kernel network (no egress)
        - HTTP(S)_PROXY env points at the egress allow-list proxy; if the
          proxy isn't running, outbound calls fail closed
        """
        return self.docker.containers.run(
            JUPYTER_IMAGE,
            detach=True,
            remove=True,
            name=f"exa-atow-{session_id}",
            user=JOVYAN_UID_GID,
            network=KERNEL_NETWORK,
            cap_drop=["ALL"],
            security_opt=["no-new-privileges:true"],
            read_only=True,
            tmpfs={
                "/tmp": f"rw,noexec,nosuid,size={KERNEL_TMP_SIZE}",
                "/home/jovyan": f"rw,nosuid,size={KERNEL_HOME_SIZE},uid=1000,gid=100",
            },
            mem_limit=KERNEL_MEM_LIMIT,
            memswap_limit=KERNEL_MEM_LIMIT,  # equal => swap disabled
            cpu_period=KERNEL_CPU_PERIOD,
            cpu_quota=KERNEL_CPU_QUOTA,
            pids_limit=KERNEL_PIDS_LIMIT,
            ulimits=[
                Ulimit(name="nofile", soft=KERNEL_NOFILE_LIMIT, hard=KERNEL_NOFILE_LIMIT),
            ],
            environment={
                "JUPYTER_TOKEN": token,
                "HTTP_PROXY": f"http://{EGRESS_PROXY_HOST}:{EGRESS_PROXY_PORT}",
                "HTTPS_PROXY": f"http://{EGRESS_PROXY_HOST}:{EGRESS_PROXY_PORT}",
                "NO_PROXY": "localhost,127.0.0.1",
            },
        )

    def get_session(self, session_id: str) -> dict | None:
        return self.sessions.get(session_id)

    def list_sessions(self) -> list[dict]:
        return [
            {
                "id": s["id"],
                "status": s["status"],
                "port": s["port"],
                "error": s["error"],
            }
            for s in self.sessions.values()
        ]

    def stop_session(self, session_id: str) -> None:
        session = self.sessions.pop(session_id, None)
        if not session:
            return

        stale = [cid for cid, sid in self._client_map.items() if sid == session_id]
        for cid in stale:
            del self._client_map[cid]

        try:
            container = self.docker.containers.get(session["container_id"])
            container.stop(timeout=3)
            logger.info("Stopped container for session %s", session_id)
        except Exception as exc:
            logger.warning(
                "Error stopping container for session %s: %s", session_id, exc
            )

    def stop_all(self) -> None:
        for sid in list(self.sessions.keys()):
            self.stop_session(sid)

    # Readiness probe 
    async def wait_for_ready(self, session_id: str, timeout: int = 90) -> None:
        session = self.sessions.get(session_id)
        if not session:
            return

        base_url = session["base_url"]
        token = session["token"]

        async with httpx.AsyncClient() as client:
            deadline = asyncio.get_event_loop().time() + timeout

            while asyncio.get_event_loop().time() < deadline:
                if session_id not in self.sessions:
                    return
                try:
                    resp = await client.get(
                        f"{base_url}/api/kernels",
                        headers={"Authorization": f"token {token}"},
                        timeout=3.0,
                    )
                    if resp.status_code == 200:
                        kresp = await client.post(
                            f"{base_url}/api/kernels",
                            headers={"Authorization": f"token {token}"},
                            json={"name": "python3"},
                            timeout=10.0,
                        )
                        kresp.raise_for_status()
                        session["kernel_id"] = kresp.json()["id"]
                        session["status"] = "ready"
                        logger.info(
                            "Session %s ready — kernel %s",
                            session_id,
                            session["kernel_id"],
                        )
                        return
                except Exception:
                    pass  # not ready yet

                await asyncio.sleep(2)

        session["status"] = "error"
        session["error"] = "Jupyter did not become ready in time."
        logger.error("Session %s timed out waiting for Jupyter", session_id)
