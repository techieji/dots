pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  id: root

  readonly property bool preview: Quickshell.env("DOTS_LOCK_MODE") === "preview"
  readonly property string runtimeDir: Quickshell.env("DOTS_LOCK_RUNTIME") || ""

  function primaryScreenName() {
    for (var i = 0; i < Quickshell.screens.length; ++i) {
      if (Quickshell.screens[i].name === "eDP-1")
        return "eDP-1"
    }
    for (var j = 0; j < Quickshell.screens.length; ++j) {
      if (Quickshell.screens[j].name !== "weylus")
        return Quickshell.screens[j].name
    }
    return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "eDP-1"
  }

  LockController {
    id: controller
    onReadyToUnlock: {
      if (root.preview)
        return
      lockSession.locked = false
    }
  }

  Variants {
    model: root.preview ? Quickshell.screens : []

    PanelWindow {
      id: previewSurface
      required property var modelData

      screen: modelData
      visible: true
      color: "black"
      aboveWindows: true
      focusable: modelData.name === root.primaryScreenName()
      exclusiveZone: 0
      anchors {
        top: true
        right: true
        bottom: true
        left: true
      }

      LockContent {
        anchors.fill: parent
        controller: controller
        screenName: previewSurface.modelData.name
        primaryScreenName: root.primaryScreenName()
        preview: true
      }
    }
  }

  Timer {
    interval: 0
    running: root.preview
    onTriggered: controller.begin()
  }

  WlSessionLock {
    id: lockSession
    locked: !root.preview

    onSecureChanged: {
      if (!secure)
        return
      if (root.runtimeDir !== "")
        Quickshell.execDetached(["touch", root.runtimeDir + "/ready"])
      controller.begin()
    }

    onLockedChanged: {
      if (!root.preview && !locked)
        Qt.callLater(Qt.quit)
    }

    WlSessionLockSurface {
      id: lockSurface
      color: "black"

      LockContent {
        anchors.fill: parent
        controller: controller
        screenName: lockSurface.screen ? lockSurface.screen.name : "unknown"
        primaryScreenName: root.primaryScreenName()
        preview: false
      }
    }
  }
}
