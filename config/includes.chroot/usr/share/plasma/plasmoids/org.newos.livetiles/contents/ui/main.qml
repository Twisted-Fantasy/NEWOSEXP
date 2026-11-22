// NEWOS Live Tiles: a grid of tiles that update themselves.
// First pass: Tor/network status, clock, and launcher tiles.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root
    property string netMode: "…"
    readonly property color neonCyan: "#00F0FF"
    readonly property color neonMagenta: "#FF2BD6"
    readonly property color neonYellow: "#F5E400"
    readonly property color bg: "#0B0B14"

    preferredRepresentation: fullRepresentation

    // Polls newos-netmode for the live network tile
    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: ["/usr/local/bin/newos-netmode status"]
        interval: 3000
        onNewData: (source, data) => root.netMode = data.stdout.trim()
    }

    fullRepresentation: GridLayout {
        columns: 4
        rowSpacing: 6
        columnSpacing: 6
        Layout.preferredWidth: 4 * 130
        Layout.preferredHeight: 2 * 130

        Tile {
            Layout.columnSpan: 2
            accent: root.netMode === "tor" ? root.neonCyan
                  : root.netMode === "direct" ? root.neonMagenta : root.neonYellow
            title: "NETWORK"
            value: root.netMode.toUpperCase()
            command: "konsole -e newos-netmode status"
        }
        Tile {
            Layout.columnSpan: 2
            accent: root.neonMagenta
            title: "TIME (UTC)"
            value: Qt.formatTime(clock.now, "HH:mm")
            Timer { id: clock; property date now: new Date(); interval: 1000; running: true; repeat: true; onTriggered: now = new Date() }
        }
        Tile { accent: root.neonCyan;    title: "BROWSER";  value: "Tor";       command: "torbrowser-launcher" }
        Tile { accent: root.neonYellow;  title: "RECON";    value: "nmap";      command: "konsole -e proxychains4 -q nmap -h" }
        Tile { accent: root.neonMagenta; title: "WEB";      value: "Burp";      command: "burpsuite" }
        Tile { accent: root.neonCyan;    title: "EXPLOIT";  value: "msf";       command: "konsole -e msfconsole" }
    }

    component Tile: Rectangle {
        property color accent
        property string title
        property string value
        property string command: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 124
        color: root.bg
        border.color: accent
        border.width: mouse.containsMouse ? 2 : 1
        radius: 2
        Column {
            anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
            Text { text: value; color: accent; font.family: "JetBrains Mono"; font.pixelSize: 26; font.bold: true }
            Text { text: title; color: "#8A8AA3"; font.family: "JetBrains Mono"; font.pixelSize: 11 }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (command !== "") launcher.connectSource(command)
        }
    }

    P5Support.DataSource {
        id: launcher
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }
}
