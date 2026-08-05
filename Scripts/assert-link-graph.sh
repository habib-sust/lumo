#!/bin/bash
#
# assert-link-graph.sh <path-to-.appex-or-binary> [monitor|shield]
#
# Inspects what an extension binary actually links, rather than what its source
# appears to import. This is the real protection for the DeviceActivityMonitor's 6 MB
# high-watermark: the documented cause of overruns is linking something heavy, and a
# transitive link through a shared package will not show up in any import line.
#
# Profile "monitor" is the strict one (no UI frameworks at all). Profile "shield"
# additionally permits UIKit, because ShieldConfiguration is built from UIColor,
# UIImage and UIBlurEffect.Style.

set -uo pipefail

TARGET="${1:-}"
PROFILE="${2:-monitor}"

if [ -z "$TARGET" ]; then
    echo "usage: $0 <path-to-.appex-or-binary> [monitor|shield]" >&2
    exit 2
fi

if [ ! -e "$TARGET" ]; then
    echo "assert-link-graph: $TARGET not built yet — skipping (extensions land in T-008)"
    exit 0
fi

# Accept either a bundle or a bare Mach-O.
BIN="$TARGET"
if [ -d "$TARGET" ]; then
    NAME="$(basename "$TARGET" .appex)"
    BIN="$TARGET/$NAME"
    if [ ! -f "$BIN" ]; then
        echo "assert-link-graph: no executable at $BIN" >&2
        exit 2
    fi
fi

case "$PROFILE" in
    monitor) FORBIDDEN="UIKit|SwiftUI|CoreData|SwiftData|WebKit|AVFoundation|CoreImage|MapKit" ;;
    shield)  FORBIDDEN="SwiftUI|CoreData|SwiftData|WebKit|AVFoundation|MapKit" ;;
    *) echo "assert-link-graph: unknown profile '$PROFILE'" >&2; exit 2 ;;
esac

LINKED="$(otool -L "$BIN" 2>/dev/null | tail -n +2 | awk '{print $1}')"
if [ -z "$LINKED" ]; then
    echo "assert-link-graph: could not read link graph of $BIN" >&2
    exit 2
fi

HITS="$(printf '%s\n' "$LINKED" | grep -E "/($FORBIDDEN)\.framework/" || true)"

if [ -n "$HITS" ]; then
    echo "✗ assert-link-graph: $(basename "$BIN") [$PROFILE] links forbidden frameworks:"
    printf '%s\n' "$HITS" | sed 's/^/    /'
    echo "  A heavy link is the documented cause of 6 MB Jetsam kills in the monitor"
    echo "  extension. When it dies the shield never re-applies — silently."
    exit 1
fi

echo "✓ assert-link-graph: $(basename "$BIN") [$PROFILE] clean ($(printf '%s\n' "$LINKED" | wc -l | tr -d ' ') libs)"
