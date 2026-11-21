#!/usr/bin/env bash
# suite: fast

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERACTIONS="$REPO_ROOT/shell/modules/drawers/Interactions.qml"
REGIONS="$REPO_ROOT/shell/modules/drawers/Regions.qml"
PANELS="$REPO_ROOT/shell/modules/drawers/Panels.qml"
DOCK_WRAPPER="$REPO_ROOT/shell/modules/dock/DockWrapper.qml"
CLIP_WRAPPER="$REPO_ROOT/shell/modules/bar/popouts/ClipWrapper.qml"
DOCK_ITEM="$REPO_ROOT/shell/components/widgets/DockItem.qml"
DOCK_MANAGER="$REPO_ROOT/shell/services/DockManager.qml"
BAR_DOCK="$REPO_ROOT/shell/modules/bar/components/Dock.qml"
DOCK_HOVER="$REPO_ROOT/shell/modules/bar/popouts/DockHover.qml"
EXCLUSIONS="$REPO_ROOT/shell/modules/drawers/Exclusions.qml"

test_dock_interaction_area_is_bounded_to_panel_geometry() {
    local interactions
    interactions="$(cat "$INTERACTIONS")"

    assert_contains "$interactions" 'function inDockPanelArea(x: real, y: real, requireVisible = false): bool' \
        "Interactions must test whether coordinates fall inside the dock panel bounds"
    assert_contains "$interactions" 'x >= dockPanel.x && x <= dockPanel.x + dockPanel.width' \
        "interaction check must clamp horizontal reach to panel bounds"
    assert_contains "$interactions" 'y >= dockPanel.y && y <= dockPanel.y + dockPanel.height' \
        "interaction check must clamp vertical reach to panel bounds"
    assert_contains "$interactions" 'const thickness = Math.max(Config.border.thickness, Config.dockPanel.dragThreshold, 20);' \
        "hidden dock interaction area must limit reach so clicks elsewhere on screen dismiss open drawers"
}

test_regions_input_mask_subtracts_only_bounded_dock_area() {
    local regions
    regions="$(cat "$REGIONS")"

    assert_contains "$regions" 'if (root.dockPanel.visible) return root.dockPanel.width;' \
        "input region subtraction must use visible dock width"
    assert_contains "$regions" 'if (root.dockPanel.visible) return root.dockPanel.height;' \
        "input region subtraction must use visible dock height"
    assert_contains "$regions" 'return root.Config.dockPanel.showOnHover ? root.edgeExtent(root.Config.dockPanel.dragThreshold) : 0;' \
        "hidden dock input subtraction must collapse to edge reveal extent"
    assert_contains "$regions" 'intersection: Intersection.Subtract' \
        "dock region must subtract from the drawer mask so clicks reach the dock panel"
}

test_drawer_offsets_and_thickness_honor_dock_visibility() {
    local panels wrapper
    panels="$(cat "$PANELS")"
    wrapper="$(cat "$DOCK_WRAPPER")"

    assert_contains "$panels" 'dockLeftOffset: (dockPanel && dockPanel.position === "left" && !dockPanel.disabled && (dockPanel.visible || dockPanel.shouldBeVisible)) ? dockPanel.visualThickness : 0' \
        "drawer offsets on the left must honor dock visibility"
    assert_contains "$panels" 'dockRightOffset: (dockPanel && dockPanel.position === "right" && !dockPanel.disabled && (dockPanel.visible || dockPanel.shouldBeVisible)) ? dockPanel.visualThickness : 0' \
        "drawer offsets on the right must honor dock visibility"
    assert_contains "$panels" 'dockTopOffset: (dockPanel && dockPanel.position === "top" && !dockPanel.disabled && (dockPanel.visible || dockPanel.shouldBeVisible)) ? dockPanel.visualThickness : 0' \
        "drawer offsets on the top must honor dock visibility"
    assert_contains "$panels" 'dockBottomOffset: (dockPanel && dockPanel.position === "bottom" && !dockPanel.disabled && (dockPanel.visible || dockPanel.shouldBeVisible)) ? dockPanel.visualThickness : 0' \
        "drawer offsets on the bottom must honor dock visibility"

    assert_contains "$wrapper" 'readonly property int visualThickness: !disabled && (Config.dockPanel.persistent || visibilities.dockPanel || shouldBeVisible || root.visible)' \
        "dock visual thickness must be conditional on visibility and persistent configuration"
    assert_contains "$wrapper" 'readonly property int exclusiveZone: Config.dockPanel.reserveSpace' \
        "dock exclusion zone must respect reserveSpace setting"
}

test_dock_popouts_deform_with_lamp_effect_and_clamp_to_panel() {
    local clip
    clip="$(cat "$CLIP_WRAPPER")"

    assert_contains "$clip" 'readonly property bool isLampActive: !content.isDetached && (isHorizontal ? (effectivePanelWidth < content.nonAnimWidth) : (panelHeight < content.nonAnimHeight))' \
        "popout lamp animation must activate when panel length is narrower than popout dimension"
    assert_contains "$clip" 'readonly property real lampScaleX:' \
        "popout lamp effect must compute horizontal scale interpolation"
    assert_contains "$clip" 'readonly property real lampScaleY:' \
        "popout lamp effect must compute vertical scale interpolation"
    assert_contains "$clip" 'const minX = Math.max(0, panelLeft);' \
        "popout target position must clamp to panel left bound"
    assert_contains "$clip" 'const maxX = Math.min(parent.width - content.nonAnimWidth, effectivePanelRight - content.nonAnimWidth);' \
        "popout target position must clamp to effective panel right bound to prevent overhang"
    assert_contains "$clip" 'content.sourcePanel = "";' \
        "sourcePanel tracking must reset when popout offset scale closes"
}

test_dock_item_magnification_uses_fast_spatial_motion_token() {
    local item
    item="$(cat "$DOCK_ITEM")"

    assert_contains "$item" 'Behavior on currentScale {' \
        "dock item magnification scale must be smoothly animated"
    assert_contains "$item" 'type: Anim.FastSpatial' \
        "dock item magnification animation must strictly follow motion policy tokens"
    assert_not_contains "$item" 'duration: 120' \
        "dock item magnification must never use literal durations"
}

test_dock_item_badges_query_by_app_class_with_id_fallback() {
    local item
    item="$(cat "$DOCK_ITEM")"

    assert_contains "$item" 'LauncherEntry.forApp(root.modelData.appClass || root.modelData.id)' \
        "dock item badges must query by appClass before per-window id to resolve launcher entry"
}

test_dock_manager_centralizes_state_and_bar_dock_delegates() {
    local manager bar_dock
    manager="$(cat "$DOCK_MANAGER")"
    bar_dock="$(cat "$BAR_DOCK")"

    assert_contains "$manager" 'pragma Singleton' \
        "DockManager must be a singleton service"
    assert_contains "$manager" 'readonly property var effectivePinnedApps:' \
        "DockManager must centrally own pinned applications resolution"
    assert_contains "$manager" 'readonly property alias listModel: dockModel' \
        "DockManager must expose listModel for views"

    assert_contains "$bar_dock" 'DockItem {' \
        "bar dock must delegate tile rendering to shared DockItem component"
    assert_contains "$bar_dock" 'model: DockManager.listModel' \
        "bar dock must read model from DockManager"
    assert_not_contains "$bar_dock" 'activeIndicators: Config.bar.dock' \
        "bar dock must not reference obsolete Config.bar.dock properties"
}

test_dock_hover_preview_tracks_source_panel() {
    local hover
    hover="$(cat "$DOCK_HOVER")"

    assert_contains "$hover" 'root.popouts.sourcePanel' \
        "dock hover preview must track whether summoned by bar or floating dock"
}

test_exclusions_do_not_double_count_border_on_dock_edge() {
    local exclusions
    exclusions="$(cat "$EXCLUSIONS")"

    assert_contains "$exclusions" 'dockPanelPosition === "bottom" ? (root.dockPanel && !root.dockPanel.disabled ? root.dockPanel.exclusiveZone : defaultBorderExclusion) : defaultBorderExclusion' \
        "bottom exclusion must not unconditionally add defaultBorderExclusion to dockPanel exclusive zone"
    assert_contains "$exclusions" 'dockPanelPosition === "top" ? (root.dockPanel && !root.dockPanel.disabled ? root.dockPanel.exclusiveZone : defaultBorderExclusion) : defaultBorderExclusion' \
        "top exclusion must not unconditionally add defaultBorderExclusion to dockPanel exclusive zone"
    assert_contains "$exclusions" 'dockPanelPosition === "left" ? (root.dockPanel && !root.dockPanel.disabled ? root.dockPanel.exclusiveZone : defaultBorderExclusion) : defaultBorderExclusion' \
        "left exclusion must not unconditionally add defaultBorderExclusion to dockPanel exclusive zone"
    assert_contains "$exclusions" 'dockPanelPosition === "right" ? (root.dockPanel && !root.dockPanel.disabled ? root.dockPanel.exclusiveZone : defaultBorderExclusion) : defaultBorderExclusion' \
        "right exclusion must not unconditionally add defaultBorderExclusion to dockPanel exclusive zone"
    assert_not_contains "$exclusions" '+ (dockPanelPosition === "bottom" ? dockPanelThickness : 0)' \
        "bottom exclusion must not add dock thickness on top of default border exclusion"
}

test_dock_item_uses_anchor_changes_to_avoid_stale_anchors() {
    local item
    item="$(cat "$DOCK_ITEM")"

    assert_contains "$item" 'AnchorChanges {' \
        "dock item must use AnchorChanges to cleanly detach stale anchors across position transitions"
    assert_contains "$item" 'anchors.horizontalCenter: iconContainer.horizontalCenter' \
        "dock indicators must anchor their horizontal center to iconContainer"
    assert_not_contains "$item" 'anchors.bottom: (root.isHorizontal && root.position === "bottom") ? root.bottom : undefined' \
        "delegateItem must not use ternary anchor bindings to undefined"
    assert_not_contains "$item" 'bottom: (root.position === "bottom" || root.position === "top") ? (root.position === "top" ? undefined : parent.bottom) : undefined' \
        "indicatorContainer must not use ternary anchor bindings to undefined"
}

run_tests
