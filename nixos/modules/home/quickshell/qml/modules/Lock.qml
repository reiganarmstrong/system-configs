// The lock screen, which is also the login screen: the session starts
// locked. The blurred wallpaper sits behind a large clock and a password
// field checked through PAM.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.components
import qs.components.settings
import qs.services

Scope {
    id: lock

    property string message: ""
    property bool checking: false
    property bool fingerprintAvailable: false
    property bool fingerprintChecking: false

    Process {
        running: Session.locked
        command: ["busctl", "--system", "call", "net.reactivated.Fprint",
            "/net/reactivated/Fprint/Manager", "net.reactivated.Fprint.Manager", "GetDefaultDevice"]
        onExited: code => lock.fingerprintAvailable = code === 0
    }

    PamContext {
        id: fingerprint
        config: "quickshell-fingerprint"
        configDirectory: "/etc/pam.d"
        onPamMessage: {
            if (!responseRequired)
                lock.message = message;
        }
        onCompleted: result => {
            if (!lock.fingerprintChecking)
                return;
            lock.fingerprintChecking = false;
            if (result === PamResult.Success) {
                lock.message = "";
                Session.locked = false;
            } else {
                lock.message = "Fingerprint not recognized. Try again or enter your password.";
            }
        }
    }

    function cancelFingerprint() {
        fingerprintChecking = false;
        fingerprint.abort();
    }

    Connections {
        target: Session
        function onLockedChanged() {
            if (!Session.locked)
                lock.cancelFingerprint();
        }
    }

    PamContext {
        id: pam
        config: "quickshell"
        configDirectory: "/etc/pam.d"
        onPamMessage: {
            if (responseRequired)
                respond(lock.password);
        }
        // The PAM service also unlocks the login keyring with this password,
        // which autologin can't do.
        onCompleted: result => {
            lock.checking = false;
            lock.password = "";
            if (result === PamResult.Success) {
                lock.message = "";
                Session.locked = false;
            } else {
                lock.message = "Wrong password";
            }
        }
    }

    // The keyring daemon from login stays uninitialised until something asks
    // for it, and PAM can't unlock it before then, so start it first. --start
    // initialises the running daemon (or starts one) and exits. Checking the
    // password waits for it to stop, whether it exited or failed to launch.
    Process {
        id: keyringStart
        command: ["gnome-keyring-daemon", "--start", "--components=secrets"]
        onRunningChanged: if (!running && lock.checking) pam.start()
    }

    property string password: ""

    function submit(text: string) {
        if (checking || text === "")
            return;
        cancelFingerprint();
        password = text;
        checking = true;
        message = "";
        keyringStart.running = true;
    }

    WlSessionLock {
        locked: Session.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.colors.background

            Image {
                id: wallpaper
                anchors.fill: parent
                anchors.margins: -80
                source: "file://" + Theme.wallpaper
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width, height)
                visible: false
            }
            MultiEffect {
                // Overscan so the blur doesn't pull dark background in at the edges.
                anchors.fill: parent
                anchors.margins: -80
                source: wallpaper
                blurEnabled: true
                blur: 1
                blurMax: 64
                brightness: -0.12
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.14
                spacing: 4

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(clock.date, "dddd, d MMMM")
                    size: Theme.textLarge
                    weight: Font.DemiBold
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, "h:mm")
                    size: 72
                    weight: Font.ExtraBold
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.12
                spacing: 14

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72
                    height: 72
                    radius: 36
                    color: Theme.withAlpha("#ffffff", 0.9)
                    Label {
                        anchors.centerIn: parent
                        text: Theme.user.fullName.charAt(0)
                        size: 26
                        weight: Font.Bold
                        color: Theme.colors.accentText
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Theme.user.fullName
                    weight: Font.Bold
                    size: Theme.textLarge
                }

                Glass {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 260
                    height: 40
                    radius: 20

                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.colors.text
                        font.family: Theme.font
                        font.pointSize: Theme.textNormal
                        focus: true
                        enabled: !lock.checking
                        onAccepted: {
                            lock.submit(text);
                            text = "";
                        }
                        Component.onCompleted: forceActiveFocus()

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: lock.checking ? "Checking…" : "Enter password"
                            dim: true
                            visible: field.text === ""
                        }
                    }
                }

                SettingButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: lock.fingerprintAvailable
                    enabled: !lock.checking
                    text: lock.fingerprintChecking ? "Cancel fingerprint" : "Use fingerprint"
                    onClicked: {
                        if (lock.fingerprintChecking) {
                            lock.cancelFingerprint();
                            lock.message = "";
                            field.forceActiveFocus();
                        } else {
                            lock.message = "Touch the fingerprint reader";
                            lock.fingerprintChecking = true;
                            if (!fingerprint.start()) {
                                lock.fingerprintChecking = false;
                                lock.message = "Fingerprint reader unavailable. Enter your password.";
                            }
                        }
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: lock.fingerprintAvailable
                    text: "Password also unlocks the login keyring"
                    dim: true
                    size: Theme.textSmall
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: lock.message
                    color: lock.fingerprintChecking ? Theme.colors.textDim : Theme.colors.urgent
                    width: 360
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }
            }
        }
    }
}
