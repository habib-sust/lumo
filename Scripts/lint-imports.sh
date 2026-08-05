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
cd "$(dirname "$0")/.." || exit 2

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
