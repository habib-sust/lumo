#!/bin/bash
#
# assert-binary-size.sh <path-to-.appex-or-binary> <max-bytes>
#
# Drift detection, not the primary defence — binary size is not resident memory. The
# link-graph gate is the real protection for the 6 MB DeviceActivityMonitor ceiling;
# this catches a binary quietly growing over time, which is usually the first visible
# symptom of a dependency creeping in.
#
# The authoritative number comes from Instruments on a device (T-092): budget 3 MB
# resident, alarm at 4.5 MB, hard ceiling 6 MB.

set -uo pipefail

TARGET="${1:-}"
MAX="${2:-}"

if [ -z "$TARGET" ] || [ -z "$MAX" ]; then
    echo "usage: $0 <path-to-.appex-or-binary> <max-bytes>" >&2
    exit 2
fi

if [ ! -e "$TARGET" ]; then
    echo "assert-binary-size: $TARGET not built yet — skipping (extensions land in T-008)"
    exit 0
fi

BIN="$TARGET"
if [ -d "$TARGET" ]; then
    NAME="$(basename "$TARGET" .appex)"
    BIN="$TARGET/$NAME"
    [ -f "$BIN" ] || { echo "assert-binary-size: no executable at $BIN" >&2; exit 2; }
fi

SIZE="$(stat -f%z "$BIN")"
PCT=$(( SIZE * 100 / MAX ))

if [ "$SIZE" -gt "$MAX" ]; then
    echo "✗ assert-binary-size: $(basename "$BIN") is ${SIZE}B, over the ${MAX}B budget (${PCT}%)"
    echo "  Check what was added to the link graph. Run assert-link-graph.sh too."
    exit 1
fi

echo "✓ assert-binary-size: $(basename "$BIN") ${SIZE}B / ${MAX}B (${PCT}%)"
