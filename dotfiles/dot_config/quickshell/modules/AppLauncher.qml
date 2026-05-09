import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
    id: root
    Theme { id: theme }

    property bool launcherVisible: false
    property var allApps: []
    property var filteredApps: []
    property int selectedIndex: 0
    property string query: ""
    property string clockText: ""
    property int cpuUsage: 0
    property int memoryUsage: 0
    property double previousCpuTotal: 0
    property double previousCpuIdle: 0

    readonly property color accent: theme.primary
    readonly property color bg:     theme.panelBg
    readonly property color bg2:    theme.surfaceBg
    readonly property color fg:     theme.fg1
    readonly property color muted:  theme.gray

    onQueryChanged: refilter()

    function toggle() {
        if (launcherVisible)
            close()
        else
            open()
    }

    function open() {
        launcherVisible = true
        selectedIndex = 0
        reloadApps()
    }

    function close() {
        launcherVisible = false
        selectedIndex = 0
        query = ""
    }

    function reloadApps() {
        var apps = DesktopEntries.applications.values.slice()

        apps.sort(function(a, b) {
            return a.name.localeCompare(b.name)
        })

        allApps = apps
        refilter()
    }

    function searchTextFor(app) {
        return [
            app.name,
            app.genericName,
            app.comment,
            app.execString,
            app.keywords ? app.keywords.join(" ") : "",
            app.categories ? app.categories.join(" ") : ""
        ].join(" ").toLowerCase()
    }

    function refilter() {
        var q = query.toLowerCase().trim()
        var next = []

        for (var i = 0; i < allApps.length; i++) {
            var app = allApps[i]

            if (q.length === 0 || searchTextFor(app).indexOf(q) !== -1)
                next.push(app)
        }

        filteredApps = next
        selectedIndex = filteredApps.length > 0 ? Math.min(selectedIndex, filteredApps.length - 1) : 0
    }

    function commandArray(command) {
        var next = []

        for (var i = 0; i < command.length; i++)
            next.push(command[i])

        return next
    }

    function launchSelected() {
        if (filteredApps.length <= 0)
            return

        var i = selectedIndex

        if (i < 0)
            i = 0

        if (i >= filteredApps.length)
            i = filteredApps.length - 1

        var app = filteredApps[i]

        if (app.runInTerminal) {
            Quickshell.execDetached({
                command: ["kitty", "-e"].concat(commandArray(app.command)),
                workingDirectory: app.workingDirectory
            })
        } else {
            app.execute()
        }

        close()
    }

    function updateClock() {
        var now = new Date()
        clockText = now.toLocaleTimeString(Qt.locale(), "h:mm AP")
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(value)))
    }

    function parseStats(text) {
        var lines = (text || "").split("\n")
        var memTotal = 0
        var memAvailable = 0

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (line.indexOf("cpu ") === 0) {
                var parts = line.split(/\s+/)
                var user = parseInt(parts[1]) || 0
                var nice = parseInt(parts[2]) || 0
                var system = parseInt(parts[3]) || 0
                var idle = parseInt(parts[4]) || 0
                var iowait = parseInt(parts[5]) || 0
                var irq = parseInt(parts[6]) || 0
                var softirq = parseInt(parts[7]) || 0
                var steal = parseInt(parts[8]) || 0
                var total = user + nice + system + idle + iowait + irq + softirq + steal
                var idleTotal = idle + iowait

                if (previousCpuTotal > 0) {
                    var totalDelta = total - previousCpuTotal
                    var idleDelta = idleTotal - previousCpuIdle

                    if (totalDelta > 0)
                        cpuUsage = clampPercent((1 - idleDelta / totalDelta) * 100)
                }

                previousCpuTotal = total
                previousCpuIdle = idleTotal
            } else if (line.indexOf("MemTotal:") === 0) {
                memTotal = parseInt(line.split(/\s+/)[1]) || 0
            } else if (line.indexOf("MemAvailable:") === 0) {
                memAvailable = parseInt(line.split(/\s+/)[1]) || 0
            }
        }

        if (memTotal > 0)
            memoryUsage = clampPercent((1 - memAvailable / memTotal) * 100)
    }

    Component.onCompleted: {
        updateClock()
        reloadApps()
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.reloadApps()
        }
    }

    Process {
        id: statsPoller
        command: ["sh", "-c", "cat /proc/stat /proc/meminfo"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseStats(this.text)
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("launcher stats error:", this.text)
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: root.updateClock()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!statsPoller.running)
                statsPoller.running = true
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
            visible: root.launcherVisible && isMainDisplay

            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                if (visible) {
                    focusDelay.tick = 0
                    focusDelay.restart()
                }
            }

            Timer {
                id: focusDelay

                property int tick: 0

                interval: 50
                repeat: true

                onTriggered: {
                    searchText.forceActiveFocus()

                    tick += 1

                    if (searchText.activeFocus || tick >= 6)
                        stop()
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

                width: 620
                height: 530
                radius: 18
                color: root.bg
                border.width: 1
                border.color: theme.border

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Row {
                        width: parent.width
                        height: 42
                        spacing: 10

                        Rectangle {
                            width: (parent.width - parent.spacing * 2) / 3
                            height: parent.height
                            radius: 12
                            color: root.bg2

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14

                                text: root.clockText
                                color: root.fg
                                font.pixelSize: 18
                                font.bold: true
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: (parent.width - parent.spacing * 2) / 3
                            height: parent.height
                            radius: 12
                            color: theme.subtleButton

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                text: "CPU " + root.cpuUsage + "%"
                                color: root.fg
                                font.pixelSize: 14
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            width: (parent.width - parent.spacing * 2) / 3
                            height: parent.height
                            radius: 12
                            color: theme.subtleButton

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                text: "MEM " + root.memoryUsage + "%"
                                color: root.fg
                                font.pixelSize: 14
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: 12
                        color: root.bg2

                        TextInput {
                            id: searchText

                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16

                            verticalAlignment: TextInput.AlignVCenter

                            color: root.fg
                            selectionColor: root.accent
                            selectedTextColor: root.bg

                            text: root.query
                            font.pixelSize: 18
                            clip: true
                            focus: root.launcherVisible

                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape) {
                                    root.close()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.launchSelected()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down) {
                                    if (root.filteredApps.length > 0)
                                        root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredApps.length - 1)

                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up) {
                                    root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Home) {
                                    root.selectedIndex = 0
                                    event.accepted = true
                                } else if (event.key === Qt.Key_End) {
                                    if (root.filteredApps.length > 0)
                                        root.selectedIndex = root.filteredApps.length - 1

                                    event.accepted = true
                                }
                            }

                            onTextChanged: {
                                if (root.query !== text)
                                    root.query = text
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter

                            visible: searchText.text.length === 0

                            text: "Search apps..."
                            color: root.muted
                            font.pixelSize: 18
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: theme.separator
                    }

                    Text {
                        visible: root.filteredApps.length === 0

                        width: parent.width
                        height: 48

                        text: "No apps found"
                        color: root.muted
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    ListView {
                        id: list

                        width: parent.width
                        height: parent.height - 140
                        clip: true
                        visible: root.filteredApps.length > 0

                        model: root.filteredApps
                        currentIndex: root.selectedIndex

                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            width: list.width
                            height: 48
                            radius: 10

                            color: index === root.selectedIndex ? root.accent : "transparent"

                            IconImage {
                                id: icon

                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter

                                implicitSize: 28
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            }

                            Text {
                                anchors.left: icon.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter

                                text: modelData.name
                                color: index === root.selectedIndex ? theme.fgOnAccent : root.fg
                                font.pixelSize: 16
                                font.bold: index === root.selectedIndex
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true

                                onEntered: {
                                    root.selectedIndex = index
                                }

                                onClicked: {
                                    root.selectedIndex = index
                                    root.launchSelected()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
