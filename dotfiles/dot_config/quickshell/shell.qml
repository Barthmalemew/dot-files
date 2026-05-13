import QtQuick
import Quickshell
import Quickshell.Io

import "./modules"

Scope {
    id: root

    WorkspaceOverlay {
        id: workspaceOverlay
    }

    AppLauncher {
        id: launcher
    }

    NotificationPanel {
        id: notifications
    }

    MediaOsd {
        id: osd
    }

    LockScreen {
        id: lockScreen
    }

    PowerMenu {
        id: powerMenu
        lockScreen: lockScreen
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            launcher.toggle()
        }

        function open() {
            launcher.open()
        }

        function close() {
            launcher.close()
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle() {
            notifications.toggle()
        }

        function open() {
            notifications.open()
        }

        function close() {
            notifications.close()
        }
    }

    IpcHandler {
        target: "osd"

        function showVolume(value: string, muted: string) {
            osd.showVolume(value, muted === "1" || muted === "true")
        }

        function showBrightness(value: string) {
            osd.showBrightness(value)
        }
    }

    IpcHandler {
        target: "powerMenu"

        function toggle() {
            powerMenu.toggle()
        }

        function open() {
            powerMenu.open()
        }

        function close() {
            powerMenu.close()
        }
    }

    IpcHandler {
        target: "lockScreen"

        function lock() {
            lockScreen.lock()
        }
    }

    IpcHandler {
        target: "workspaceOverlay"

        // Desktop-only output-name IPC, disabled for shared use:
        // function showDp1() {
        //     workspaceOverlay.showOverlay("DP-1")
        // }
        //
        // function showDp2() {
        //     workspaceOverlay.showOverlay("DP-2")
        // }

        function showPrimary() {
            if (Quickshell.screens.length > 0)
                workspaceOverlay.showOverlay(Quickshell.screens[0].name)
        }
    }
}
