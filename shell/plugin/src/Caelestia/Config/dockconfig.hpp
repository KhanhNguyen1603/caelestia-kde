#pragma once

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

#include "../Settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class DockConfig : public settings::ObjectNode {
    CONFIG_NODE(DockConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, persistent, true)
    CONFIG_PROPERTY(bool, islands, false)
    CONFIG_PROPERTY(bool, dodgeWindows, false)
    CONFIG_PROPERTY(bool, dodgeFocusedOnly, false)
    CONFIG_PROPERTY(int, autoHideDelay, 300)
    CONFIG_PROPERTY(QString, position, u"bottom"_s)
    CONFIG_PROPERTY(QString, alignment, u"center"_s)
    CONFIG_PROPERTY(int, size, 56)
    CONFIG_PROPERTY(int, iconSize, 48)
    CONFIG_PROPERTY(int, floatingMargin, 12)
    CONFIG_PROPERTY(int, padding, 10)
    CONFIG_PROPERTY(int, spacing, 8)
    CONFIG_PROPERTY(bool, magnification, true)
    CONFIG_PROPERTY(qreal, maxMagnification, 1.35)
    CONFIG_PROPERTY(qreal, backgroundOpacity, 0.85)
    CONFIG_PROPERTY(QString, indicatorStyle, u"pill"_s)
    CONFIG_PROPERTY(QString, launchingStyle, u"circle"_s)
    CONFIG_PROPERTY(bool, recolourIcons, false)
    CONFIG_PROPERTY(bool, showBadges, true)
    CONFIG_PROPERTY(bool, showLauncherIcon, true)
    CONFIG_PROPERTY(bool, currentDesktopOnly, false)
    CONFIG_ENUM_PROPERTY(DockWindowGrouping, windowGrouping, DockWindowGrouping::Combined)
    CONFIG_PROPERTY(bool, previewOnDesktop, true)
    CONFIG_GLOBAL_PROPERTY(QStringList, pinnedApps, QStringList({ u"firefox"_s, u"org.kde.dolphin"_s }))
    CONFIG_PROPERTY(bool, reserveSpace, true)
    CONFIG_PROPERTY(bool, activeIndicators, true)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(int, dragThreshold, 20)
    CONFIG_PROPERTY(bool, fixedLength, false)
    CONFIG_PROPERTY(int, length, 100)
    CONFIG_PROPERTY(QString, labelMode, u"none"_s)
    CONFIG_PROPERTY(bool, fixedLabelWidth, false)
    CONFIG_PROPERTY(int, labelWidth, 120)
    CONFIG_PROPERTY(int, maxLabelWidth, 180)
    CONFIG_PROPERTY(int, labelSize, 12)
    CONFIG_PROPERTY(QStringList, excludedScreens, QStringList())
};

} // namespace caelestia::config
