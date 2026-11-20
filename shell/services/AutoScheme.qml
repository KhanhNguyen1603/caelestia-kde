pragma Singleton

import "../utils/scripts/solartime.js" as Solar
import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Singleton {
    id: root

    readonly property bool enabled: GlobalConfig.services.autoSchemeEnabled
    readonly property bool solar: GlobalConfig.services.autoSchemeMode === "solar"

    readonly property var coords: Solar.parseCoords(GlobalConfig.services.weatherLocation || Weather.loc)

    property string lastApplied: ""

    /// The two boundaries for the given moment, as minutes since local
    /// midnight. Falls back to the fixed times whenever solar times are
    /// unavailable, so enabling this without a location still does something
    /// sensible.
    function boundariesFor(date: date): var {
        if (root.solar && root.coords) {
            const times = Solar.solarTimes(date, root.coords.lat, root.coords.lon);
            if (times)
                return {
                    light: times.sunrise,
                    dark: times.sunset
                };
        }

        const light = Solar.parseTime(GlobalConfig.services.autoSchemeLightTime);
        const dark = Solar.parseTime(GlobalConfig.services.autoSchemeDarkTime);
        if (light < 0 || dark < 0 || light === dark)
            return null;
        return {
            light: light,
            dark: dark
        };
    }

    function apply(force: bool): void {
        if (!root.enabled)
            return;

        // The file on disk is the only statement of what mode is in effect, and it is read
        // asynchronously. Deciding before it lands compares the target against the default
        // (dark) and asks the engine to re-derive the scheme the session already had.
        if (!Colours.schemeLoaded)
            return;

        const now = Time.date;
        const bounds = root.boundariesFor(now);
        if (!bounds)
            return;

        const minutes = now.getHours() * 60 + now.getMinutes();
        const target = Solar.isLightAt(minutes, bounds.light, bounds.dark) ? "light" : "dark";

        if (!force && target === root.lastApplied)
            return;

        root.lastApplied = target;

        if ((target === "light") !== Colours.currentLight)
            Colours.setMode(target);
    }

    onEnabledChanged: {
        if (root.enabled)
            root.apply(true);
        else
            root.lastApplied = "";
    }

    Component.onCompleted: root.apply(true)

    Connections {
        function onMinutesChanged(): void {
            root.apply(false);
        }

        target: Time
        enabled: root.enabled
    }

    Connections {
        function onSchemeLoadedChanged(): void {
            if (Colours.schemeLoaded)
                root.apply(true);
        }

        target: Colours
    }

    Connections {
        function onAutoSchemeModeChanged(): void { root.apply(true); }

        function onAutoSchemeLightTimeChanged(): void { root.apply(true); }

        function onAutoSchemeDarkTimeChanged(): void { root.apply(true); }

        function onWeatherLocationChanged(): void { root.apply(true); }

        target: GlobalConfig.services
        enabled: root.enabled
    }

    Connections {
        function onLocChanged(): void { root.apply(true); }

        target: Weather
        enabled: root.enabled
    }
}
