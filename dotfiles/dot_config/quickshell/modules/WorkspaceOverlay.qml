import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: root
    Theme { id: theme }

    property var tagsByMonitor: ({})
    property var activeTagByMonitor: ({})
    property var overlayByMonitor: ({})
    property var dimByMonitor: ({})
    property bool hasValidState: false

    readonly property color accent:   theme.primary
    readonly property color occupied: theme.info
    readonly property color empty:    theme.bg2
    readonly property color bg:       theme.overlayBg
    readonly property color fg:       theme.fgOnAccent

    function monitorMinTag(monitorName) {
        // Desktop-only split, disabled for shared use:
        // if (monitorName === "DP-2")
        //     return 8
        return 1
    }

    function monitorMaxTag(monitorName) {
        // Desktop-only split, disabled for shared use:
        // if (monitorName === "DP-2")
        //     return 9
        // return 7
        return 9
    }

    function showOverlay(monitorName) {
        const next = Object.assign({}, root.overlayByMonitor)
        next[monitorName] = true
        root.overlayByMonitor = next

        const nextDim = Object.assign({}, root.dimByMonitor)
        nextDim[monitorName] = true
        root.dimByMonitor = nextDim

        dimTimer.restart()
        hideTimer.restart()
    }

    function showOverlays(monitorNames) {
        if (monitorNames.length === 0)
            return

        const next = Object.assign({}, root.overlayByMonitor)

        for (let i = 0; i < monitorNames.length; i++)
            next[monitorNames[i]] = true

        root.overlayByMonitor = next

        const nextDim = Object.assign({}, root.dimByMonitor)

        for (let i = 0; i < monitorNames.length; i++)
            nextDim[monitorNames[i]] = true

        root.dimByMonitor = nextDim
        dimTimer.restart()
        hideTimer.restart()
    }

    function overlayVisible(monitorName) {
        return root.overlayByMonitor[monitorName] === true
    }

    function dimVisible(monitorName) {
        return root.dimByMonitor[monitorName] === true
    }

    function visibleTagsForMonitor(monitorName) {
        const tags = root.tagsByMonitor[monitorName] || {}
        const minTag = root.monitorMinTag(monitorName)
        const maxTag = root.monitorMaxTag(monitorName)

        const result = []

        for (let id = minTag; id <= maxTag; id++) {
            const t = tags[id] || {
                occupied: false,
                focused: false
            }

            if (t.occupied || t.focused) {
                result.push({
                    realId: id,
                    displayId: id,
                    occupied: t.occupied,
                    focused: t.focused
                })
            }
        }

        return result
    }

    function monitorForTag(id) {
        // Desktop-only output mapping, disabled for shared use:
        // if (id >= root.monitorMinTag("DP-2") && id <= root.monitorMaxTag("DP-2"))
        //     return "DP-2"
        // return "DP-1"
        if (Quickshell.screens.length > 0)
            return Quickshell.screens[0].name

        return ""
    }

    function parseTagLine(parts) {
        let offset = -1
        let monitor = ""

        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "tag") {
                offset = i
                break
            }
        }

        if (offset < 0 || parts.length < offset + 5)
            return null

        const id = parseInt(parts[offset + 1])

        if (isNaN(id) || id < 1 || id > 9)
            return null

        if (offset > 0)
            monitor = parts[offset - 1]
        else
            monitor = root.monitorForTag(id)

        const minTag = root.monitorMinTag(monitor)
        const maxTag = root.monitorMaxTag(monitor)

        if (id < minTag || id > maxTag)
            return null

        const state = parseInt(parts[offset + 2]) || 0
        const clients = parseInt(parts[offset + 3]) || 0
        const focused = parseInt(parts[offset + 4]) || 0
        const isActive = state === 1

        return {
            monitor: monitor,
            id: id,
            occupied: clients > 0,
            focused: isActive || focused === 1,
            active: isActive
        }
    }

    Timer {
        id: hideTimer
        interval: dimTimer.interval
        repeat: false

        onTriggered: {
            root.overlayByMonitor = ({})
        }
    }

    Timer {
        id: dimTimer
        interval: 650
        repeat: false

        onTriggered: {
            root.dimByMonitor = ({})
        }
    }

    Process {
        id: poller
        command: ["mmsg", "-g", "-t"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseBlock(this.text)
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "")
                    console.warn("mmsg error:", this.text)
            }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!poller.running)
                poller.running = true
        }
    }

    function parseBlock(block) {
        const nextByMonitor = {}
        const nextActiveByMonitor = {}
        let parsedTags = 0

        const lines = (block || "").split("\n")

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line.length === 0)
                continue

            const p = line.split(/\s+/)
            const tag = root.parseTagLine(p)

            if (tag === null)
                continue

            parsedTags += 1

            if (!nextByMonitor[tag.monitor])
                nextByMonitor[tag.monitor] = {}

            nextByMonitor[tag.monitor][tag.id] = {
                occupied: tag.occupied,
                focused: tag.focused
            }

            if (tag.active)
                nextActiveByMonitor[tag.monitor] = tag.id
        }

        if (parsedTags === 0)
            return

        const changedMonitors = []

        if (root.hasValidState) {
            for (const monitorName in nextActiveByMonitor) {
                if (nextActiveByMonitor[monitorName] !== root.activeTagByMonitor[monitorName])
                    changedMonitors.push(monitorName)
            }
        }

        root.tagsByMonitor = nextByMonitor
        root.activeTagByMonitor = nextActiveByMonitor
        root.hasValidState = true

        root.showOverlays(changedMonitors)
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property var modelData

            property string monitorName: modelData.name
            property var visibleTags: root.visibleTagsForMonitor(monitorName)

            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            mask: Region {}

            visible: root.overlayVisible(monitorName) || pill.opacity > 0.01

            Rectangle {
                anchors.fill: parent
                color: theme.dimBg
                opacity: root.dimVisible(monitorName) ? 0.38 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                id: pill

                anchors.centerIn: parent

                color: root.bg
                radius: 14
                border.width: 1
                border.color: theme.border

                width: row.width + 28
                height: row.height + 20

                opacity: root.overlayVisible(monitorName) ? 1.0 : 0.0
                scale: root.overlayVisible(monitorName) ? 1.0 : 0.92

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    id: row

                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: visibleTags

                        Rectangle {
                            id: box

                            property var tag: modelData

                            width: 40
                            height: 40
                            radius: 8

                            color: tag.focused ? root.accent
                                 : tag.occupied ? root.occupied
                                 : root.empty

                            scale: tag.focused ? 1.08 : 1.0

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: box.tag.displayId
                                font.pixelSize: 16
                                font.bold: box.tag.focused

                                color: box.tag.focused ? root.fg
                                     : box.tag.occupied ? root.fg
                                     : root.occupied

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
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
