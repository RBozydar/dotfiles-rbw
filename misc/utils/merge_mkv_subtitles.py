#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


IMAGE_SUBTITLE_CODECS = {
    "dvb_subtitle",
    "dvd_subtitle",
    "hdmv_pgs_subtitle",
    "xsub",
}

SDH_TITLE_RE = re.compile(
    r"(^|[\s._/\[\]()-])(?:sdh|hi|cc)(?=$|[\s._/\[\]()-])"
    r"|hearing impaired|closed captions?"
)
TIME_RE = re.compile(
    r"^(?P<start>\d{2,}:\d{2}:\d{2},\d{3})\s+-->\s+"
    r"(?P<end>\d{2,}:\d{2}:\d{2},\d{3})(?P<rest>.*)$"
)


@dataclass(frozen=True)
class SubtitleStream:
    index: int
    codec: str
    language: str
    title: str
    forced: bool
    hearing_impaired: bool

    @property
    def title_lower(self) -> str:
        return self.title.casefold()

    @property
    def is_forced(self) -> bool:
        return self.forced or "forced" in self.title_lower

    @property
    def is_sdh(self) -> bool:
        if self.hearing_impaired:
            return True
        return SDH_TITLE_RE.search(self.title_lower) is not None

    @property
    def is_text_convertible(self) -> bool:
        return self.codec not in IMAGE_SUBTITLE_CODECS

    @property
    def flags(self) -> str:
        flags = []
        if self.is_forced:
            flags.append("forced")
        if self.is_sdh:
            flags.append("sdh")
        if not self.is_text_convertible:
            flags.append("image")
        return ",".join(flags) or "-"


@dataclass(frozen=True)
class Cue:
    start_ms: int
    end_ms: int
    timing: str
    text: str
    source_index: int


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=False, capture_output=True, text=True)


def fail(message: str, examples: list[str] | None = None) -> None:
    print(f"error: {message}", file=sys.stderr)
    if examples:
        print("examples:", file=sys.stderr)
        for example in examples:
            print(f"  {example}", file=sys.stderr)
    raise SystemExit(1)


def normalize_language(language: str) -> str:
    language = language.strip().casefold()
    if language in {"en", "eng", "english"}:
        return "eng"
    return language or "und"


def language_matches(stream: SubtitleStream, wanted: str) -> bool:
    wanted = normalize_language(wanted)
    return wanted == "all" or stream.language == wanted


def timestamp_to_ms(timestamp: str) -> int:
    hours, minutes, rest = timestamp.split(":")
    seconds, milliseconds = rest.split(",")
    return (
        ((int(hours) * 60 + int(minutes)) * 60 + int(seconds)) * 1000
        + int(milliseconds)
    )


def parse_srt(path: Path, source_index: int) -> list[Cue]:
    text = path.read_text(encoding="utf-8-sig")
    if not text.strip():
        return []

    cues: list[Cue] = []
    for block in re.split(r"\n\s*\n", text.strip()):
        lines = block.splitlines()
        if lines and lines[0].strip().isdigit():
            lines = lines[1:]
        if not lines:
            continue

        match = TIME_RE.match(lines[0].strip())
        if match is None:
            fail(f"could not parse SRT timing in {path}: {lines[0]}")

        cue_text = "\n".join(lines[1:]).strip()
        cues.append(
            Cue(
                start_ms=timestamp_to_ms(match.group("start")),
                end_ms=timestamp_to_ms(match.group("end")),
                timing=lines[0].strip(),
                text=cue_text,
                source_index=source_index,
            )
        )
    return cues


def write_srt(path: Path, cues: list[Cue]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as output:
        for number, cue in enumerate(cues, start=1):
            output.write(f"{number}\n{cue.timing}\n{cue.text}\n\n")


def probe_subtitle_streams(mkv: Path, ffprobe: str) -> list[SubtitleStream]:
    result = run_command(
        [
            ffprobe,
            "-v",
            "error",
            "-print_format",
            "json",
            "-show_entries",
            (
                "stream=index,codec_type,codec_name:"
                "stream_tags=language,title:"
                "stream_disposition=forced,hearing_impaired"
            ),
            str(mkv),
        ]
    )
    if result.returncode != 0:
        fail(f"ffprobe failed for {mkv}:\n{result.stderr.strip()}")

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        fail(f"ffprobe returned invalid JSON for {mkv}: {exc}")

    streams: list[SubtitleStream] = []
    for stream in payload.get("streams", []):
        if stream.get("codec_type") != "subtitle":
            continue

        tags = stream.get("tags") or {}
        disposition = stream.get("disposition") or {}
        streams.append(
            SubtitleStream(
                index=int(stream["index"]),
                codec=str(stream.get("codec_name") or "unknown"),
                language=normalize_language(str(tags.get("language") or "und")),
                title=str(tags.get("title") or ""),
                forced=bool(disposition.get("forced")),
                hearing_impaired=bool(disposition.get("hearing_impaired")),
            )
        )
    return streams


def print_stream_table(streams: list[SubtitleStream]) -> None:
    if not streams:
        print("No subtitle streams found.")
        return

    print("Subtitle streams:")
    print("  stream  lang  codec                  flags       title")
    print("  ------  ----  ---------------------  ----------  -----")
    for stream in streams:
        title = stream.title or "-"
        print(
            f"  {stream.index:<6}  {stream.language:<4}  "
            f"{stream.codec:<21}  {stream.flags:<10}  {title}"
        )


def stream_to_dict(stream: SubtitleStream) -> dict[str, object]:
    return {
        "index": stream.index,
        "language": stream.language,
        "codec": stream.codec,
        "title": stream.title,
        "forced": stream.is_forced,
        "sdh": stream.is_sdh,
        "text_convertible": stream.is_text_convertible,
        "flags": stream.flags,
    }


def auto_select_streams(
    streams: list[SubtitleStream], language: str, allow_regular_base: bool
) -> list[SubtitleStream]:
    candidates = [stream for stream in streams if language_matches(stream, language)]
    forced = [stream for stream in candidates if stream.is_forced]
    sdh = [stream for stream in candidates if stream.is_sdh and not stream.is_forced]

    selected: list[SubtitleStream] = []
    if sdh:
        selected.append(sdh[0])
    elif allow_regular_base:
        regular = [
            stream
            for stream in candidates
            if not stream.is_forced and not stream.is_sdh
        ]
        if regular:
            selected.append(regular[0])

    selected.extend(forced)
    return selected


def parse_track_spec(spec: str, streams: list[SubtitleStream]) -> list[SubtitleStream]:
    by_index = {stream.index: stream for stream in streams}
    selected: list[SubtitleStream] = []
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if not part.isdigit():
            fail(f"track spec must use numeric stream indexes, got {part!r}")
        stream_index = int(part)
        if stream_index not in by_index:
            fail(f"stream {stream_index} is not a subtitle stream")
        selected.append(by_index[stream_index])

    if not selected:
        fail("no tracks selected")
    return selected


def prompt_for_streams(
    streams: list[SubtitleStream], suggested: list[SubtitleStream]
) -> list[SubtitleStream]:
    print_stream_table(streams)

    default = ",".join(str(stream.index) for stream in suggested)
    prompt = "Tracks to merge"
    if default:
        prompt += f" [{default}]"
    prompt += ": "

    while True:
        answer = input(prompt).strip()
        if not answer and default:
            answer = default
        try:
            return parse_track_spec(answer, streams)
        except SystemExit:
            print("Try again, for example: 2,4", file=sys.stderr)


def select_streams(args: argparse.Namespace, streams: list[SubtitleStream]) -> list[SubtitleStream]:
    if args.tracks:
        return parse_track_spec(args.tracks, streams)

    suggested = auto_select_streams(
        streams,
        language=args.lang,
        allow_regular_base=args.allow_regular_base,
    )

    if args.interactive:
        return prompt_for_streams(streams, suggested)

    if not suggested:
        fail(
            "could not auto-select tracks; use --list, then pass --tracks "
            "with comma-separated subtitle stream indexes",
            [
                "./merge_mkv_subtitles.py --list episode.mkv",
                "./merge_mkv_subtitles.py --tracks 2,4 episode.mkv",
                "./merge_mkv_subtitles.py --interactive episode.mkv",
            ],
        )
    return suggested


def ensure_convertible(streams: list[SubtitleStream]) -> None:
    image_streams = [stream for stream in streams if not stream.is_text_convertible]
    if image_streams:
        indexes = ", ".join(str(stream.index) for stream in image_streams)
        fail(
            "stream(s) "
            f"{indexes} are image-based subtitles; ffmpeg cannot OCR them into SRT"
        )


def output_path_for(mkv: Path, language: str, streams: list[SubtitleStream]) -> Path:
    labels: list[str] = []
    if any(stream.is_sdh for stream in streams):
        labels.append("sdh")
    elif len(streams) > 1:
        labels.append("merged")
    else:
        labels.append("sub")

    if any(stream.is_forced for stream in streams):
        labels.append("forced")

    lang = normalize_language(language)
    if lang == "all":
        lang = "subs"
    return mkv.with_name(f"{mkv.stem}.{lang}.{'-'.join(labels)}.srt")


def extract_stream_to_srt(
    mkv: Path,
    stream: SubtitleStream,
    output: Path,
    ffmpeg: str,
) -> None:
    result = run_command(
        [
            ffmpeg,
            "-nostdin",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(mkv),
            "-map",
            f"0:{stream.index}",
            "-c:s",
            "srt",
            str(output),
        ]
    )
    if result.returncode != 0:
        fail(
            f"ffmpeg failed while extracting stream {stream.index} from {mkv}:\n"
            f"{result.stderr.strip()}"
        )


def merge_streams(
    mkv: Path,
    streams: list[SubtitleStream],
    output: Path,
    args: argparse.Namespace,
) -> dict[str, object]:
    ensure_convertible(streams)
    if output.exists() and not args.overwrite:
        return result_payload(
            status="skipped",
            mkv=mkv,
            output=output,
            streams=streams,
            reason="output already exists; pass --overwrite to replace it",
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    cues: list[Cue] = []
    extracted: list[Path] = []

    with tempfile.TemporaryDirectory(prefix="mkv-sub-merge-", dir=output.parent) as tmpdir:
        tmpdir_path = Path(tmpdir)
        for stream in streams:
            extracted_path = tmpdir_path / f"stream-{stream.index}.srt"
            extract_stream_to_srt(mkv, stream, extracted_path, args.ffmpeg)
            cues.extend(parse_srt(extracted_path, stream.index))

            if args.keep_extracted:
                keep_path = output.with_name(
                    f"{output.stem}.stream-{stream.index}.srt"
                )
                keep_path.write_text(
                    extracted_path.read_text(encoding="utf-8-sig"),
                    encoding="utf-8",
                    newline="\n",
                )
                extracted.append(keep_path)

    if not cues:
        fail("selected tracks did not contain any subtitle cues")

    if not args.no_dedupe:
        deduped: list[Cue] = []
        seen: set[tuple[int, int, str]] = set()
        for cue in cues:
            key = (cue.start_ms, cue.end_ms, cue.text)
            if key not in seen:
                seen.add(key)
                deduped.append(cue)
        cues = deduped

    cues.sort(key=lambda cue: (cue.start_ms, cue.end_ms, cue.source_index, cue.text))
    write_srt(output, cues)

    return result_payload(
        status="wrote",
        mkv=mkv,
        output=output,
        streams=streams,
        cue_count=len(cues),
        extracted=extracted,
    )


def result_payload(
    *,
    status: str,
    mkv: Path,
    output: Path,
    streams: list[SubtitleStream],
    cue_count: int | None = None,
    reason: str | None = None,
    extracted: list[Path] | None = None,
) -> dict[str, object]:
    payload: dict[str, object] = {
        "status": status,
        "input": str(mkv),
        "output": str(output),
        "output_exists": output.exists(),
        "streams": [stream_to_dict(stream) for stream in streams],
        "stream_indexes": [stream.index for stream in streams],
    }
    if cue_count is not None:
        payload["cue_count"] = cue_count
    if reason:
        payload["reason"] = reason
    if extracted:
        payload["extracted"] = [str(path) for path in extracted]
    return payload


def dry_run_payload(
    mkv: Path,
    streams: list[SubtitleStream],
    output: Path,
) -> dict[str, object]:
    ensure_convertible(streams)
    return result_payload(
        status="dry-run",
        mkv=mkv,
        output=output,
        streams=streams,
        reason="no files were written",
    )


def list_payload(mkv: Path, streams: list[SubtitleStream]) -> dict[str, object]:
    return {
        "status": "listed",
        "input": str(mkv),
        "subtitle_streams": [stream_to_dict(stream) for stream in streams],
    }


def emit_payload(payload: dict[str, object], json_output: bool) -> None:
    if json_output:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        return

    print(f"status: {payload['status']}")
    print(f"input: {payload['input']}")
    print(f"output: {payload['output']}")
    print(f"streams: {','.join(str(index) for index in payload['stream_indexes'])}")
    if "cue_count" in payload:
        print(f"cue_count: {payload['cue_count']}")
    if "reason" in payload:
        print(f"reason: {payload['reason']}")
    if "extracted" in payload:
        print("extracted:")
        for path in payload["extracted"]:
            print(f"  {path}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Extract selected subtitle streams from MKV files, convert them to SRT, "
            "sort and renumber all cues, and write a merged .srt."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  ./merge_mkv_subtitles.py --list episode.mkv
  ./merge_mkv_subtitles.py --dry-run episode.mkv
  ./merge_mkv_subtitles.py episode.mkv
  ./merge_mkv_subtitles.py --overwrite episode.mkv
  ./merge_mkv_subtitles.py --tracks 2,4 -o episode.eng.sdh-forced.srt episode.mkv
  ./merge_mkv_subtitles.py --interactive episode.mkv
  ./merge_mkv_subtitles.py --json --dry-run episode.mkv
""",
    )
    parser.add_argument("mkv", nargs="+", type=Path, help="MKV file(s) to process")
    parser.add_argument(
        "--lang",
        default="eng",
        help="language for auto-selection, e.g. eng, en, pol, all (default: eng)",
    )
    parser.add_argument(
        "--tracks",
        help="comma-separated subtitle stream indexes to merge, e.g. 2,4",
    )
    parser.add_argument(
        "--interactive",
        "-i",
        action="store_true",
        help="show subtitle streams and prompt for tracks; never used by default",
    )
    parser.add_argument(
        "--auto",
        action="store_true",
        help="compatibility alias for the default auto-selection behavior",
    )
    parser.add_argument(
        "--allow-regular-base",
        action="store_true",
        help="if no SDH track exists, auto-select a regular non-forced subtitle track",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="list subtitle streams and exit without extracting",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="output SRT path; only valid with one MKV input",
    )
    parser.add_argument(
        "--overwrite",
        "-y",
        action="store_true",
        help="replace an existing output SRT",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print selected streams and output path without writing files",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit one JSON object per input for agent parsing",
    )
    parser.add_argument(
        "--keep-extracted",
        action="store_true",
        help="also write each selected stream as its own .srt next to the output",
    )
    parser.add_argument(
        "--no-dedupe",
        action="store_true",
        help="keep duplicate cues with identical timings and text",
    )
    parser.add_argument("--ffmpeg", default="ffmpeg", help="ffmpeg executable")
    parser.add_argument("--ffprobe", default="ffprobe", help="ffprobe executable")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.output and len(args.mkv) > 1:
        fail(
            "--output can only be used with a single MKV input",
            [
                "./merge_mkv_subtitles.py --output episode.eng.sdh-forced.srt episode.mkv",
                "./merge_mkv_subtitles.py episode1.mkv episode2.mkv",
            ],
        )

    for mkv in args.mkv:
        if not mkv.exists():
            fail(f"{mkv} does not exist")
        if not mkv.is_file():
            fail(f"{mkv} is not a file")

        streams = probe_subtitle_streams(mkv, args.ffprobe)
        if args.list:
            if args.json:
                print(json.dumps(list_payload(mkv, streams), ensure_ascii=False, sort_keys=True))
            else:
                print(f"\n{mkv}")
                print_stream_table(streams)
            continue

        selected = select_streams(args, streams)
        output = args.output or output_path_for(mkv, args.lang, selected)
        if args.dry_run:
            emit_payload(dry_run_payload(mkv, selected, output), args.json)
            continue
        emit_payload(merge_streams(mkv, selected, output, args), args.json)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
