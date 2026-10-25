pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pam

QtObject {
  id: root

  signal readyToUnlock
  signal failed

  readonly property bool preview: Quickshell.env("DOTS_LOCK_MODE") === "preview"
  readonly property bool recovery: Quickshell.env("DOTS_LOCK_RECOVERY") === "1"
  readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "prajasekar"

  property string phase: "desktop"
  property string password: ""
  property string message: ""
  property bool messageIsError: false
  property bool fingerprintActive: false
  property bool passwordActive: false
  property bool unlockLatched: false
  property int failureSerial: 0
  property int fingerprintRetryMs: 750
  property string pendingPassword: ""

  readonly property bool acceptingInput: phase === "awaiting-auth" || phase === "auth-failed"
  readonly property bool showAuthentication: acceptingInput || phase === "authenticating"

  function begin() {
    password = ""
    message = ""
    messageIsError = false
    unlockLatched = false

    if (recovery) {
      phase = "cooling"
      coolingTimer.restart()
    } else {
      phase = "desktop-depart"
      desktopDepartTimer.restart()
    }
  }

  function appendText(text) {
    if (!acceptingInput || password.length >= 128)
      return
    password += text
    message = ""
    messageIsError = false
  }

  function backspace() {
    if (acceptingInput && password.length > 0)
      password = password.slice(0, -1)
  }

  function clearPassword() {
    password = ""
  }

  function submitPassword() {
    if (!acceptingInput || password.length === 0)
      return

    pendingPassword = password
    password = ""
    message = "checking password"
    messageIsError = false
    phase = "authenticating"
    passwordActive = true
    if (!passwordPam.start())
      authenticateFailed("password authentication unavailable")
  }

  function startFingerprint() {
    if (!fingerprintActive && !unlockLatched) {
      fingerprintActive = true
      if (!fingerprintPam.start()) {
        fingerprintActive = false
        message = "fingerprint unavailable · type password"
        messageIsError = false
      }
    }
  }

  function authenticateSucceeded() {
    if (unlockLatched)
      return
    unlockLatched = true
    fingerprintActive = false
    passwordActive = false
    pendingPassword = ""
    password = ""
    fingerprintPam.abort()
    passwordPam.abort()
    phase = "auth-exit"
    authExitTimer.restart()
  }

  function authenticateFailed(reason) {
    passwordActive = false
    pendingPassword = ""
    password = ""
    message = reason || "not recognized"
    messageIsError = true
    phase = "auth-failed"
    failureSerial++
    failed()
  }

  property Timer desktopDepartTimer: Timer {
    interval: 360
    onTriggered: {
      root.phase = "cooling"
      coolingTimer.restart()
    }
  }

  property Timer coolingTimer: Timer {
    interval: 2400
    onTriggered: {
      root.phase = "awaiting-auth"
      root.startFingerprint()
    }
  }

  property Timer authExitTimer: Timer {
    interval: 180
    onTriggered: {
      root.phase = "warming"
      warmingTimer.restart()
    }
  }

  property Timer warmingTimer: Timer {
    interval: 2400
    onTriggered: {
      root.phase = root.recovery ? "unlock-ready" : "desktop-return"
      desktopReturnTimer.restart()
    }
  }

  property Timer desktopReturnTimer: Timer {
    interval: root.recovery ? 0 : 360
    onTriggered: {
      if (root.preview) {
        Qt.quit()
      } else {
        root.readyToUnlock()
      }
    }
  }

  property Timer fingerprintRetryTimer: Timer {
    interval: root.fingerprintRetryMs
    onTriggered: root.startFingerprint()
  }

  property PamContext passwordPam: PamContext {
    configDirectory: "/etc/pam.d"
    config: "dots-lock-password"
    user: root.user

    onPamMessage: {
      if (responseRequired && root.pendingPassword !== "") {
        var response = root.pendingPassword
        root.pendingPassword = ""
        passwordPam.respond(response)
      } else if (!responseRequired && message !== "") {
        root.message = message
        root.messageIsError = messageIsError
      }
    }

    onCompleted: result => {
      if (result === PamResult.Success)
        root.authenticateSucceeded()
      else
        root.authenticateFailed("password rejected")
    }

    onError: root.authenticateFailed("password unavailable")
  }

  property PamContext fingerprintPam: PamContext {
    configDirectory: "/etc/pam.d"
    config: "dots-lock-fingerprint"
    user: root.user

    onPamMessage: {
      if (message !== "" && !responseRequired) {
        root.message = message
        root.messageIsError = messageIsError
      }
    }

    onCompleted: result => {
      root.fingerprintActive = false
      if (result === PamResult.Success) {
        root.fingerprintRetryMs = 750
        root.authenticateSucceeded()
      } else if (!root.unlockLatched) {
        root.failureSerial++
        root.message = "fingerprint not recognized"
        root.messageIsError = true
        root.fingerprintRetryMs = Math.min(root.fingerprintRetryMs * 2, 10000)
        fingerprintRetryTimer.restart()
      }
    }

    onError: {
      root.fingerprintActive = false
      if (!root.unlockLatched) {
        root.message = "fingerprint unavailable · type password"
        root.messageIsError = false
        root.fingerprintRetryMs = Math.min(root.fingerprintRetryMs * 2, 10000)
        fingerprintRetryTimer.restart()
      }
    }
  }
}
