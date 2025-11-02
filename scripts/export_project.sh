#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'USAGE'
Usage: scripts/export_project.sh [--output <path>] [--format zip|tar] [--ref <git-ref>]

Creates an archive of the project (tracked files only) using git-archive.

Options:
  --output <path>  Destination file. Defaults to dist/<repo>-<ref>.<format>.
  --format <fmt>   Archive format: zip (default) or tar.
  --ref <ref>      Git reference to export. Defaults to HEAD.
  -h, --help       Show this help message and exit.
USAGE
}

OUTPUT=""
FORMAT="zip"
REF="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || { echo "--output requires a value" >&2; exit 1; }
      OUTPUT="$2"
      shift 2
      ;;
    --format)
      [[ $# -ge 2 ]] || { echo "--format requires a value" >&2; exit 1; }
      FORMAT="$2"
      shift 2
      ;;
    --ref)
      [[ $# -ge 2 ]] || { echo "--ref requires a value" >&2; exit 1; }
      REF="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [[ "$FORMAT" != "zip" && "$FORMAT" != "tar" ]]; then
  echo "Unsupported format: $FORMAT" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO_NAME="$(basename "$REPO_ROOT")"
REF_NAME="$(git rev-parse --abbrev-ref "$REF" 2>/dev/null || echo "$REF")"
REF_SAFE="${REF_NAME//\//-}"

if [[ -z "$OUTPUT" ]]; then
  mkdir -p "$REPO_ROOT/dist"
  EXT="$FORMAT"
  OUTPUT="$REPO_ROOT/dist/${REPO_NAME}-${REF_SAFE}.${EXT}"
else
  mkdir -p "$(dirname "$OUTPUT")"
fi

case "$FORMAT" in
  zip)
    git -C "$REPO_ROOT" archive --format=zip "$REF" -o "$OUTPUT"
    ;;
  tar)
    git -C "$REPO_ROOT" archive --format=tar "$REF" -o "$OUTPUT"
    ;;
esac

echo "Archive created at: $OUTPUT"
