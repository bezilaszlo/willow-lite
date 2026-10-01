#!/usr/bin/env python3
"""Create compact 1 fps contact sheets and selected detail frames."""

from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

MAX_DURATION_SECONDS = 120
MAX_DETAIL_FRAMES = 8
SHEET_SECONDS = 30


def run(args: list[str]) -> str:
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", type=Path, help="Willow diagnostic MP4")
    parser.add_argument("--output", type=Path, help="new review directory; must not already exist")
    parser.add_argument("--at", type=float, action="append", default=[], metavar="SECONDS",
                        help="save a full-size frame near this timestamp; repeat up to 8 times")
    options = parser.parse_args()
    video = options.video.expanduser().resolve()
    if not video.is_file():
        parser.error(f"video does not exist: {video}")
    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            parser.error(f"required host tool not found: {tool}")
    if len(options.at) > MAX_DETAIL_FRAMES:
        parser.error(f"at most {MAX_DETAIL_FRAMES} --at timestamps are allowed")

    duration = float(run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                          "-of", "default=noprint_wrappers=1:nokey=1", str(video)]))
    if not math.isfinite(duration) or duration <= 0 or duration > MAX_DURATION_SECONDS + 2:
        parser.error(f"duration {duration:.2f}s is outside the bounded capture limit")
    for timestamp in options.at:
        if not math.isfinite(timestamp) or timestamp < 0 or timestamp >= duration:
            parser.error(f"detail timestamp {timestamp} must be between 0 and {duration:.2f}")

    default_out = video.with_name(video.stem + "-review")
    out = (options.output or default_out).expanduser().resolve()
    os.umask(0o077)
    try:
        out.mkdir(mode=0o700, parents=True, exist_ok=False)
    except FileExistsError:
        parser.error(f"review directory already exists: {out}; choose a new --output path")

    pages: list[tuple[Path, float, float]] = []
    for page_start in range(0, int(duration) + 1, SHEET_SECONDS):
        if page_start >= duration:
            break
        page_end = min(page_start + SHEET_SECONDS, duration)
        sheet = out / f"contact-{page_start:03d}-{int(page_end):03d}s.jpg"
        frame_count = min(SHEET_SECONDS, math.ceil(page_end - page_start))
        columns = min(6, frame_count)
        rows = math.ceil(frame_count / columns)
        # Six columns by five rows: each page covers at most 30 seconds, one sample per cell.
        run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", str(page_start), "-i", str(video),
             "-vf", f"fps=1,scale=180:-2,tile={columns}x{rows}:nb_frames={frame_count}:padding=4:margin=4", "-frames:v", "1",
             "-q:v", "4", str(sheet)])
        pages.append((sheet, page_start, page_end))

    details: list[str] = []
    for index, timestamp in enumerate(options.at, 1):
        target = out / f"detail-{index:02d}-{timestamp:.2f}s.jpg"
        run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", f"{timestamp:.3f}",
             "-i", str(video), "-frames:v", "1", "-q:v", "2", str(target)])
        details.append(str(target))

    timeline_path = Path(str(video) + ".events.json")
    timeline_count = None
    if timeline_path.is_file() and timeline_path.stat().st_size <= 65536:
        try:
            events = json.loads(timeline_path.read_text(encoding="utf-8"))
            if isinstance(events, list) and len(events) <= 64:
                timeline_count = len(events)
        except (UnicodeError, json.JSONDecodeError):
            pass
    report = [f"video={video}", f"duration_seconds={duration:.2f}", "sample_rate=1 frame/second",
              f"pages={len(pages)}", "Each page is read left-to-right, top-to-bottom; its first cell starts at the listed second."]
    report.extend(f"page={sheet} seconds={start}-{end:.2f}" for sheet, start, end in pages)
    report.extend(f"detail_{i}={path}" for i, path in enumerate(details, 1))
    report.append(f"timeline_events={timeline_count if timeline_count is not None else 'unavailable'}")
    (out / "report.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    print("\n".join(report))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        print(f"command failed: {error.cmd[0]}", file=sys.stderr)
        raise SystemExit(error.returncode)
