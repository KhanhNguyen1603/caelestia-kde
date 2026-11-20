#pragma once

#include <algorithm>

#include "../Settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

class BorderConfig : public settings::ObjectNode {
    CONFIG_NODE(BorderConfig, settings::ObjectNode)

    CONFIG_PROPERTY(int, thickness, 10)
    CONFIG_PROPERTY(int, rounding, 25)
    CONFIG_PROPERTY(int, roundingTop, 25)
    CONFIG_PROPERTY(int, roundingBottom, 25)
    CONFIG_PROPERTY(int, smoothing, 20)

    Q_PROPERTY(int minThickness READ minThickness CONSTANT)
    Q_PROPERTY(int clampedThickness READ clampedThickness NOTIFY thicknessChanged)

public:
    [[nodiscard]] static int minThickness() { return 2; }

    [[nodiscard]] int clampedThickness() const { return std::max(minThickness(), m_thickness); }

    bool syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) override {
        const auto obj = json.toObject();
        const bool res = ObjectNode::syncJson(json, diagnostics);
        if (res && obj.contains(QStringLiteral("rounding"))) {
            if (!obj.contains(QStringLiteral("roundingTop")))
                set_roundingTop(rounding());
            if (!obj.contains(QStringLiteral("roundingBottom")))
                set_roundingBottom(rounding());
        }
        return res;
    }
};

} // namespace caelestia::config
