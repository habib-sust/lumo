#!/bin/bash
#
# Enforces the import allowlist for the three app-extension targets.
#
# Why this is mechanical rather than cultural: the DeviceActivityMonitor extension
# has a 6 MB high-watermark and Jetsam kills it instantly past that. When it dies,
# the shield never re-applies — a total product failure that is silent, leaves no
# crash log a user would report, and is invisible in metrics. The documented cause
# of overruns is linking something heavy, so the defence is at the import line.
#
# Run from the repo root. Exits non-zero on any violation.

set -uo pipefail

# Root is overridable so the self-test can point this at a throwaway sandbox instead of
# planting fake targets inside the real source tree. It used to plant them in place and
# `rm -rf` the directory afterwards — which was harmless while those directories did not
# exist, and deleted real source the moment they did.
cd "${LUMO_LINT_ROOT:-$(dirname "$0")/..}" || exit 2

FAIL=0

# Shared allowlist. UIKit is NOT here — it is granted only to the shield-config
# extension below, because ShieldConfiguration is built from UIColor/UIImage/
# UIBlurEffect.Style and (with MemberImportVisibility enabled) it does not arrive
# transitively.
BASE_ALLOWED="Foundation|DeviceActivity|ManagedSettings|ManagedSettingsUI|UserNotifications|LumoCore|LumoShieldKit|os|os.log"

check_target() {
    local dir="$1" allowed="$2" label="$3"

    if [ ! -d "$dir" ]; then
        echo "  – $label: not present yet (created in T-008), skipping"
        return
    fi

    local violations=()
    while IFS= read -r f; do
        while IFS= read -r entry; do
            violations+=("$f:$entry")
        done < <(
            sed 's://.*::' "$f" \
                | grep -nE '^[[:space:]]*(@[a-zA-Z]+[[:space:]]+)?import[[:space:]]+' \
                | sed -E 's/[[:space:]]*(@[a-zA-Z]+[[:space:]]+)?import[[:space:]]+//' \
                | grep -vE ":($allowed)$" || true
        )
    done < <(find "$dir" -name '*.swift' -not -path '*/.build/*' 2>/dev/null)

    if [ ${#violations[@]} -gt 0 ]; then
        echo ""
        echo "✗ $label imports outside its allowlist:"
        printf '    %s\n' "${violations[@]}"
        echo "  Allowed: $(echo "$allowed" | tr '|' ' ')"
        FAIL=1
    else
        echo "  ✓ $label"
    fi
}

echo "lint-imports: checking extension import allowlists"
check_target "LumoMonitorExtension"      "$BASE_ALLOWED"        "LumoMonitorExtension (6 MB ceiling)"
check_target "LumoShieldConfigExtension" "$BASE_ALLOWED|UIKit"  "LumoShieldConfigExtension (UIKit permitted)"
check_target "LumoShieldActionExtension" "$BASE_ALLOWED"        "LumoShieldActionExtension"

# LumoShieldKit must not import FamilyControls.
#
# FamilyControls links SwiftUI, which links UIKit. The monitor extension links this package,
# so a FamilyControls import here hands it a transitive UIKit link against its 6 MB ceiling.
# This regressed once already and was caught only by the link-graph gate — the monitor was
# linking UIKit with no UIKit import in its own sources. Gate it at the import line too,
# because that failure is silent and total in production.
if [ -d Packages/LumoShieldKit/Sources ]; then
    leaks=()
    while IFS= read -r entry; do leaks+=("$entry"); done < <(
        grep -rnE '^[[:space:]]*import[[:space:]]+(FamilyControls|SwiftUI|UIKit|SwiftData)\b' \
            Packages/LumoShieldKit/Sources 2>/dev/null || true
    )
    if [ ${#leaks[@]} -gt 0 ]; then
        echo ""
        echo "✗ LumoShieldKit imports a UI-linking framework:"
        printf '    %s\n' "${leaks[@]}"
        echo "  FamilyControls -> SwiftUI -> UIKit, inherited by the 6 MB monitor extension."
        echo "  Put FamilyControls-dependent code in the app target instead."
        FAIL=1
    else
        echo "  ✓ LumoShieldKit is free of UI-linking frameworks"
    fi
fi

# LumoCore must stay portable — it is the reason ~90% of the risky logic can be
# tested on macOS at all. A single Screen Time or UI import here ends that.
if [ -d Packages/LumoCore/Sources ]; then
    banned=()
    while IFS= read -r entry; do banned+=("$entry"); done < <(
        grep -rnE '^[[:space:]]*import[[:space:]]+(ManagedSettings|ManagedSettingsUI|DeviceActivity|FamilyControls|SwiftUI|SwiftData|UIKit)\b' \
            Packages/LumoCore/Sources 2>/dev/null || true
    )
    if [ ${#banned[@]} -gt 0 ]; then
        echo ""
        echo "✗ LumoCore is no longer portable:"
        printf '    %s\n' "${banned[@]}"
        echo "  LumoCore must be Foundation-only so it compiles and tests on macOS."
        echo "  Screen Time adapters belong in LumoShieldKit."
        FAIL=1
    else
        echo "  ✓ LumoCore is Foundation-only"
    fi
fi

if [ "$FAIL" -eq 0 ]; then
    echo "✓ lint-imports: clean"
fi
exit "$FAIL"
