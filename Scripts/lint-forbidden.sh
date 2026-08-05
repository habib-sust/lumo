#!/bin/bash
#
# Merge-blocking greps for three mistakes that are catastrophic in production,
# invisible in code review, and trivially detectable by a machine.
#
# Run from the repo root. Exits non-zero on any violation.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

FAIL=0
SEARCH_DIRS=()
[ -d Lumo ] && SEARCH_DIRS+=(Lumo)
[ -d Packages ] && SEARCH_DIRS+=(Packages)
[ -d LumoTests ] && SEARCH_DIRS+=(LumoTests)

if [ ${#SEARCH_DIRS[@]} -eq 0 ]; then
    echo "lint-forbidden: no source directories found; nothing to check"
    exit 0
fi

# Collect Swift sources, excluding build products.
swift_files() {
    find "${SEARCH_DIRS[@]}" -name '*.swift' \
        -not -path '*/.build/*' \
        -not -path '*/DerivedData/*' 2>/dev/null
}

# Strip // line comments so prose about a rule never trips the rule itself.
# Known limitation: /* */ block comments are not stripped.
strip_comments() {
    sed 's://.*::'
}

report() {
    # $1 = rule name, $2 = why it matters, $3.. = offending "file:line:text" entries
    local rule="$1" why="$2"; shift 2
    echo ""
    echo "✗ $rule"
    echo "  $why"
    printf '    %s\n' "$@"
    FAIL=1
}

# ---------------------------------------------------------------------------
# 1. application.blockedApplications
#
# It hard-blocks with no shield UI — which removes the ShieldAction entry point,
# i.e. the only place a user can spend coins. It would silently delete the
# product's business model. Always use shield.applications.
# ---------------------------------------------------------------------------
hits=()
while IFS= read -r f; do
    while IFS= read -r line; do hits+=("$f:$line"); done < <(
        strip_comments < "$f" | grep -n 'blockedApplications' || true
    )
done < <(swift_files)
[ ${#hits[@]} -gt 0 ] && report "blockedApplications is forbidden" \
    "It removes the shield, destroying the coin-spend entry point. Use shield.applications." \
    "${hits[@]}"

# ---------------------------------------------------------------------------
# 2. == .approved  /  != .approved
#
# iOS 26.4 added AuthorizationStatus.approvedWithDataAccess. An equality test
# against .approved returns false for a user who granted MORE access than we
# asked for, silently disabling shielding for them. Always switch with
# @unknown default.
# ---------------------------------------------------------------------------
hits=()
while IFS= read -r f; do
    while IFS= read -r line; do hits+=("$f:$line"); done < <(
        strip_comments < "$f" | grep -nE '[!=]=[[:space:]]*(AuthorizationStatus)?\.approved\b' || true
    )
done < <(swift_files)
[ ${#hits[@]} -gt 0 ] && report "Comparing AuthorizationStatus with == / != is forbidden" \
    "iOS 26.4 added .approvedWithDataAccess; equality silently breaks shielding. Use a switch with @unknown default." \
    "${hits[@]}"

# ---------------------------------------------------------------------------
# 3. async anywhere in Packages/
#
# ShieldReconciler.reconcile() must be synchronous. It runs on the foreground
# path before any UI or store work; an await there is a suspension point the
# user can exploit by backgrounding mid-reconcile, leaving shields half-applied.
# Nothing it depends on may be async either.
# ---------------------------------------------------------------------------
if [ -d Packages ]; then
    hits=()
    while IFS= read -r f; do
        while IFS= read -r line; do hits+=("$f:$line"); done < <(
            strip_comments < "$f" | grep -nE '\b(async|await)\b' || true
        )
    done < <(find Packages -name '*.swift' -path '*/Sources/*' -not -path '*/.build/*' 2>/dev/null)
    [ ${#hits[@]} -gt 0 ] && report "async/await is forbidden in Packages/*/Sources" \
        "reconcile() must stay synchronous — an await on the foreground path leaves shields half-applied." \
        "${hits[@]}"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "✓ lint-forbidden: clean"
fi
exit "$FAIL"
