import QtQuick
import Caelestia.Config
import qs.services

StyledText {
    property real fill
    property int grade: Colours.light ? 0 : -25
    property font fontStyle: Tokens.font.icon.small
    // A glyph is rasterised at the size its font asks for, so a bigger icon is a
    // bigger font size: scaling the item instead draws a stretched copy of the glyph
    // the font was rendered at.
    property real fontScale: 1

    swapFromScale: 0.25

    font: Tokens.font.icon.size(Math.round(fontStyle.pointSize * fontScale)).weight(fontStyle.weight).fill(fill.toFixed(1)).grade(grade).build()
}
