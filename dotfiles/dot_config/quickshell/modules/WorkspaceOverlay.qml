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
        command: ["mmsg", "get", "all-tags"]

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
        let data
        try {
            data = JSON.parse(block)
        } catch (e) {
            return
        }

        if (!data || !data.all_tags)
            return

        const nextByMonitor = {}
        const nextActiveByMonitor = {}
        let parsedTags = 0

        for (let m = 0; m < data.all_tags.length; m++) {
            const entry = data.all_tags[m]
            const monitor = entry.monitor
            const tags = entry.tags || []

            const minTag = root.monitorMinTag(monitor)
            const maxTag = root.monitorMaxTag(monitor)

            for (let i = 0; i < tags.length; i++) {
                const t = tags[i]
                const id = t.index

                if (isNaN(id) || id < minTag || id > maxTag)
                    continue

                parsedTags += 1

                if (!nextByMonitor[monitor])
                    nextByMonitor[monitor] = {}

                nextByMonitor[monitor][id] = {
                    occupied: (t.client_count || 0) > 0,
                    focused: t.is_active === true
                }

                if (t.is_active)
                    nextActiveByMonitor[monitor] = id
            }
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
