import logging
import re
import socket
from app.config import settings

logger = logging.getLogger("farma_hpc.green_it")
MAC_REGEX = re.compile(r"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$")


def wake_on_lan(
    mac_address: str = settings.wol_mac_address,
    broadcast_ip: str = settings.wol_broadcast_ip,
    port: int = settings.wol_port,
) -> bool:
    """Envía un Magic Packet UDP para despertar al Nodo Esclavo i7 bajo demanda."""
    if not MAC_REGEX.match(mac_address):
        raise ValueError(f"Formato de dirección MAC inválido: {mac_address}")

    clean_mac = mac_address.replace(":", "").replace("-", "")
    mac_bytes = bytes.fromhex(clean_mac)
    magic_packet = b"\xff" * 6 + mac_bytes * 16

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(magic_packet, (broadcast_ip, port))

    logger.info("Magic Packet WoL enviado a %s (%s:%d)", mac_address, broadcast_ip, port)
    return True
