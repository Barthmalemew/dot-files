import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

Scope {
    id: root
    Theme { id: theme }

    property bool panelVisible: false

    readonly property color accent: theme.primary
    readonly property color bg:     theme.panelBg
    readonly property color bg2:    theme.surfaceBg
    readonly property color fg:     theme.fg1
    readonly property color muted:  theme.gray
    readonly property color danger: theme.danger

    function toggle() {
        if (panelVisible)
            close()
        else
            open()
    }

    function open() {
        panelVisible = true
    }

    function close() {
        panelVisible = false
    }

    function dismissAll() {
        const notifications = notificationServer.trackedNotifications.values.slice()

        for (let i = 0; i < notifications.length; i++)
            notifications[i].dismiss()
    }

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(notification) {
            notification.tracked = true
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property var modelData

            readonly property bool isMainDisplay: Quickshell.screens.length > 0 && modelData.name === Quickshell.screens[0].name

            screen: modelData
            focusable: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            visible: isMainDisplay && (root.panelVisible || dim.opacity > 0.01 || panel.x > -panel.width - panel.sideMargin + 1)

            WlrLayershell.namespace: "quickshell-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.panelVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (visible)
                    keyboardSink.forceActiveFocus()
            }

            Item {
                id: keyboardSink

                anchors.fill: parent
                focus: root.panelVisible

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.close()
                        event.accepted = true
                    }
                }

                Rectangle {
                    id: dim

                    anchors.fill: parent
                    color: theme.dimBg
                    opacity: root.panelVisible ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: root.close()
                    }
                }

                Rectangle {
                    id: panel

                    readonly property int sideMargin: 18

                    x: root.panelVisible ? sideMargin : -width - sideMargin
                    y: 18
                    width: Math.min(440, parent.width - sideMargin * 2)
                    height: parent.height - 36
                    radius: 16
                    color: root.bg

                    Behavior on x {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        Row {
                            width: parent.width
                            height: 34
                            spacing: 10

                            Text {
                                width: parent.width - clearButton.width - closeButton.width - parent.spacing * 2
                                height: parent.height

                                text: "Notifications"
                                color: root.fg
                                font.pixelSize: 22
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                id: clearButton

                                width: 104
                                height: parent.height
                                radius: 9
                                color: clearMouse.containsMouse ? root.accent : root.bg2
                                opacity: notificationServer.trackedNotifications.values.length > 0 ? 1.0 : 0.45

                                Row {
                                    anchors.centerIn: parent
                                    height: parent.height
                                    spacing: 6

                                    Text {
                                        height: parent.height

                                        text: "󰆴"
                                        color: clearMouse.containsMouse ? theme.fgOnAccent : root.fg
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 15
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        height: parent.height

                                        text: "Clear all"
                                        color: clearMouse.containsMouse ? theme.fgOnAccent : root.fg
                                        font.pixelSize: 13
                                        font.bold: clearMouse.containsMouse
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    id: clearMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: notificationServer.trackedNotifications.values.length > 0

                                    onClicked: root.dismissAll()
                                }
                            }

                            Rectangle {
                                id: closeButton

                                width: 34
                                height: parent.height
                                radius: 9
                                color: closeMouse.containsMouse ? root.danger : root.bg2

                                Text {
                                    anchors.centerIn: parent

                                    text: "󰅖"
                                    color: closeMouse.containsMouse ? theme.fgOnAccent : root.fg
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 18
                                }

                                MouseArea {
                                    id: closeMouse

                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onClicked: root.close()
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: theme.separator
                        }

                        Text {
                            visible: notificationServer.trackedNotifications.values.length === 0

                            width: parent.width
                            height: 90

                            text: "No notifications"
                            color: root.muted
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        ListView {
                            id: list

                            width: parent.width
                            height: parent.height - 34 - 1 - parent.spacing * 2
                            clip: true
                            spacing: 10
                            visible: notificationServer.trackedNotifications.values.length > 0

                            model: notificationServer.trackedNotifications

                            delegate: Rectangle {
                                required property var modelData

                                property var notification: modelData

                                width: list.width
                                height: Math.max(96, content.implicitHeight + 28)
                                radius: 12
                                color: root.bg2
                                border.width: notification.urgency === NotificationUrgency.Critical ? 1 : 0
                                border.color: root.danger

                                Row {
                                    id: content

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    spacing: 12

                                    IconImage {
                                        id: icon

                                        implicitSize: 36
                                        source: notification.image !== "" ? notification.image
                                            : Quickshell.iconPath(notification.appIcon, "dialog-information")
                                    }

                                    Column {
                                        width: parent.width - icon.width - dismissButton.width - parent.spacing * 2
                                        spacing: 6

                                        Text {
                                            width: parent.width

                                            text: notification.appName !== "" ? notification.appName : "Application"
                                            color: root.muted
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width

                                            text: notification.summary
                                            color: root.fg
                                            font.pixelSize: 16
                                            font.bold: true
                                            wrapMode: Text.Wrap
                                            textFormat: Text.PlainText
                                        }

                                        Text {
                                            visible: notification.body !== ""
                                            width: parent.width

                                            text: notification.body
                                            color: root.muted
                                            font.pixelSize: 13
                                            wrapMode: Text.Wrap
                                            textFormat: Text.StyledText
                                        }

                                        Flow {
                                            visible: notification.actions.length > 0
                                            width: parent.width
                                            spacing: 6

                                            Repeater {
                                                model: notification.actions

                                                delegate: Rectangle {
                                                    required property var modelData

                                                    width: Math.max(74, actionText.implicitWidth + 22)
                                                    height: 28
                                                    radius: 8
                                                    color: actionMouse.containsMouse ? root.accent : theme.subtleButton

                                                    Text {
                                                        id: actionText

                                                        anchors.centerIn: parent

                                                        text: modelData.text
                                                        color: actionMouse.containsMouse ? theme.fgOnAccent : root.fg
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                    }

                                                    MouseArea {
                                                        id: actionMouse

                                                        anchors.fill: parent
                                                        hoverEnabled: true

                                                        onClicked: modelData.invoke()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: dismissButton

                                        width: 28
                                        height: 28
                                        radius: 8
                                        color: dismissMouse.containsMouse ? root.danger : "transparent"

                                        Text {
                                            anchors.centerIn: parent

                                            text: "󰅖"
                                            color: dismissMouse.containsMouse ? theme.fgOnAccent : root.muted
                                            font.family: "Symbols Nerd Font"
                                            font.pixelSize: 16
                                        }

                                        MouseArea {
                                            id: dismissMouse

                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onClicked: notification.dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
