"""Create a reproducible Part 3 source bundle from two clean Git checkouts.

The archive contains only tracked files from HEAD plus manifest.json with the
repository URL, commit, per-file SHA-256, and the bundle script version.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path


def git(repo: Path, *args: str, binary: bool = False):
    result = subprocess.run(
        ["git", "-C", str(repo), *args], check=True, capture_output=True
    )
    return result.stdout if binary else result.stdout.decode("utf-8").strip()


def tracked(repo: Path):
    for rel in git(repo, "ls-files", "-z", binary=True).decode("utf-8").split("\0"):
        if rel:
            path = repo / rel
            if path.is_file():
                yield rel, path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gateway-root", type=Path, required=True)
    parser.add_argument("--tutorial-root", type=Path, required=True)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "aegis-part3-src.zip",
    )
    args = parser.parse_args()

    repos = {
        "aegis-mcp-gateway": args.gateway_root.resolve(),
        "aegis-platform-mcp-tutorial": args.tutorial_root.resolve(),
    }
    manifest = {"format": 1, "repositories": {}, "files": {}}

    for name, repo in repos.items():
        if git(repo, "status", "--porcelain"):
            raise SystemExit(f"{repo} is not clean; commit or stash changes before bundling")
        manifest["repositories"][name] = {
            "url": git(repo, "remote", "get-url", "origin"),
            "commit": git(repo, "rev-parse", "HEAD"),
        }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, repo in repos.items():
            for rel, path in tracked(repo):
                data = path.read_bytes()
                arcname = f"{name}/{rel}"
                archive.writestr(arcname, data)
                manifest["files"][arcname] = hashlib.sha256(data).hexdigest()
        archive.writestr(
            "manifest.json",
            json.dumps(manifest, indent=2, sort_keys=True).encode("utf-8"),
        )

    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(f"bundle={args.output}")
    print(f"sha256={digest}")
    print(f"files={len(manifest['files'])}")


if __name__ == "__main__":
    main()
