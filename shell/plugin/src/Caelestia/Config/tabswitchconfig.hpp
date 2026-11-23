#pragma once

#include "../Settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

class TabSwitchConfig : public settings::ObjectNode {
    CONFIG_NODE(TabSwitchConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, currentDesktopOnly, false)
    CONFIG_PROPERTY(bool, previewOnDesktop, true)
    CONFIG_PROPERTY(bool, showMinimized, true)
    CONFIG_PROPERTY(bool, allScreens, true)
    CONFIG_ENUM_PROPERTY(TabSwitchLayout, layout, TabSwitchLayout::Caelestia)
};

} // namespace caelestia::config
