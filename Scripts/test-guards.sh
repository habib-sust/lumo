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

# Snapshot the tree state up front. The teardown check compares against this rather than
# against "clean", so pre-existing uncommitted work does not read as a leak from this
# script — we only care about what this script itself changed.
#
# Stored in a FILE, not a variable: `printf '%s\n' "$empty"` emits one blank line whereas
# `git status --porcelain` on a clean tree emits nothing, so a variable round-trip made
# every clean-tree run report a phantom deleted line. Two identical commands, two files.
BASELINE_FILE="$(mktemp)"
TMP_PATHS+=("$BASELINE_FILE")
git status --porcelain > "$BASELINE_FILE" 2>/dev/null

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

# --- lint-imports: extension allowlists ---
#
# These run against a throwaway sandbox via LUMO_LINT_ROOT. They used to plant fake targets
# directly in the source tree and `rm -rf` the directory afterwards, which silently deleted
# real extension sources once those directories existed. Never plant inside real targets.
echo "lint-imports"
SANDBOX="$(mktemp -d)"
TMP_PATHS+=("$SANDBOX")

sandbox_reset() { rm -rf "$SANDBOX"; mkdir -p "$SANDBOX"; }

sandbox_plant() {
    mkdir -p "$SANDBOX/$(dirname "$1")"
    printf '%s\n' "$2" > "$SANDBOX/$1"
}

sandbox_reset
sandbox_plant LumoMonitorExtension/x.swift 'import Foundation
import SwiftUI
final class X {}'
LUMO_LINT_ROOT="$SANDBOX" expect_reject ./Scripts/lint-imports.sh "SwiftUI in LumoMonitorExtension"

sandbox_reset
sandbox_plant LumoMonitorExtension/x.swift 'import Foundation
import UIKit
final class X {}'
LUMO_LINT_ROOT="$SANDBOX" expect_reject ./Scripts/lint-imports.sh "UIKit in LumoMonitorExtension (denied)"

sandbox_reset
sandbox_plant LumoShieldConfigExtension/x.swift 'import Foundation
import UIKit
import ManagedSettingsUI
final class X {}'
LUMO_LINT_ROOT="$SANDBOX" expect_accept ./Scripts/lint-imports.sh "UIKit in LumoShieldConfigExtension (permitted)"

sandbox_reset
sandbox_plant Packages/LumoShieldKit/Sources/x.swift 'import Foundation
import FamilyControls
struct X {}'
LUMO_LINT_ROOT="$SANDBOX" expect_reject ./Scripts/lint-imports.sh "FamilyControls in LumoShieldKit (UIKit leak)"

sandbox_reset
sandbox_plant Packages/LumoCore/Sources/x.swift 'import Foundation
import ManagedSettings
struct X {}'
LUMO_LINT_ROOT="$SANDBOX" expect_reject ./Scripts/lint-imports.sh "ManagedSettings import in LumoCore"
echo ""

# --- Confirm the tree really was restored. ---
echo "Teardown"
CURRENT_FILE="$(mktemp)"
TMP_PATHS+=("$CURRENT_FILE")
git status --porcelain > "$CURRENT_FILE" 2>/dev/null
DRIFT="$(diff "$BASELINE_FILE" "$CURRENT_FILE" || true)"
if [ -n "$DRIFT" ]; then
    echo "  ✗ this script changed the working tree:"
    printf '%s\n' "$DRIFT" | sed 's/^/      /'
    echo "    ('>' = left behind, '<' = removed. Either is a bug in this script.)"
    FAIL=$((FAIL + 1))
else
    echo "  ✓ tree byte-identical to pre-run state"
    PASS=$((PASS + 1))
fi

echo ""
echo "test-guards: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
