from http.server import HTTPServer
from threading import Thread
from http.client import HTTPConnection

from app import Handler


def start_server():
    server = HTTPServer(("localhost", 8080), Handler)

    thread = Thread(target=server.serve_forever)
    thread.daemon = True
    thread.start()

    return server


def get_response(path):
    connection = HTTPConnection("localhost", 8080)
    connection.request("GET", path)

    response = connection.getresponse()
    body = response.read()

    connection.close()

    return response.status, body


def test_health():
    server = start_server()

    status, body = get_response("/health")

    assert status == 200
    assert body == b"healthy"

    server.shutdown()
    server.server_close()


def test_root():
    server = start_server()

    status, body = get_response("/")

    assert status == 200
    assert body == b"8Byte DevOps Assignment - staging"

    server.shutdown()
    server.server_close()


def test_invalid_path():
    server = start_server()

    status, body = get_response("/invalid")

    assert status == 404

    server.shutdown()
    server.server_close()