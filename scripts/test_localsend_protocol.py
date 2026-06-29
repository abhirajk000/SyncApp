#!/usr/bin/env python3
"""Smoke test for Local Send TCP protocol (localhost, no mDNS)."""

import json
import socket
import struct
import threading
import time
import uuid

CHUNK_MAGIC = b"SBLS"
CHUNK_SIZE = 4 * 1024 * 1024
PORT = 19876
TRANSFER_ID = str(uuid.uuid4())
TEST_PAYLOAD = b"SyncBridge Local Send test " * 1000  # ~27KB


def encode_line(obj: dict) -> bytes:
    return (json.dumps(obj) + "\n").encode()


def write_chunk(sock: socket.socket, file_index: int, offset: int, data: bytes) -> None:
    header = CHUNK_MAGIC + struct.pack(">HQ I", file_index, offset, len(data))
    sock.sendall(header + data)


def read_line(sock: socket.socket) -> str:
    buf = b""
    while b"\n" not in buf:
        chunk = sock.recv(1)
        if not chunk:
            raise ConnectionError("closed")
        buf += chunk
    return buf.decode().strip()


def read_chunk(sock: socket.socket) -> tuple[int, int, bytes]:
    header = _read_exact(sock, 18)
    if header[:4] != CHUNK_MAGIC:
        raise ValueError("bad magic")
    file_index, offset, length = struct.unpack(">HQ I", header[4:])
    data = _read_exact(sock, length)
    return file_index, offset, data


def _read_exact(sock: socket.socket, n: int) -> bytes:
    buf = b""
    while len(buf) < n:
        part = sock.recv(n - len(buf))
        if not part:
            raise ConnectionError("closed")
        buf += part
    return buf


received = {"data": b"", "accepted": False, "complete": False}
errors: list[str] = []


def receiver(host: str, port: int) -> None:
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((host, port))
    srv.listen(1)
    srv.settimeout(10)
    conn, _ = srv.accept()
    conn.settimeout(10)
    try:
        line = read_line(conn)
        msg = json.loads(line)
        assert msg["op"] == "offer", f"expected offer, got {msg}"
        assert msg["id"] == TRANSFER_ID
        conn.sendall(encode_line({"op": "accept", "id": TRANSFER_ID}))
        received["accepted"] = True

        while True:
            peek = conn.recv(4, socket.MSG_PEEK)
            if not peek:
                break
            if peek == CHUNK_MAGIC:
                idx, off, data = read_chunk(conn)
                received["data"] += data
                continue
            line = read_line(conn)
            msg = json.loads(line)
            if msg["op"] == "file_begin":
                continue
            if msg["op"] == "file_end":
                continue
            if msg["op"] == "complete":
                received["complete"] = True
                break
    except Exception as e:
        errors.append(f"receiver: {e}")
    finally:
        conn.close()
        srv.close()


def sender(host: str, port: int) -> None:
    time.sleep(0.2)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10)
    try:
        sock.connect((host, port))
        offer = {
            "op": "offer",
            "id": TRANSFER_ID,
            "sender": "Test MacBook",
            "files": [
                {
                    "index": 0,
                    "name": "test.bin",
                    "relativePath": "test.bin",
                    "size": len(TEST_PAYLOAD),
                }
            ],
        }
        sock.sendall(encode_line(offer))
        resp = json.loads(read_line(sock))
        assert resp["op"] == "accept", f"expected accept, got {resp}"

        sock.sendall(
            encode_line(
                {"op": "file_begin", "id": TRANSFER_ID, "index": 0, "offset": 0}
            )
        )
        write_chunk(sock, 0, 0, TEST_PAYLOAD)
        sock.sendall(encode_line({"op": "file_end", "id": TRANSFER_ID, "index": 0}))
        sock.sendall(encode_line({"op": "complete", "id": TRANSFER_ID}))
    except Exception as e:
        errors.append(f"sender: {e}")
    finally:
        sock.close()


def main() -> int:
    t = threading.Thread(target=receiver, args=("127.0.0.1", PORT), daemon=True)
    t.start()
    sender("127.0.0.1", PORT)
    t.join(timeout=15)

    ok = (
        not errors
        and received["accepted"]
        and received["complete"]
        and received["data"] == TEST_PAYLOAD
    )
    print("=" * 50)
    print("Local Send Protocol Smoke Test")
    print("=" * 50)
    print(f"  Accept handshake:  {'PASS' if received['accepted'] else 'FAIL'}")
    print(f"  Chunk transfer:    {'PASS' if received['data'] == TEST_PAYLOAD else 'FAIL'}")
    print(f"  Complete signal:   {'PASS' if received['complete'] else 'FAIL'}")
    print(f"  Bytes transferred: {len(received['data'])} / {len(TEST_PAYLOAD)}")
    if errors:
        print("  Errors:")
        for e in errors:
            print(f"    - {e}")
    print("=" * 50)
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
