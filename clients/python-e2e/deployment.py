import json
import os
from dataclasses import dataclass
from ipaddress import ip_address
from pathlib import Path
from urllib.parse import urlparse


TRANSPORT_VM = "vm-tunnel"
TRANSPORT_G5K = "g5k-direct"
TRANSPORTS = {TRANSPORT_VM, TRANSPORT_G5K}


@dataclass(frozen=True)
class DeploymentEndpoints:
    composition: str
    transport: str
    ebuffer_url: str
    ebservice_url: str
    ssh_host: str
    ssh_port: int
    ssh_user: str
    strict_host_key_checking: str


def _service_url(variable: str, default: str) -> str:
    value = os.getenv(variable, default).rstrip("/")
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError(f"{variable} must be an absolute HTTP(S) URL, got {value!r}")
    return value


def _ssh_port() -> int | None:
    value = os.getenv("E2E_SSH_PORT")
    if value is None:
        return None
    try:
        port = int(value)
    except ValueError as error:
        raise ValueError(f"E2E_SSH_PORT must be an integer, got {value!r}") from error
    if not 1 <= port <= 65535:
        raise ValueError(f"E2E_SSH_PORT must be between 1 and 65535, got {port}")
    return port


def _role_address(deployment: dict, hostname: str) -> str:
    matches = [
        address
        for address, node in deployment.items()
        if isinstance(node, dict) and node.get("host") == hostname
    ]
    if len(matches) != 1:
        raise ValueError(
            f"deployment must contain exactly one host named {hostname!r}, found {len(matches)}"
        )
    try:
        ip_address(matches[0])
    except ValueError as error:
        raise ValueError(
            f"deployment address for {hostname!r} is not an IP address: {matches[0]!r}"
        ) from error
    return matches[0]


def load_deployment_endpoints(
    deployment_file: str | Path,
    transport: str,
    expected_composition: str | None = None,
) -> DeploymentEndpoints:
    path = Path(deployment_file).expanduser().resolve()
    if not path.is_file():
        raise FileNotFoundError(f"NXC deployment file not found: {path}")
    if transport not in TRANSPORTS:
        raise ValueError(
            f"NXC_E2E_TRANSPORT must be one of {', '.join(sorted(TRANSPORTS))}, "
            f"got {transport!r}"
        )

    try:
        document = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid NXC deployment JSON in {path}: {error}") from error
    if not isinstance(document, dict):
        raise ValueError(f"NXC deployment document must be an object: {path}")

    composition = document.get("composition")
    if not isinstance(composition, str) or not composition:
        raise ValueError(f"NXC deployment has no composition name: {path}")
    if expected_composition is not None and composition != expected_composition:
        raise ValueError(
            f"deployment composition is {composition!r}, expected {expected_composition!r}"
        )

    deployment = document.get("deployment")
    if not isinstance(deployment, dict) or not deployment:
        raise ValueError(f"NXC deployment has no nodes: {path}")

    ebuffer_host = _role_address(deployment, "ebuffer")
    ebservice_host = _role_address(deployment, "ebservice")
    frontend_host = _role_address(deployment, "frontend")
    required_nodes = [deployment[host] for host in (ebuffer_host, ebservice_host, frontend_host)]

    ssh_port_override = _ssh_port()
    ssh_host_override = os.getenv("E2E_SSH_HOST")
    ssh_user = os.getenv("E2E_SSH_USER", "root")
    if not ssh_user:
        raise ValueError("E2E_SSH_USER must not be empty")

    if transport == TRANSPORT_VM:
        if any("vm_id" not in node for node in required_nodes):
            raise ValueError("vm-tunnel transport requires vm_id on every service node")
        return DeploymentEndpoints(
            composition=composition,
            transport=transport,
            ebuffer_url=_service_url(
                "E2E_EBUFFER_URL", "http://127.0.0.1:8000/api/v1"
            ),
            ebservice_url=_service_url(
                "E2E_EBSERVICE_URL", "http://127.0.0.1:8001/api/v1"
            ),
            ssh_host=ssh_host_override or "127.0.0.1",
            ssh_port=ssh_port_override or 2222,
            ssh_user=ssh_user,
            strict_host_key_checking="no",
        )

    if any("vm_id" in node for node in required_nodes):
        raise ValueError("g5k-direct transport cannot use a VM deployment")
    return DeploymentEndpoints(
        composition=composition,
        transport=transport,
        ebuffer_url=_service_url(
            "E2E_EBUFFER_URL", f"http://{ebuffer_host}:8000/api/v1"
        ),
        ebservice_url=_service_url(
            "E2E_EBSERVICE_URL", f"http://{ebservice_host}:8001/api/v1"
        ),
        ssh_host=ssh_host_override or frontend_host,
        ssh_port=ssh_port_override or 22,
        ssh_user=ssh_user,
        strict_host_key_checking="accept-new",
    )


def endpoints_from_environment() -> DeploymentEndpoints:
    deployment_file = os.environ.get("NXC_DEPLOYMENT_FILE")
    if not deployment_file:
        raise ValueError("NXC_DEPLOYMENT_FILE is required")
    transport = os.environ.get("NXC_E2E_TRANSPORT")
    if not transport:
        raise ValueError("NXC_E2E_TRANSPORT is required")
    return load_deployment_endpoints(
        deployment_file,
        transport,
        os.environ.get("NXC_EXPECTED_COMPOSITION"),
    )
