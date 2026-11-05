// The lock screen, which is also the login screen: the session starts
// locked. The blurred wallpaper sits behind a large clock and a password
// field checked through PAM.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import qs.components
import qs.services

Scope {
    id: lock

    property string message: ""
    property bool checking: false

    PamContext {
        id: pam
        config: "quickshell"
        configDirectory: "/etc/pam.d"
        onPamMessage: {
            if (responseRequired)
                respond(lock.password);
        }
        onCompleted: result => {
            lock.checking = false;
            if (result === PamResult.Success) {
                lock.message = "";
                // Autologin can't unlock the login keyring; the password just
                // typed here can.
                keyring.running = true;
                Session.locked = false;
            } else {
                lock.message = "Wrong password";
                lock.password = "";
            }
        }
    }

    Process {
        id: keyring
        command: ["gnome-keyring-daemon", "--unlock"]
        stdinEnabled: true
        onStarted: {
            write(lock.password);
            stdinEnabled = false;
            lock.password = "";
        }
    }

    property string password: ""

    function submit(text: string) {
        if (checking || text === "")
            return;
        password = text;
        checking = true;
        message = "";
        pam.start();
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

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: lock.message
                    color: Theme.colors.urgent
                    visible: text !== ""
                }
            }
        }
    }
}
