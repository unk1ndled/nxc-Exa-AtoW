import json

import pytest

from deployment import TRANSPORT_G5K, TRANSPORT_VM, load_deployment_endpoints


def write_deployment(tmp_path, nodes, composition="mpi-hello"):
    path = tmp_path / "deployment.json"
    path.write_text(json.dumps({"composition": composition, "deployment": nodes}))
    return path


def service_nodes(vm=False):
    nodes = {
        "192.0.2.10": {"role": "ebuffer", "host": "ebuffer"},
        "192.0.2.11": {"role": "ebservice", "host": "ebservice"},
        "192.0.2.12": {"role": "frontend", "host": "frontend"},
    }
    if vm:
        for index, node in enumerate(nodes.values(), start=1):
            node["vm_id"] = index
    return nodes


def test_g5k_endpoints_are_read_from_deployment(tmp_path):
    endpoints = load_deployment_endpoints(
        write_deployment(tmp_path, service_nodes()),
        TRANSPORT_G5K,
        "mpi-hello",
    )

    assert endpoints.ebuffer_url == "http://192.0.2.10:8000/api/v1"
    assert endpoints.ebservice_url == "http://192.0.2.11:8001/api/v1"
    assert endpoints.ssh_host == "192.0.2.12"
    assert endpoints.ssh_port == 22
    assert endpoints.strict_host_key_checking == "accept-new"


def test_vm_endpoints_use_established_local_forwards(tmp_path):
    endpoints = load_deployment_endpoints(
        write_deployment(tmp_path, service_nodes(vm=True)),
        TRANSPORT_VM,
    )

    assert endpoints.ebuffer_url == "http://127.0.0.1:8000/api/v1"
    assert endpoints.ebservice_url == "http://127.0.0.1:8001/api/v1"
    assert endpoints.ssh_host == "127.0.0.1"
    assert endpoints.ssh_port == 2222
    assert endpoints.strict_host_key_checking == "no"


def test_transport_and_deployment_kind_must_match(tmp_path):
    with pytest.raises(ValueError, match="cannot use a VM deployment"):
        load_deployment_endpoints(
            write_deployment(tmp_path, service_nodes(vm=True)),
            TRANSPORT_G5K,
        )
    with pytest.raises(ValueError, match="requires vm_id"):
        load_deployment_endpoints(
            write_deployment(tmp_path, service_nodes()),
            TRANSPORT_VM,
        )


def test_expected_composition_is_enforced(tmp_path):
    with pytest.raises(ValueError, match="expected 'openqcd'"):
        load_deployment_endpoints(
            write_deployment(tmp_path, service_nodes()),
            TRANSPORT_G5K,
            "openqcd",
        )


def test_every_required_host_must_be_unique(tmp_path):
    nodes = service_nodes()
    nodes["192.0.2.13"] = {"role": "frontend", "host": "frontend"}
    with pytest.raises(ValueError, match="exactly one host named 'frontend'"):
        load_deployment_endpoints(
            write_deployment(tmp_path, nodes),
            TRANSPORT_G5K,
        )
