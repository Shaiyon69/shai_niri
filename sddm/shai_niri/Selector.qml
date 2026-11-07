import QtQuick

// A button that opens a list above itself. Used to pick the session or user.
Item {
    id: selector

    property var model
    property string role: "name"
    property int currentIndex: 0
    property string currentText: ""
    readonly property bool hasChoice: options.count > 1
    signal picked

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function labelFor(entry) {
        return selector.role === "user" ? (entry.realName || entry.name) : entry.name
    }

    function refresh() {
        var item = options.itemAt(currentIndex)
        currentText = item ? item.label : ""
    }

    onCurrentIndexChanged: refresh()

    TextButton {
        id: button
        anchors.fill: parent
        text: selector.currentText + (selector.hasChoice ? "  ▾" : "")
        enabled: selector.hasChoice
        activeFocusOnTab: selector.hasChoice
        onClicked: list.visible = !list.visible
    }

    Rectangle {
        id: list
        visible: false
        anchors.bottom: button.top
        anchors.bottomMargin: 8
        anchors.left: button.left
        width: Math.max(180, column.implicitWidth)
        height: column.implicitHeight + 12
        radius: 12
        color: "#1b1b1b"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)

        Column {
            id: column
            x: 6
            y: 6
            width: parent.width - 12

            Repeater {
                id: options
                model: selector.model
                onCountChanged: selector.refresh()

                Item {
                    required property int index
                    required property var model
                    property string label: selector.labelFor(model)

                    width: column.width
                    height: 34
                    Component.onCompleted: selector.refresh()

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: optionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: parent.label
                        color: "#ececec"
                        font.family: "Noto Sans"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: optionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selector.currentIndex = parent.index
                            list.visible = false
                            selector.picked()
                        }
                    }
                }
            }
        }
    }
}
