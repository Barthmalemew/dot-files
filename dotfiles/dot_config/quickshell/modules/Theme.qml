import QtQuick

QtObject {
    // Gruvbox Dark Medium base palette
    readonly property color bg0: "#282828"
    readonly property color bg1: "#3c3836"
    readonly property color bg2: "#504945"
    readonly property color fg0: "#fbf1c7"
    readonly property color fg1: "#ebdbb2"
    readonly property color gray: "#a89984"

    // Semantic accents
    readonly property color primary: "#d79921"
    readonly property color info: "#458588"
    readonly property color success: "#98971a"
    readonly property color danger: "#cc241d"

    // Alpha surfaces for existing translucent style
    readonly property color panelBg: "#ee282828"
    readonly property color surfaceBg: "#cc3c3836"
    readonly property color overlayBg: "#cc282828"
    readonly property color inputBg: "#ee282828"
    readonly property color dimBg: "#99000000"
    readonly property color separator: "#33a89984"
    readonly property color subtleButton: "#33504945"
    readonly property color hoverSurface: "#dd504945"
    readonly property color border: "#66504945"

    // Text on strong accent backgrounds
    readonly property color fgOnAccent: bg0

    // Shared shape tokens
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 16
    readonly property int radiusXl: 18
}
