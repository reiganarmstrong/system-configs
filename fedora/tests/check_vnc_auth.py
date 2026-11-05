"""Check the running VM's password authentication with the default local secret file."""

import socket
import struct
from pathlib import Path

import yaml
from cryptography.hazmat.decrepit.ciphers.algorithms import TripleDES
from cryptography.hazmat.primitives.ciphers import Cipher, modes


def read_exact(connection, count):
    data = bytearray()
    while len(data) < count:
        chunk = connection.recv(count - len(data))
        if not chunk:
            raise RuntimeError("VNC disconnected during authentication")
        data.extend(chunk)
    return bytes(data)


repository = Path(__file__).resolve().parents[1]
configuration = yaml.safe_load((repository / "vars/vm.yml").read_text())
password = (repository / ".local/vnc-password").read_bytes()
assert len(password) == 8, "Expected an 8-byte VNC password"

# Classic VNC uses DES with the bits in each password byte reversed.
# Repeating the key makes TripleDES equivalent to the required DES operation.
key = bytes(int(f"{byte:08b}"[::-1], 2) for byte in password)

with socket.create_connection(("127.0.0.1", configuration["vm_vnc_port"]), timeout=10) as connection:
    version = read_exact(connection, 12)
    assert version == b"RFB 003.008\n", "Expected RFB 3.8"
    connection.sendall(b"RFB 003.008\n")
    count = read_exact(connection, 1)[0]
    offered = list(read_exact(connection, count))
    assert offered == [2], "The console must require classic VNC password authentication"

    connection.sendall(bytes([2]))
    challenge = read_exact(connection, 16)
    encryptor = Cipher(TripleDES(key * 3), modes.ECB()).encryptor()
    connection.sendall(encryptor.update(challenge) + encryptor.finalize())
    result = struct.unpack("!I", read_exact(connection, 4))[0]
    assert result == 0, "The configured VNC password was rejected"

    connection.sendall(bytes([1]))
    server_info = read_exact(connection, 24)
    width, height = struct.unpack("!HH", server_info[:4])
    name_length = struct.unpack("!I", server_info[20:24])[0]
    name = read_exact(connection, name_length).decode()
    assert width > 0 and height > 0, "The authenticated console has no display"
    print(f"Password authentication passed for {name}, {width}x{height}")
