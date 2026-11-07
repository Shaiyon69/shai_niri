import QtQuick

Rectangle {
    id: root

    property bool busy: false
    property string message: ""
    property date now: new Date()
    readonly property string userName: {
        var item = userNames.itemAt(users.currentIndex)
        return item ? item.login : userModel.lastUser
    }

    function login() {
        if (busy)
            return
        busy = true
        message = ""
        sddm.login(root.userName, password.text, sessions.currentIndex)
    }

    color: "#0b0b0b"

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root.message = ""
        }
        function onLoginFailed() {
            root.busy = false
            root.message = "Wrong password"
            password.text = ""
            password.forceActiveFocus()
            shake.restart()
        }
        function onInformationMessage(message) {
            root.message = message
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Image {
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
    }

    // Only the primary monitor gets the login form. Others show the wallpaper.
    Item {
        anchors.fill: parent
        visible: primaryScreen

        Column {
            id: center
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Math.round(root.height * 0.04)
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, Qt.locale().timeFormat(Locale.ShortFormat))
                color: "#f2f2f2"
                font.family: "Noto Sans"
                font.weight: Font.Light
                font.pixelSize: Math.round(root.height * 0.11)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale().toString(root.now, "dddd, MMMM d")
                color: "#b8b8b8"
                font.family: "Noto Sans"
                font.pixelSize: 18
            }

            Item { width: 1; height: 44 }

            Selector {
                id: users
                anchors.horizontalCenter: parent.horizontalCenter
                model: userModel
                role: "user"
                currentIndex: Math.max(0, userModel.lastIndex)
                onPicked: password.forceActiveFocus()
            }

            Item { width: 1; height: 12 }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340
                height: 52
                radius: 26
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: root.message !== "" ? "#e8a0a0"
                                                  : password.activeFocus ? Qt.rgba(1, 1, 1, 0.55)
                                                                         : Qt.rgba(1, 1, 1, 0.18)

                Behavior on border.color { ColorAnimation { duration: 120 } }

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: fieldShift; property: "x"; to: -10; duration: 50 }
                    NumberAnimation { target: fieldShift; property: "x"; to: 8; duration: 70 }
                    NumberAnimation { target: fieldShift; property: "x"; to: -5; duration: 60 }
                    NumberAnimation { target: fieldShift; property: "x"; to: 0; duration: 50 }
                }

                transform: Translate { id: fieldShift }

                TextInput {
                    id: password
                    anchors.left: parent.left
                    anchors.right: submit.left
                    anchors.leftMargin: 24
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#f2f2f2"
                    selectionColor: "#5a5a5a"
                    font.family: "Noto Sans"
                    font.pixelSize: 16
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 0
                    clip: true
                    enabled: !root.busy
                    focus: true
                    Keys.onReturnPressed: root.login()
                    Keys.onEnterPressed: root.login()
                    Keys.onEscapePressed: text = ""
                    onTextChanged: if (text !== "") root.message = ""
                    KeyNavigation.tab: users.hasChoice ? users : sessions
                }

                Text {
                    anchors.left: password.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: password.text === ""
                    text: root.busy ? "Signing in…" : "Password"
                    color: "#8f8f8f"
                    font.family: "Noto Sans"
                    font.pixelSize: 16
                }

                Rectangle {
                    id: submit
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: submitMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "→"
                        color: "#f2f2f2"
                        font.family: "Noto Sans"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.login()
                    }
                }
            }

            Item { width: 1; height: 12 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340
                height: 20
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.message !== "" ? root.message
                                          : keyboard.capsLock ? "Caps Lock is on" : ""
                color: root.message !== "" ? "#e8a0a0" : "#d8c48a"
                font.family: "Noto Sans"
                font.pixelSize: 14
            }
        }

        Selector {
            id: sessions
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 24
            model: sessionModel
            currentIndex: Math.max(0, sessionModel.lastIndex)
            onPicked: password.forceActiveFocus()
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            spacing: 4

            TextButton {
                visible: sddm.canSuspend
                text: "Suspend"
                onClicked: sddm.suspend()
            }
            TextButton {
                visible: sddm.canReboot
                text: "Restart"
                onClicked: sddm.reboot()
            }
            TextButton {
                visible: sddm.canPowerOff
                text: "Shut down"
                onClicked: sddm.powerOff()
            }
        }
    }

    // Maps each row of the user list to the login name sddm.login() needs.
    Repeater {
        id: userNames
        model: userModel
        Item {
            required property var model
            property string login: model.name
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
