import json
from types import SimpleNamespace

import pytest
from ebstemplate.hpc import HpcConfig

from common import build_application_hpc_config, validate_scheduler_info
from mpi_hello_e2e import APPLICATION


def test_application_config_is_compatible_with_ebs_0_1_1(tmp_path, monkeypatch):
    monkeypatch.delenv("E2E_HPC_CONFIG", raising=False)
    path = build_application_hpc_config(APPLICATION, tmp_path / "hpc.ini")
    config = HpcConfig(path)

    assert config.hpc == "idris"
    assert config.hostname == "nxc-frontend"
    assert config.app_name == "mpi-hello"
    assert config.nodes == 2
    assert config.tasks == 2
    assert config.cores == 1


def test_scheduler_info_uses_last_complete_ndjson_record():
    records = [
        {"job_state": ["RUNNING"], "job_id": 42, "exit_code": "0:0"},
        {
            "last_update": {"set": True, "infinite": False, "number": 1234},
            "job_state": ["COMPLETED"],
            "job_id": 42,
            "exit_code": "0:0",
        },
    ]
    content = b"".join((json.dumps(record) + "\n").encode() for record in records)
    content += b'{"truncated":'
    client = SimpleNamespace(seb=SimpleNamespace(fetch=lambda: content))

    assert validate_scheduler_info(client) == 42


def test_scheduler_info_rejects_nonzero_exit():
    record = {
        "last_update": {"set": True, "infinite": False, "number": 1234},
        "job_state": ["FAILED"],
        "job_id": 42,
        "exit_code": "1:0",
    }
    client = SimpleNamespace(
        seb=SimpleNamespace(fetch=lambda: (json.dumps(record) + "\n").encode())
    )

    with pytest.raises(RuntimeError, match="no successful terminal record"):
        validate_scheduler_info(client)
