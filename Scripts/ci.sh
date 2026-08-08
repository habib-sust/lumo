#!/bin/bash
#
# The merge gate. Runs everything that can be verified without a physical device.
#
# What this deliberately does NOT cover: AuthorizationCenter, ManagedSettingsStore,
# DeviceActivityCenter, FamilyActivityPicker and all three extensions. Family Controls
# does not function in the Simulator at all, so the shield path is verified by the
# signed-off device matrix in docs/qa/device-matrix.md — a release gate, not a merge
# gate. CI's job is to protect everything else absolutely, so that device testing is a
# short defined list rather than a fishing trip.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

FAILED=()

step() {
    local name="$1"; shift
    echo ""
    echo "───────────────────────────────────────────────────────────"
    echo "▸ $name"
    echo "───────────────────────────────────────────────────────────"
    if "$@"; then
        echo "  ✓ $name"
    else
        echo "  ✗ $name"
        FAILED+=("$name")
    fi
}

# 1. Guards. Cheapest and catch the most catastrophic mistakes — run first.
step "forbidden patterns"   ./Scripts/lint-forbidden.sh
step "import allowlists"    ./Scripts/lint-imports.sh
step "guards self-test"     ./Scripts/test-guards.sh

# 2. The real test suite. Runs on the macOS host in seconds.
step "LumoCore tests (macOS)" swift test --package-path Packages/LumoCore

# 3. Compile everything for iOS. Catches actor-isolation and availability mistakes,
#    which are the majority of extension bugs, with no hardware involved.
step "build for iOS device" \
    xcodebuild build -scheme Lumo -destination 'generic/platform=iOS' \
    CODE_SIGNING_ALLOWED=NO -quiet

# 4. UI tests. Slow (~2 min) but they cover the seams where every device bug lived — SwiftUI
#    presentation semantics, navigation state, and whether saving wipes data. Five of the eight
#    bugs found in the first hardware session were reachable this way.
# Asserts a COUNT, not just an exit code. `-quiet` hides the results, so a green step could
# previously mean "13 tests passed" or "0 tests ran and xcodebuild shrugged" — indistinguishable
# from the outside. A gate you cannot audit is not a gate.
run_ui_tests() {
    local log; log="$(mktemp)"
    xcodebuild test -scheme Lumo \
        -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
        -only-testing:LumoUITests CODE_SIGNING_ALLOWED=NO > "$log" 2>&1
    local status=$?
    local passed failed
    passed="$(grep -cE "Test Case .*' passed" "$log" || true)"
    failed="$(grep -cE "Test Case .*' failed" "$log" || true)"
    echo "    UI tests: $passed passed, $failed failed"
    if [ "$status" -ne 0 ] || [ "$failed" -ne 0 ]; then
        grep -E "error:.*XCTAssert|Test Case .*failed" "$log" | sed 's/^/    /' | head -10
        rm -f "$log"; return 1
    fi
    # The floor that catches a silently-empty run.
    if [ "$passed" -lt 10 ]; then
        echo "    only $passed UI tests ran — expected at least 10; the suite may not be executing"
        rm -f "$log"; return 1
    fi
    rm -f "$log"; return 0
}
step "UI tests (simulator)" run_ui_tests

# 5. Link-graph and size gates. No-ops until T-008 creates the extension targets.
DD="$(xcodebuild -showBuildSettings -scheme Lumo -destination 'generic/platform=iOS' 2>/dev/null \
      | awk '/ BUILT_PRODUCTS_DIR =/{print $3; exit}')"
if [ -n "${DD:-}" ] && [ -d "$DD" ]; then
    for appex in "$DD"/Lumo.app/PlugIns/*.appex; do
        [ -e "$appex" ] || continue
        case "$(basename "$appex")" in
            LumoMonitorExtension.appex)
                step "link graph: monitor" ./Scripts/assert-link-graph.sh "$appex" monitor
                # Binary size is drift detection only; the link graph above is the real
                # protection for the 6 MB ceiling. Authoritative resident figure comes from
                # Instruments on device (T-092): budget 3 MB, alarm 4.5 MB.
                step "size: monitor" ./Scripts/assert-binary-size.sh "$appex" 1258291
                ;;
            LumoShieldConfigExtension.appex)
                step "link graph: shield config" ./Scripts/assert-link-graph.sh "$appex" shieldconfig
                ;;
            LumoShieldActionExtension.appex)
                step "link graph: shield action" ./Scripts/assert-link-graph.sh "$appex" shieldaction
                ;;
        esac
    done
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "✓ CI passed"
    exit 0
fi
echo "✗ CI failed: ${#FAILED[@]} step(s)"
printf '    %s\n' "${FAILED[@]}"
exit 1
