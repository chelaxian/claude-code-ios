#!/usr/bin/env python3
# Flip LC_BUILD_VERSION platform macOS(1) -> iOS(2) in a thin arm64 Mach-O,
# so a macOS-built binary loads the iOS shared-cache dylibs instead of failing
# with "wrong platform to load into process". Used on the bundled ripgrep.
import struct, sys

path = sys.argv[1]
f = open(path, "r+b")
d = f.read(0x8000)
assert struct.unpack_from("<I", d, 0)[0] == 0xFEEDFACF, "not a 64-bit LE Mach-O"
ncmds = struct.unpack_from("<I", d, 16)[0]
off, n = 32, 0
for _ in range(ncmds):
    cmd, sz = struct.unpack_from("<II", d, off)
    if cmd == 0x32:  # LC_BUILD_VERSION
        f.seek(off + 8)
        f.write(struct.pack("<I", 2))  # platform -> iOS
        n += 1
    off += sz
f.close()
print(f"patched {n} LC_BUILD_VERSION -> iOS: {path}")
