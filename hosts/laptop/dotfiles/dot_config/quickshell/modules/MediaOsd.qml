import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    Theme { id: theme }

    property bool osdVisible: false
    property string title: "Volume"
    property string titleSymbol: "󰕾"
    property string valueText: "--%"
    property int percent: -1
    property color tone: theme.primary

    readonly property color bg: theme.panelBg
    readonly property color fg: theme.fg1
    readonly property color muted: theme.gray

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value))))
    }

    function show(titleText, symbolText, value, mutedState) {
        title = titleText
        titleSymbol = symbolText

        if (mutedState) {
            valueText = "Muted"
            percent = 0
            tone = theme.gray
        } else {
            percent = clampPercent(value)
            valueText = percent + "%"
            tone = titleText === "Brightness" ? theme.primary : theme.info
        }

        osdVisible = true
        hideTimer.restart()
    }

    function showVolume(value, mutedState) {
        show("Volume", mutedState ? "󰝟" : "󰕾", value, mutedState)
    }

    function showBrightness(value) {
        show("Brightness", "󰃠", value, false)
    }

    function showNightMode(state) {
        title = "Night mode"
        titleSymbol = "󰖔"

        if (state === "on") {
            valueText = "On"
            percent = 100
            tone = theme.primary
        } else if (state === "off") {
            valueText = "Off"
            percent = 0
            tone = theme.gray
        } else if (state === "missing") {
            valueText = "Missing"
            percent = 0
            tone = theme.danger
        } else {
            valueText = "Failed"
            percent = 0
            tone = theme.danger
        }

        osdVisible = true
        hideTimer.restart()
    }

    function showBluetoothMode(state) {
        title = "Bluetooth"
        titleSymbol = "󰂯"

        if (state === "on") {
            valueText = "On"
            percent = 100
            tone = theme.info
        } else if (state === "off") {
            valueText = "Off"
            percent = 0
            tone = theme.gray
        } else if (state === "missing") {
            valueText = "Missing"
            percent = 0
            tone = theme.danger
        } else {
            valueText = "Failed"
            percent = 0
            tone = theme.danger
        }

        osdVisible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer

        interval: 1400
        repeat: false

        onTriggered: root.osdVisible = false
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property var modelData
            readonly property bool isMainDisplay: Quickshell.screens.length > 0 && modelData.name === Quickshell.screens[0].name

            screen: modelData
            focusable: false

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            visible: isMainDisplay && (root.osdVisible || card.opacity > 0.01)

            WlrLayershell.namespace: "quickshell-media-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: card

                readonly property int margin: 18

                x: root.osdVisible ? parent.width - width - margin : parent.width + margin
                y: margin
                width: 250
                height: 78
                radius: 14
                color: root.bg
                border.width: 1
                border.color: theme.border
                opacity: root.osdVisible ? 1.0 : 0.0

                Behavior on x {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 24
                        spacing: 10

                        Text {
                            width: 22
                            height: parent.height

                            text: root.titleSymbol
                            color: root.tone
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            width: parent.width - 22 - value.width - parent.spacing * 2
                            height: parent.height

                            text: root.title
                            color: root.fg
                            font.pixelSize: 16
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            id: value

                            width: Math.max(58, implicitWidth)
                            height: parent.height

                            text: root.valueText
                            color: root.muted
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 8
                        radius: 4
                        color: theme.separator

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, root.percent)) / 100
                            height: parent.height
                            radius: parent.radius
                            color: root.tone

                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
