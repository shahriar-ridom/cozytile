#!/bin/sh
# Start the shell with transparent huge pages off for its own memory.
#
# With THP set to "always" (the CachyOS/Arch default on many kernels) the kernel backs the
# shell's partly used malloc/JS heaps with 2 MB pages, which costs ~80 MB of RSS for nothing.
# PR_SET_THP_DISABLE turns that off for this process. The flag is inherited by what the shell
# launches, so PR_THP_DISABLE_EXCEPT_ADVISED (Linux 6.18+) is tried first: apps that ask for huge
# pages with madvise still get them. Older kernels fall back to a plain disable; if python3 or
# prctl is unavailable the shell simply starts as usual.
#
# Extra arguments are passed to qs, e.g. `launch.sh --no-duplicate`.
command -v python3 >/dev/null 2>&1 || exec qs -c cozytile "$@"
exec python3 -c '
import ctypes, os, sys
try:
    prctl = ctypes.CDLL(None, use_errno=True).prctl
    PR_SET_THP_DISABLE, PR_THP_DISABLE_EXCEPT_ADVISED = 41, 1 << 1
    if prctl(PR_SET_THP_DISABLE, 1, PR_THP_DISABLE_EXCEPT_ADVISED, 0, 0) != 0:
        prctl(PR_SET_THP_DISABLE, 1, 0, 0, 0)
except Exception:
    pass
os.execvp("qs", ["qs", "-c", "cozytile"] + sys.argv[1:])
' "$@"
