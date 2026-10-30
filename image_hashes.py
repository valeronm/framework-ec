#!/usr/bin/env python3
"""Print the sha256 of an EC image's RO and RW halves, the build date masked.

  image_hashes.py <ec.bin>

A dump of the flash also holds blank space and the EC's settings, which a
built image leaves 0xff, so only the halves are hashed. A flash size with no
layout below is refused.
"""

import hashlib
import re
import sys

# By flash size: each half's start and end.
LAYOUTS = {
    # NPCX9 with 512 KB, as on sakura.
    0x80000: ((0x0, 0x3F000), (0x40000, 0x7F000)),
}
# zmake stamps the time of the build into each half.
DATE = re.compile(rb"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}")

image = open(sys.argv[1], "rb").read()
if len(image) not in LAYOUTS:
    sys.exit(f"no layout for a {len(image)}-byte image")
print(
    " ".join(
        hashlib.sha256(DATE.sub(b"X" * 19, image[start:end])).hexdigest()
        for start, end in LAYOUTS[len(image)]
    )
)
