#!/bin/bash
# Restore POSIX symlinks that became plain-text path stubs after extracting on Windows NTFS.
set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FSTYPE="$(findmnt -n -o FSTYPE -T "$ROOT_DIR" 2>/dev/null || true)"
if [[ "$FSTYPE" == "9p" || "$FSTYPE" == "drvfs" || "$FSTYPE" == "ntfs" || "$FSTYPE" == "fuseblk" ]]; then
	echo "Skipping symlink repair on non-POSIX filesystem ($FSTYPE): $ROOT_DIR"
	exit 0
fi

python3 - "$ROOT_DIR" <<'PY'
import os
import sys

root_dir = os.path.abspath(sys.argv[1])
subdirs = ["userpatches", "u-boot", "external", "kernel", "toolchains", "scripts"]
fixed = 0

for sub in subdirs:
    top = os.path.join(root_dir, sub)
    if not os.path.isdir(top):
        continue
    for dirpath, _, filenames in os.walk(top, followlinks=False):
        for name in filenames:
            fpath = os.path.join(dirpath, name)
            if os.path.islink(fpath):
                continue
            try:
                st = os.lstat(fpath)
                if st.st_size <= 0 or st.st_size > 255:
                    continue
                with open(fpath, "rb") as fp:
                    raw = fp.read()
                if b"\n" in raw or b"\r" in raw or b"\0" in raw:
                    continue
                target = raw.decode("utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            if not target or any(ch.isspace() for ch in target) or target.startswith(("#", "//", "http")):
                continue
            resolved = os.path.normpath(os.path.join(dirpath, target))
            if resolved == os.path.normpath(fpath):
                continue
            if os.path.lexists(resolved):
                os.unlink(fpath)
                os.symlink(target, fpath)
                fixed += 1

print(f"Restored {fixed} symlinks in {root_dir}")
PY
