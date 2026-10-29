#!/usr/bin/env python3
"""Package existing PNG representations in Apple's ICNS container (no image dependencies)."""
from pathlib import Path
import struct
import sys

source, destination = map(Path, sys.argv[1:])
representations = {
    b"icp4": "icon_16x16.png", b"icp5": "icon_32x32.png", b"icp6": "icon_32x32@2x.png",
    b"ic07": "icon_128x128.png", b"ic08": "icon_256x256.png", b"ic09": "icon_512x512.png",
    b"ic10": "icon_512x512@2x.png", b"ic11": "icon_16x16@2x.png", b"ic12": "icon_32x32@2x.png",
    b"ic13": "icon_128x128@2x.png", b"ic14": "icon_256x256@2x.png",
}
chunks = []
for kind, name in representations.items():
    image = (source / name).read_bytes()
    chunks.append(kind + struct.pack(">I", len(image) + 8) + image)
payload = b"".join(chunks)
destination.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
