pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

FocusScope {
  id: root

  required property LockController controller
  property string screenName: "eDP-1"
  property string primaryScreenName: "eDP-1"
  property bool preview: false

  readonly property bool interactive: screenName === primaryScreenName
  readonly property string runtimeDir: Quickshell.env("DOTS_LOCK_RUNTIME") || ""
  readonly property string backgroundPath: Quickshell.env("DOTS_LOCK_BACKGROUND") || ""
  readonly property bool recovery: Quickshell.env("DOTS_LOCK_RECOVERY") === "1"
  readonly property string safeScreenName: screenName.replace(/[^A-Za-z0-9_.-]/g, "_")
  readonly property string snapshotPath: runtimeDir === "" ? "" : "file://" + runtimeDir + "/" + safeScreenName + ".png"
  readonly property real statusBarWidth: Math.min(width, statusBarWidthForScreen())

  function statusBarWidthForScreen() {
    var encodedWidths = Quickshell.env("DOTS_LOCK_BAR_WIDTHS") || "{}"
    try {
      var widths = JSON.parse(encodedWidths)
      var detectedWidth = Number(widths[screenName] || 0)
      return isFinite(detectedWidth) ? Math.max(0, detectedWidth) : 0
    } catch (error) {
      return 0
    }
  }

  focus: true

  function isPrintable(event) {
    var commandModifiers = Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier
    return event.text.length > 0
      && event.text.charCodeAt(0) >= 32
      && !(event.modifiers & commandModifiers)
  }

  Keys.onPressed: event => {
    if (preview && event.key === Qt.Key_Escape && controller.password.length === 0) {
      Qt.quit()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      controller.submitPassword()
      event.accepted = true
    } else if (event.key === Qt.Key_Backspace) {
      controller.backspace()
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      controller.clearPassword()
      event.accepted = true
    } else if (isPrintable(event)) {
      controller.appendText(event.text)
      event.accepted = true
    }
  }

  Image {
    id: wallpaperSource
    anchors.fill: parent
    source: root.backgroundPath
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: width
    sourceSize.height: height
    visible: false
  }

  ShaderEffect {
    id: gradedWallpaper
    anchors.fill: parent
    property variant source: wallpaperSource
    property real temperatureMix: controller.phase === "cooling"
      || controller.phase === "awaiting-auth"
      || controller.phase === "authenticating"
      || controller.phase === "auth-failed"
      || controller.phase === "auth-exit" ? 1.0 : 0.0
    fragmentShader: Quickshell.shellPath("temperature.frag.qsb")

    Behavior on temperatureMix {
      NumberAnimation { duration: 2400; easing.type: Easing.InOutCubic }
    }
  }

  Item {
    id: desktopApps
    x: root.statusBarWidth
    y: controller.phase === "desktop" || controller.phase === "desktop-return" ? 0 : 12
    width: parent.width - root.statusBarWidth
    height: parent.height
    clip: true
    visible: !root.recovery && root.snapshotPath !== ""
    opacity: controller.phase === "desktop" || controller.phase === "desktop-return" ? 1.0 : 0.0
    scale: controller.phase === "desktop" || controller.phase === "desktop-return" ? 1.0 : 0.94
    transformOrigin: Item.Center

    Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }
    Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }
    Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }

    Image {
      x: -root.statusBarWidth
      y: 0
      width: root.width
      height: root.height
      source: root.snapshotPath
      fillMode: Image.PreserveAspectCrop
    }
  }

  Item {
    id: statusBarSnapshot
    x: controller.phase === "desktop" || controller.phase === "desktop-return" ? 0 : -width
    width: root.statusBarWidth
    height: parent.height
    clip: true
    visible: !root.recovery && root.snapshotPath !== "" && width > 0
    opacity: controller.phase === "desktop" || controller.phase === "desktop-return" ? 1.0 : 0.0

    Behavior on x {
      SequentialAnimation {
        PauseAnimation { duration: controller.phase === "desktop-return" ? 140 : 0 }
        NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
      }
    }
    Behavior on opacity {
      SequentialAnimation {
        PauseAnimation { duration: controller.phase === "desktop-return" ? 140 : 0 }
        NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
      }
    }

    Image {
      width: root.width
      height: root.height
      source: root.snapshotPath
      fillMode: Image.PreserveAspectCrop
    }
  }

  Item {
    id: authentication
    anchors.fill: parent
    visible: root.interactive
    opacity: controller.showAuthentication ? 1.0 : 0.0

    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    SystemClock {
      id: clock
      precision: SystemClock.Minutes
    }

    Text {
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.topMargin: 34
      text: Qt.formatDateTime(clock.date, "h:mm AP")
      color: "#c9ffffff"
      font.family: "Iosevka Radon"
      font.pixelSize: 18
      font.letterSpacing: 1.2
      renderType: Text.NativeRendering
    }

    Item {
      id: authPrompt
      width: 320
      height: 70
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 76

      property real shakeOffset: 0
      transform: Translate { x: authPrompt.shakeOffset }

      Connections {
        target: controller
        function onFailureSerialChanged() { failureShake.restart() }
      }

      SequentialAnimation {
        id: failureShake
        NumberAnimation { target: authPrompt; property: "shakeOffset"; to: -7; duration: 45 }
        NumberAnimation { target: authPrompt; property: "shakeOffset"; to: 7; duration: 70 }
        NumberAnimation { target: authPrompt; property: "shakeOffset"; to: -4; duration: 55 }
        NumberAnimation { target: authPrompt; property: "shakeOffset"; to: 0; duration: 45 }
      }

      Text {
        id: promptText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: hairline.top
        anchors.bottomMargin: 13
        text: controller.messageIsError ? controller.message : ""
        color: "#e5b0a8"
        font.family: "Iosevka Radon"
        font.pixelSize: 13
        font.letterSpacing: 0.5
        renderType: Text.NativeRendering
      }

      Rectangle {
        id: hairline
        width: 280
        height: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        color: controller.password.length > 0 ? "#b8ffffff" : "#55ffffff"

        Behavior on color { ColorAnimation { duration: 120 } }

      }

    }

  }

  MouseArea {
    anchors.fill: parent
    z: 1000
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    cursorShape: Qt.BlankCursor
  }

  Component.onCompleted: forceActiveFocus()
}
