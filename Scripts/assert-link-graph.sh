#!/bin/bash
#
# assert-link-graph.sh <path-to-.appex-or-binary> <monitor|shieldconfig|shieldaction>
#
# Inspects what an extension actually LINKS, rather than what its source appears to import.
# This is the real protection for the DeviceActivityMonitor's 6 MB high-watermark: the
# documented cause of overruns is linking something heavy, and a transitive link through a
# shared package shows up in no import line.
#
# Two things this script learned the hard way:
#
#  1. In Debug builds Xcode uses "debug dylib" packaging — the real code lives in
#     <Name>.debug.dylib and the .appex executable is a thin launcher. Running otool -L on
#     just the executable reported "clean (2 libs)" for an extension that demonstrably links
#     UIKit. So every Mach-O in the bundle is inspected, not only the entry point.
#
#  2. A gate that cannot fail is worse than no gate, because it reads as coverage. So each
#     profile declares a CANARY framework it must find. If the canary is missing, the gate
#     itself is broken — wrong path, new packaging layout, stripped binary — and it fails
#     loudly instead of passing silently.

set -uo pipefail

TARGET="${1:-}"
PROFILE="${2:-monitor}"

if [ -z "$TARGET" ]; then
    echo "usage: $0 <path-to-.appex-or-binary> <monitor|shieldconfig|shieldaction>" >&2
    exit 2
fi

if [ ! -e "$TARGET" ]; then
    echo "assert-link-graph: $TARGET not built yet — skipping"
    exit 0
fi

case "$PROFILE" in
    monitor)
        # Strictest: no UI frameworks at all. This is the 6 MB target.
        FORBIDDEN="UIKit|SwiftUI|CoreData|SwiftData|WebKit|AVFoundation|CoreImage|MapKit|ManagedSettingsUI"
        CANARY="DeviceActivity"
        ;;
    shieldconfig)
        # UIKit is REQUIRED here: ShieldConfiguration is built from UIColor/UIImage/
        # UIBlurEffect.Style, and MemberImportVisibility stops it arriving transitively.
        FORBIDDEN="SwiftUI|CoreData|SwiftData|WebKit|AVFoundation|MapKit"
        CANARY="ManagedSettingsUI"
        ;;
    shieldaction)
        FORBIDDEN="UIKit|SwiftUI|CoreData|SwiftData|WebKit|AVFoundation|MapKit"
        CANARY="ManagedSettings"
        ;;
    *) echo "assert-link-graph: unknown profile '$PROFILE'" >&2; exit 2 ;;
esac

# Gather every Mach-O in the bundle: the executable, the debug dylib, any embedded libs.
BINARIES=()
if [ -d "$TARGET" ]; then
    while IFS= read -r f; do
        file -b "$f" 2>/dev/null | grep -q "Mach-O" && BINARIES+=("$f")
    done < <(find "$TARGET" -type f -perm +111 -o -type f -name '*.dylib' 2>/dev/null | sort -u)
else
    BINARIES=("$TARGET")
fi

if [ ${#BINARIES[@]} -eq 0 ]; then
    echo "✗ assert-link-graph: no Mach-O binaries found in $TARGET" >&2
    exit 1
fi

LINKED=""
for b in "${BINARIES[@]}"; do
    LINKED+=$'\n'"$(otool -L "$b" 2>/dev/null | tail -n +2 | awk '{print $1}')"
done
LINKED="$(printf '%s\n' "$LINKED" | grep -v '^$' | sort -u)"

NAME="$(basename "$TARGET")"

# Non-vacuity check FIRST — otherwise a clean result is meaningless.
if ! printf '%s\n' "$LINKED" | grep -qE "/${CANARY}\.framework/"; then
    echo "✗ assert-link-graph: $NAME [$PROFILE] — canary '$CANARY' not found in the link graph."
    echo "  The gate is not inspecting real binaries, so it cannot detect a violation either."
    echo "  Inspected ${#BINARIES[@]} Mach-O file(s):"
    printf '    %s\n' "${BINARIES[@]#"$TARGET/"}"
    echo "  Linked libraries seen:"
    printf '%s\n' "$LINKED" | sed 's/^/    /'
    exit 1
fi

HITS="$(printf '%s\n' "$LINKED" | grep -E "/($FORBIDDEN)\.framework/" || true)"
if [ -n "$HITS" ]; then
    echo "✗ assert-link-graph: $NAME [$PROFILE] links forbidden frameworks:"
    printf '%s\n' "$HITS" | sed 's/^/    /'
    echo "  A heavy link is the documented cause of 6 MB Jetsam kills in the monitor"
    echo "  extension. When it dies the shield never re-applies — silently."
    exit 1
fi

COUNT="$(printf '%s\n' "$LINKED" | wc -l | tr -d ' ')"
echo "✓ assert-link-graph: $NAME [$PROFILE] clean — ${#BINARIES[@]} binary/ies, $COUNT libs, canary $CANARY present"
