import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root
    Theme { id: theme }

    required property var lockScreen

    property bool menuVisible: false
    property string confirmingAction: ""

    readonly property color accent: theme.primary
    readonly property color bg:     theme.panelBg
    readonly property color bg2:    theme.surfaceBg
    readonly property color fg:     theme.fg1
    readonly property color muted:  theme.gray
    readonly property color danger: theme.danger

    property var actions: [
        {
            key: "lock",
            label: "Lock",
            symbol: "",
            command: []
        },
        {
            key: "hibernate",
            label: "Hibernate",
            symbol: "",
            command: ["loginctl", "hibernate"]
        },
        {
            key: "restart",
            label: "Restart",
            symbol: "",
            command: ["loginctl", "reboot"]
        },
        {
            key: "shutdown",
            label: "Shutdown",
            symbol: "",
            command: ["loginctl", "poweroff"]
        }
    ]

    function toggle() {
        if (menuVisible)
            close()
        else
            open()
    }

    function open() {
        confirmingAction = ""
        menuVisible = true
    }

    function close() {
        confirmingAction = ""
        menuVisible = false
    }

    function selectAction(action) {
        if (action.key === "lock") {
            close()
            lockScreen.lock()
            return
        }

        if (confirmingAction !== action.key) {
            confirmingAction = action.key
            return
        }

        close()
        Quickshell.execDetached(action.command)
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property var modelData
            readonly property bool isMainDisplay: modelData.name === "DP-1"

            screen: modelData
            focusable: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            visible: root.menuVisible && isMainDisplay

            WlrLayershell.namespace: "quickshell-power-menu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (visible)
                    keyboardSink.forceActiveFocus()
            }

            Item {
                id: keyboardSink

                anchors.fill: parent
                focus: root.menuVisible

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.close()
                        event.accepted = true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: theme.dimBg

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.close()
                    }
                }

                Rectangle {
                    id: panel

                    anchors.centerIn: parent
                    width: Math.min(504, parent.width - 32)
                    height: 164
                    radius: 16
                    color: root.bg

                    border.width: 1
                    border.color: theme.border

                    MouseArea {
                        anchors.fill: parent
                    }

                    Row {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 36, 456)
                        height: 96
                        spacing: 18

                        Repeater {
                            model: root.actions

                            delegate: Rectangle {
                                required property var modelData

                                width: 96
                                height: 96
                                radius: 14

                                readonly property bool confirming: root.confirmingAction === modelData.key
                                readonly property bool dangerous: modelData.key === "shutdown" || modelData.key === "restart"
                                readonly property color activeColor: dangerous ? root.danger : root.accent

                                color: confirming ? activeColor : (actionMouse.containsMouse ? theme.hoverSurface : root.bg2)
                                border.width: actionMouse.containsMouse && !confirming ? 1 : 0
                                border.color: activeColor

                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - 14
                                    spacing: 8

                                    Text {
                                        width: parent.width
                                        height: 34

                                        text: modelData.symbol
                                        color: confirming ? theme.fgOnAccent : root.fg
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 30
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        width: parent.width
                                        height: 18

                                        text: confirming ? "Confirm" : modelData.label
                                        color: confirming ? theme.fgOnAccent : root.fg
                                        font.pixelSize: 12
                                        font.bold: confirming
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: actionMouse

                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onClicked: root.selectAction(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
