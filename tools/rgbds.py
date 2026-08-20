"""Fetch the pinned RGBDS toolchain into build/toolchain/.

Never installs anything system-wide. If a matching rgbasm is already on PATH,
that is used instead and reported.

See docs/architecture.md D4: the toolchain version is pinned because RGBDS 1.0
removed pre-1.0 `EQU` syntax and breaks every Game Boy Tetris disassembly.
"""

import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

VERSION = "0.6.1"

# sha256 of the official release archives, verified 2026-08-20
RELEASES = {
    "Linux": (
        f"https://github.com/gbdev/rgbds/releases/download/v{VERSION}/"
        f"rgbds-{VERSION}-linux-x86_64.tar.xz",
        "cfaff18e0db0006863de921d6f5a10eb5fb04dba453f967955a8b0f30bc7ba5b",
    ),
    "Darwin": (
        f"https://github.com/gbdev/rgbds/releases/download/v{VERSION}/"
        f"rgbds-{VERSION}-macos-x86-64.zip",
        "65929a5483c89b20955df0d78ceb87744d8ad0cf7c80919f6ee9ef90fc55c08d",
    ),
}

TOOLS = ("rgbasm", "rgblink", "rgbfix", "rgbgfx")


def _system_toolchain():
    """Return a dir containing a system rgbasm of the pinned version, if any."""
    found = shutil.which("rgbasm")
    if not found:
        return None
    try:
        out = subprocess.run(
            [found, "--version"], capture_output=True, text=True, timeout=10
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    if VERSION not in out:
        print(f"  note: system rgbasm is {out.strip()!r}, not v{VERSION}; ignoring it")
        return None
    return Path(found).parent


def _download(url, sha256, dest):
    print(f"  downloading {url}")
    with urllib.request.urlopen(url, timeout=120) as resp:
        blob = resp.read()
    got = hashlib.sha256(blob).hexdigest()
    if got != sha256:
        raise SystemExit(
            f"checksum mismatch for {url}\n  expected {sha256}\n  got      {got}"
        )
    dest.write_bytes(blob)


def ensure(build_dir: Path) -> Path:
    """Return a directory containing the four RGBDS binaries."""
    system = _system_toolchain()
    if system:
        print(f"  using system RGBDS v{VERSION} from {system}")
        return system

    tc = build_dir / "toolchain"
    if all((tc / t).exists() for t in TOOLS):
        return tc

    plat = platform.system()
    if plat not in RELEASES:
        raise SystemExit(
            f"No pinned RGBDS build for {plat}. Install RGBDS v{VERSION} manually "
            f"and put it on PATH."
        )
    url, sha256 = RELEASES[plat]

    tc.mkdir(parents=True, exist_ok=True)
    archive = tc / url.rsplit("/", 1)[-1]
    if not archive.exists():
        _download(url, sha256, archive)
    else:
        got = hashlib.sha256(archive.read_bytes()).hexdigest()
        if got != sha256:
            archive.unlink()
            _download(url, sha256, archive)

    print(f"  extracting {archive.name}")
    if archive.suffix == ".zip":
        with zipfile.ZipFile(archive) as z:
            z.extractall(tc)
    else:
        with tarfile.open(archive) as t:
            t.extractall(tc)

    # some archives nest the binaries one level down
    for tool in TOOLS:
        if not (tc / tool).exists():
            hits = list(tc.rglob(tool))
            if not hits:
                raise SystemExit(f"{tool} not found in {archive.name}")
            shutil.copy2(hits[0], tc / tool)
        (tc / tool).chmod(0o755)

    return tc


if __name__ == "__main__":
    print(ensure(Path(sys.argv[1] if len(sys.argv) > 1 else "build")))
