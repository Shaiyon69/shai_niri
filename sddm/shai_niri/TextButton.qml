import QtQuick

// A plain text button that works with the mouse and the keyboard.
Item {
    id: button

    property alias text: label.text
    signal clicked

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 36
    activeFocusOnTab: true

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Keys.onSpacePressed: clicked()

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        border.width: button.activeFocus ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.5)
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: mouse.containsMouse || button.activeFocus ? "#f2f2f2" : "#a8a8a8"
        font.family: "Noto Sans"
        font.pixelSize: 14
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
