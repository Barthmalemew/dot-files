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
    property int batteryPercent: -1
    property string batteryState: ""
    property int volumePercent: -1
    property bool volumeMuted: false
    property int brightnessPercent: -1
    property double previousCpuTotal: 0
    property double previousCpuIdle: 0
    property string statusScript: Qt.resolvedUrl("../scripts/launcher-status.sh").toString().replace("file://", "")

    readonly property color accent: theme.primary
    readonly property color bg:     theme.panelBg
    readonly property color bg2:    theme.surfaceBg
    readonly property color fg:     theme.fg1
    readonly property color muted:  theme.gray

    onQueryChanged: refilter()

    component StatusCell: Rectangle {
        required property string symbol
        required property string title
        required property string value
        property int percent: -1
        property color tone: root.accent

        width: (parent.width - parent.spacing * 2) / 3
        height: (parent.height - parent.spacing) / 2
        radius: theme.radiusSm
        color: root.bg2
        border.width: 1
        border.color: theme.border

        Text {
            id: symbolText

            anchors.left: parent.left
            anchors.leftMargin: 14
            y: parent.percent >= 0 ? 11 : Math.round((parent.height - height) / 2)
            width: 24
            height: 28

            text: parent.symbol
            color: parent.tone
            font.family: "Symbols Nerd Font"
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            id: valueText

            anchors.right: parent.right
            anchors.rightMargin: 14
            y: parent.percent >= 0 ? 9 : Math.round((parent.height - height) / 2)
            width: Math.min(104, Math.max(52, implicitWidth))
            height: 30

            text: parent.value
            color: root.fg
            font.pixelSize: 22
            font.bold: true
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        Text {
            anchors.left: symbolText.right
            anchors.leftMargin: 9
            anchors.right: valueText.left
            anchors.rightMargin: 10
            y: parent.percent >= 0 ? 10 : Math.round((parent.height - height) / 2)
            height: 28

            text: parent.title
            color: root.muted
            font.pixelSize: 14
            font.bold: true
            font.capitalization: Font.AllUppercase
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        Rectangle {
            id: meter

            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8

            height: 7
            radius: 4
            visible: parent.percent >= 0
            color: theme.subtleButton

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, parent.parent.percent)) / 100
                height: parent.height
                radius: parent.radius
                color: parent.parent.tone
                opacity: 0.82
            }
        }
    }

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
        var apps = dedupeApps(DesktopEntries.applications.values.slice())

        apps.sort(function(a, b) {
            return a.name.localeCompare(b.name)
        })

        var entries = []

        for (var i = 0; i < apps.length; i++) {
            entries.push({
                app: apps[i],
                searchText: searchTextFor(apps[i])
            })
        }

        allApps = entries
        refilter()
    }

    function normalizedExecFor(app) {
        var exec = app.execString || ""

        if (exec.length === 0 && app.command)
            exec = commandArray(app.command).join(" ")

        return exec
            .replace(/--password-store=[^ ]+/g, "")
            .replace(/%[fFuUdDnNickvm]/g, "")
            .replace(/\s+/g, " ")
            .trim()
    }

    function appDedupeKey(app) {
        return [
            app.name || "",
            app.genericName || "",
            normalizedExecFor(app)
        ].join("\u0000").toLowerCase()
    }

    function preferApp(candidate, current) {
        var candidateExec = candidate.execString || ""
        var currentExec = current.execString || ""

        if (candidateExec.indexOf("--password-store=basic") !== -1 &&
            currentExec.indexOf("--password-store=basic") === -1)
            return true

        return false
    }

    function dedupeApps(apps) {
        var byKey = {}
        var order = []

        for (var i = 0; i < apps.length; i++) {
            var app = apps[i]

            if (app.noDisplay || app.hidden)
                continue

            var key = appDedupeKey(app)

            if (!byKey[key]) {
                byKey[key] = app
                order.push(key)
            } else if (preferApp(app, byKey[key])) {
                byKey[key] = app
            }
        }

        var next = []

        for (var j = 0; j < order.length; j++)
            next.push(byKey[order[j]])

        return next
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
            var entry = allApps[i]

            if (q.length === 0 || entry.searchText.indexOf(q) !== -1)
                next.push(entry)
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

        var app = filteredApps[i].app

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

    function parseSystemStatus(text) {
        var lines = (text || "").split("\n")

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            var split = line.indexOf("=")

            if (split < 0)
                continue

            var key = line.slice(0, split)
            var value = line.slice(split + 1)

            if (key === "BAT") {
                batteryPercent = value === "" ? -1 : clampPercent(parseInt(value))
            } else if (key === "BAT_STATE") {
                batteryState = value
            } else if (key === "VOL") {
                volumePercent = value === "" ? -1 : clampPercent(parseInt(value))
            } else if (key === "VOL_MUTED") {
                volumeMuted = value === "1"
            } else if (key === "BRI") {
                brightnessPercent = value === "" ? -1 : clampPercent(parseInt(value))
            }
        }
    }

    function percentText(value) {
        return value < 0 ? "--%" : value + "%"
    }

    function batteryValue() {
        if (batteryPercent < 0)
            return "AC"

        if (batteryState === "fully-charged")
            return "Full"

        if (batteryState === "charging")
            return percentText(batteryPercent) + " chg"

        return percentText(batteryPercent)
    }

    function volumeValue() {
        if (volumePercent < 0)
            return "No sink"

        if (volumeMuted)
            return "Muted"

        return percentText(volumePercent)
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
        command: ["cat", "/proc/stat", "/proc/meminfo"]

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

    Process {
        id: systemStatusPoller
        command: ["sh", root.statusScript]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseSystemStatus(this.text)
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("launcher system status error:", this.text)
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

            if (!systemStatusPoller.running)
                systemStatusPoller.running = true
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

                width: Math.min(760, Math.max(280, parent.width - 32))
                height: Math.min(640, Math.max(360, parent.height - 32))
                radius: theme.radiusXl
                color: root.bg
                border.width: 1
                border.color: theme.border

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 16

                    Row {
                        width: parent.width
                        height: 34
                        spacing: 12

                        Text {
                            width: parent.width - appCount.width - parent.spacing
                            height: parent.height

                            text: "Applications"
                            color: root.fg
                            font.pixelSize: 22
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            id: appCount

                            width: Math.max(72, implicitWidth)
                            height: parent.height

                            text: root.filteredApps.length + " apps"
                            color: root.muted
                            font.pixelSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    Grid {
                        width: parent.width
                        height: 132
                        columns: 3
                        rows: 2
                        spacing: 12

                        StatusCell {
                            symbol: "󰥔"
                            title: "Time"
                            value: root.clockText
                            tone: root.accent
                        }

                        StatusCell {
                            symbol: "󰍛"
                            title: "CPU"
                            value: root.percentText(root.cpuUsage)
                            tone: theme.info
                        }

                        StatusCell {
                            symbol: "󰘚"
                            title: "Memory"
                            value: root.percentText(root.memoryUsage)
                            tone: theme.success
                        }

                        StatusCell {
                            symbol: "󰁹"
                            title: "Battery"
                            value: root.batteryValue()
                            percent: root.batteryPercent
                            tone: root.batteryPercent >= 0 && root.batteryPercent < 20 ? theme.danger : theme.success
                        }

                        StatusCell {
                            symbol: root.volumeMuted ? "󰝟" : "󰕾"
                            title: "Volume"
                            value: root.volumeValue()
                            percent: root.volumeMuted ? 0 : root.volumePercent
                            tone: theme.info
                        }

                        StatusCell {
                            symbol: "󰃠"
                            title: "Brightness"
                            value: root.percentText(root.brightnessPercent)
                            percent: root.brightnessPercent
                            tone: root.accent
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 58
                        radius: theme.radiusMd
                        color: theme.inputBg
                        border.width: 1
                        border.color: searchText.activeFocus ? root.accent : theme.border

                        Text {
                            id: searchIcon

                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter

                            width: 24
                            height: 28

                            text: "󰍉"
                            color: searchText.activeFocus ? root.accent : root.muted
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextInput {
                            id: searchText

                            anchors.fill: parent
                            anchors.leftMargin: 50
                            anchors.rightMargin: 18

                            verticalAlignment: TextInput.AlignVCenter

                            color: root.fg
                            selectionColor: root.accent
                            selectedTextColor: root.bg

                            text: root.query
                            font.pixelSize: 20
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
                            anchors.left: searchIcon.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter

                            visible: searchText.text.length === 0

                            text: "Search apps..."
                            color: root.muted
                            font.pixelSize: 20
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
                        height: parent.height - 34 - 132 - 58 - 1 - parent.spacing * 4
                        clip: true
                        visible: root.filteredApps.length > 0

                        model: root.filteredApps
                        currentIndex: root.selectedIndex

                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            width: list.width
                            height: 58
                            radius: theme.radiusMd
                            border.width: index === root.selectedIndex ? 1 : 0
                            border.color: root.accent

                            color: index === root.selectedIndex ? theme.hoverSurface : appMouse.containsMouse ? theme.subtleButton : "transparent"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter

                                width: 3
                                height: 30
                                radius: 2
                                visible: index === root.selectedIndex
                                color: root.accent
                            }

                            IconImage {
                                id: icon

                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter

                                implicitSize: 34
                                source: Quickshell.iconPath(modelData.app.icon, "application-x-executable")
                            }

                            Text {
                                id: appName

                                anchors.left: icon.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                y: modelData.app.genericName ? 8 : Math.round((parent.height - height) / 2)

                                text: modelData.app.name
                                color: root.fg
                                font.pixelSize: 18
                                font.bold: index === root.selectedIndex
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.left: appName.left
                                anchors.right: appName.right
                                anchors.top: appName.bottom
                                anchors.topMargin: 2

                                visible: !!modelData.app.genericName

                                text: modelData.app.genericName || ""
                                color: index === root.selectedIndex ? root.accent : root.muted
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: appMouse

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
