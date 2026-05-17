import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root
    Theme { id: theme }

    property bool lockVisible: false
    property string password: ""
    property string pendingResponse: ""
    property string statusText: ""
    property string clockText: ""
    property string dateText: ""
    property bool statusIsError: false
    readonly property string lockImage: ""

    readonly property color accent: theme.primary
    readonly property color bg:     theme.bg0
    readonly property color bg2:    theme.surfaceBg
    readonly property color fg:     theme.fg1
    readonly property color muted:  theme.gray
    readonly property color danger: theme.danger

    function updateClock() {
        var now = new Date()
        clockText = now.toLocaleTimeString(Qt.locale(), "h:mm AP")
        dateText = now.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
    }

    function lock() {
        password = ""
        pendingResponse = ""
        statusText = ""
        statusIsError = false
        updateClock()
        lockVisible = true
        sessionLock.locked = true
    }

    function unlock() {
        if (auth.active || password.length === 0)
            return

        pendingResponse = password
        password = ""
        statusText = "Checking password..."
        statusIsError = false

        if (!auth.start()) {
            pendingResponse = ""
            statusText = "Could not start authentication"
            statusIsError = true
        }
    }

    function answerPam() {
        if (auth.responseRequired && pendingResponse.length > 0) {
            const response = pendingResponse
            pendingResponse = ""
            auth.respond(response)
        }
    }

    PamContext {
        id: auth

        config: "login"

        onResponseRequiredChanged: root.answerPam()
        onPamMessage: root.answerPam()

        onCompleted: function(result) {
            pendingResponse = ""

            if (result === PamResult.Success) {
                statusText = ""
                statusIsError = false
                lockVisible = false
                sessionLock.locked = false
            } else {
                statusText = "Authentication failed"
                statusIsError = true
            }
        }

        onError: function(error) {
            pendingResponse = ""
            statusText = "Authentication error"
            statusIsError = true
            console.warn("lock screen PAM error:", PamError.toString(error))
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: false

        WlSessionLockSurface {
            color: root.bg

            Item {
                anchors.fill: parent

                readonly property bool wideLayout: width >= 900

                Rectangle {
                    anchors.fill: parent
                    color: root.bg
                }

                Item {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.wideLayout ? parent.width / 2 : parent.width
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.lockImage
                        visible: root.lockImage !== ""
                        fillMode: Image.PreserveAspectCrop
                        autoTransform: true
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: root.bg
                        opacity: parent.parent.wideLayout ? 0.10 : 0.48
                    }
                }

                Rectangle {
                    anchors.left: parent.wideLayout ? parent.horizontalCenter : parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    color: root.bg
                    opacity: parent.wideLayout ? 0.92 : 0.30
                }

                Item {
                    anchors.left: parent.wideLayout ? parent.horizontalCenter : parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Column {
                        id: lockContent
                        anchors.centerIn: parent
                        width: Math.min(420, parent.width - 48)
                        spacing: 16

                        Text {
                            width: parent.width
                            height: Math.min(92, Math.max(58, parent.width * 0.2))

                            text: root.clockText
                            color: root.fg
                            font.pixelSize: Math.min(76, Math.max(48, parent.width * 0.18))
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            width: parent.width
                            height: 24

                            text: root.dateText
                            color: root.muted
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Item {
                            width: parent.width
                            height: 10
                        }

                        Text {
                            width: parent.width
                            height: 22

                            text: auth.message !== "" ? auth.message : "Enter password"
                            color: root.muted
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: Math.min(360, parent.width)
                            height: 46
                            anchors.horizontalCenter: parent.horizontalCenter
                            radius: 12
                            color: theme.inputBg
                            border.width: passwordInput.activeFocus ? 1 : 0
                            border.color: root.accent
                            opacity: auth.active ? 0.72 : 1.0

                            TextInput {
                                id: passwordInput

                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16

                                text: root.password
                                color: root.fg
                                selectionColor: root.accent
                                selectedTextColor: root.bg
                                echoMode: auth.responseVisible ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "*"
                                font.pixelSize: 17
                                focus: root.lockVisible
                                clip: true
                                horizontalAlignment: TextInput.AlignHCenter
                                verticalAlignment: TextInput.AlignVCenter
                                enabled: !auth.active

                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        root.unlock()
                                        event.accepted = true
                                    }
                                }

                                onTextChanged: {
                                    if (root.password !== text)
                                        root.password = text
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 32
                                height: parent.height

                                visible: passwordInput.text.length === 0

                                text: auth.active ? "Checking..." : "Password"
                                color: root.muted
                                font.pixelSize: 17
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            width: parent.width
                            height: 22

                            text: root.statusText
                            color: root.statusIsError ? root.danger : root.muted
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                Timer {
                    interval: 1000
                    running: root.lockVisible
                    repeat: true
                    triggeredOnStart: true

                    onTriggered: root.updateClock()
                }

                Timer {
                    interval: 50
                    running: root.lockVisible
                    repeat: true

                    onTriggered: {
                        passwordInput.forceActiveFocus()

                        if (passwordInput.activeFocus)
                            stop()
                    }
                }
            }
        }
    }
}
