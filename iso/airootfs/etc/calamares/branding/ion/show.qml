import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Rectangle {
        anchors.fill: parent
        color: "#1a1a2e"
        z: -1
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1a1a2e"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Image {
                    source: "/usr/share/pixmaps/ion-logo.svg"
                    width: 128
                    height: 128
                    anchors.horizontalCenter: parent.horizontalCenter
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    text: "Installing Ion Linux..."
                    color: "#00d4ff"
                    font.pixelSize: 28
                    font.weight: Font.Light
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "A minimal, rolling release distribution"
                    color: "#88ccee"
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
