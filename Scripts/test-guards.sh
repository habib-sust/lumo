#!/bin/bash
#
# Tests the CI guards by planting a violation for each rule and asserting the guard
# rejects it. A guard that never fires is worse than no guard: it reads as coverage.
#
# Every temp file is removed on exit, including on failure or interrupt.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

PASS=0
FAIL=0
TMP_PATHS=()

cleanup() {
    for p in ${TMP_PATHS+"${TMP_PATHS[@]}"}; do rm -rf "$p"; done
}
trap cleanup EXIT INT TERM

# plant <path> <contents>
plant() {
    mkdir -p "$(dirname "$1")"
    printf '%s\n' "$2" > "$1"
    TMP_PATHS+=("$1")
}

# expect_reject <guard script> <rule name>
expect_reject() {
    local script="$1" name="$2"
    if "$script" >/dev/null 2>&1; then
        echo "  ✗ $name — guard PASSED but should have failed"
        FAIL=$((FAIL + 1))
    else
        echo "  ✓ $name — correctly rejected"
        PASS=$((PASS + 1))
    fi
}

# expect_accept <guard script> <rule name>
expect_accept() {
    local script="$1" name="$2"
    if "$script" >/dev/null 2>&1; then
        echo "  ✓ $name — correctly accepted"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $name — guard FAILED but should have passed"
        FAIL=$((FAIL + 1))
    fi
}

# Snapshot the tree state up front. The teardown check compares against this rather
# than against "clean", so pre-existing uncommitted work does not read as a leak from
# this script — we only care about what the script itself left behind.
BASELINE_STATUS="$(git status --porcelain 2>/dev/null)"

echo "test-guards: planting violations"
echo ""

# --- Baseline: the real tree must be clean, or nothing below means anything. ---
echo "Baseline"
expect_accept ./Scripts/lint-forbidden.sh "lint-forbidden on clean tree"
expect_accept ./Scripts/lint-imports.sh   "lint-imports on clean tree"
echo ""

# --- lint-forbidden rule 1: blockedApplications ---
echo "lint-forbidden"
plant Lumo/__guardtest_blocked.swift \
'import Foundation
func bad() { store.application.blockedApplications = [] }'
expect_reject ./Scripts/lint-forbidden.sh "blockedApplications"
rm -f Lumo/__guardtest_blocked.swift

# --- rule 2: == .approved (and the qualified form) ---
plant Lumo/__guardtest_approved.swift \
'import Foundation
func bad() -> Bool { return status == .approved }'
expect_reject ./Scripts/lint-forbidden.sh "== .approved"
rm -f Lumo/__guardtest_approved.swift

plant Lumo/__guardtest_approved2.swift \
'import Foundation
func bad() -> Bool { return s != AuthorizationStatus.approved }'
expect_reject ./Scripts/lint-forbidden.sh "!= AuthorizationStatus.approved"
rm -f Lumo/__guardtest_approved2.swift

# --- rule 3: async inside Packages/*/Sources ---
plant Packages/LumoCore/Sources/LumoCore/__guardtest_async.swift \
'import Foundation
func bad() async -> Int { 0 }'
expect_reject ./Scripts/lint-forbidden.sh "async in Packages/*/Sources"
rm -f Packages/LumoCore/Sources/LumoCore/__guardtest_async.swift

# --- Comment stripping: prose about a rule must not trip the rule. ---
# This matters because the codebase documents these rules in comments; without
# stripping, the guards would fail on their own documentation.
plant Lumo/__guardtest_comment.swift \
'import Foundation
// Never use blockedApplications, and never write == .approved here.
func fine() {}'
expect_accept ./Scripts/lint-forbidden.sh "comments mentioning banned patterns are ignored"
rm -f Lumo/__guardtest_comment.swift
echo ""

# --- lint-imports: disallowed import in the monitor extension ---
echo "lint-imports"
plant LumoMonitorExtension/__guardtest_import.swift \
'import Foundation
import SwiftUI
final class X {}'
expect_reject ./Scripts/lint-imports.sh "SwiftUI in LumoMonitorExtension"
rm -rf LumoMonitorExtension

# --- UIKit is denied to the monitor, permitted to shield-config ---
plant LumoMonitorExtension/__guardtest_uikit.swift \
'import Foundation
import UIKit
final class X {}'
expect_reject ./Scripts/lint-imports.sh "UIKit in LumoMonitorExtension (denied)"
rm -rf LumoMonitorExtension

plant LumoShieldConfigExtension/__guardtest_uikit.swift \
'import Foundation
import UIKit
import ManagedSettingsUI
final class X {}'
expect_accept ./Scripts/lint-imports.sh "UIKit in LumoShieldConfigExtension (permitted)"
rm -rf LumoShieldConfigExtension

# --- LumoCore losing portability ---
plant Packages/LumoCore/Sources/LumoCore/__guardtest_ms.swift \
'import Foundation
import ManagedSettings
struct X {}'
expect_reject ./Scripts/lint-imports.sh "ManagedSettings import in LumoCore"
rm -f Packages/LumoCore/Sources/LumoCore/__guardtest_ms.swift
echo ""

# --- Confirm the tree really was restored. ---
echo "Teardown"
LEAKED="$(diff <(printf '%s\n' "$BASELINE_STATUS") <(git status --porcelain 2>/dev/null) | grep '^>' || true)"
if [ -n "$LEAKED" ]; then
    echo "  ✗ this script leaked files into the working tree:"
    printf '%s\n' "$LEAKED" | sed 's/^> /      /'
    FAIL=$((FAIL + 1))
else
    echo "  ✓ no files leaked (tree matches pre-run state)"
    PASS=$((PASS + 1))
fi

echo ""
echo "test-guards: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
