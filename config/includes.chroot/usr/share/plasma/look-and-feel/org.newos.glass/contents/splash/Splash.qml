// NEWOS loading screen: black, white logo, Windows 8 style orbiting dots.
import QtQuick

Rectangle {
    id: root
    color: "#000000"
    property int stage   // set by ksplash, 1..6

    Image {
        id: logo
        source: "images/logo.svg"
        sourceSize.width: 360
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -60
        opacity: 0
        NumberAnimation on opacity { to: 1; duration: 600; easing.type: Easing.OutCubic }
    }

    // Five dots chasing each other around a circle, like Windows 8
    Item {
        id: spinner
        width: 56; height: 56
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: 64
        Repeater {
            model: 5
            Item {
                anchors.fill: parent
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: "#ffffff"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                SequentialAnimation on rotation {
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 140 }
                    NumberAnimation { from: 0; to: 360; duration: 1800; easing.type: Easing.InOutCubic }
                    PauseAnimation { duration: (4 - index) * 140 + 300 }
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: spinner.bottom
        anchors.topMargin: 36
        text: root.stage < 4 ? "Starting secure session" : "Almost ready"
        color: "#b0b0b5"
        font.pixelSize: 15
        font.weight: Font.Light
        font.letterSpacing: 1
    }
}
