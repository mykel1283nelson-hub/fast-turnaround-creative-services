#!/usr/bin/env python3
"""Validate local portfolio links and committed media artifacts."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
MARKDOWN_LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
REMOTE_SCHEMES = {"http", "https", "mailto"}


def local_markdown_targets() -> list[tuple[Path, Path]]:
    targets: list[tuple[Path, Path]] = []
    for markdown in sorted(ROOT.rglob("*.md")):
        if ".git" in markdown.parts:
            continue
        text = markdown.read_text(encoding="utf-8")
        for raw_target in MARKDOWN_LINK.findall(text):
            target = raw_target.strip().strip("<>").split(" ", 1)[0]
            parsed = urlsplit(target)
            if not target or target.startswith("#") or parsed.scheme in REMOTE_SCHEMES:
                continue
            relative = unquote(parsed.path)
            if not relative:
                continue
            resolved = (markdown.parent / relative).resolve()
            targets.append((markdown, resolved))
    return targets


def validate_links() -> list[str]:
    errors: list[str] = []
    for source, target in local_markdown_targets():
        if ROOT not in target.parents and target != ROOT:
            errors.append(f"{source.relative_to(ROOT)}: local link escapes repository: {target}")
        elif not target.exists():
            errors.append(f"{source.relative_to(ROOT)}: missing local target: {target.relative_to(ROOT)}")
    return errors


def validate_mp4s() -> list[str]:
    errors: list[str] = []
    ffprobe = shutil.which("ffprobe")
    if ffprobe is None:
        return ["ffprobe is required to validate MP4 metadata"]
    for video in sorted(ROOT.rglob("*.mp4")):
        result = subprocess.run(
            [
                ffprobe,
                "-v",
                "error",
                "-show_entries",
                "format=duration:stream=codec_name,codec_type,width,height,pix_fmt",
                "-of",
                "json",
                str(video),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            errors.append(f"{video.relative_to(ROOT)}: ffprobe failed: {result.stderr.strip()}")
            continue
        payload = json.loads(result.stdout)
        duration = float(payload.get("format", {}).get("duration", 0))
        video_streams = [
            stream for stream in payload.get("streams", []) if stream.get("codec_type") == "video"
        ]
        if duration <= 0:
            errors.append(f"{video.relative_to(ROOT)}: non-positive duration")
        if not video_streams:
            errors.append(f"{video.relative_to(ROOT)}: no video stream")
        elif any(not stream.get("width") or not stream.get("height") for stream in video_streams):
            errors.append(f"{video.relative_to(ROOT)}: missing video dimensions")
    return errors


def validate_nonempty_media() -> list[str]:
    errors: list[str] = []
    for pattern in ("*.png", "*.jpg", "*.jpeg", "*.mp4"):
        for artifact in ROOT.rglob(pattern):
            if artifact.stat().st_size == 0:
                errors.append(f"{artifact.relative_to(ROOT)}: empty media artifact")
    return errors


def main() -> int:
    errors = validate_links() + validate_mp4s() + validate_nonempty_media()
    if errors:
        print("Portfolio validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Portfolio validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
