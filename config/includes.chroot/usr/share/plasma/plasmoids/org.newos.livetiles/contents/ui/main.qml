// NEWOS Live Tiles: Windows 8 style "Start" group on the desktop.
// Dark glass tiles, white text and icons. Some tiles update live.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property int unit: 132          // medium tile size
    readonly property int gap: 8
    property string netMode: "…"
    property string torPercent: "0"
    property date now: new Date()

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // Live data: network mode and Tor bootstrap progress
    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["newos-netmode status", "cut -d' ' -f1 /run/newos/tor-progress"]
        interval: 3000
        onNewData: (source, data) => {
            const out = (data.stdout || "").trim()
            if (source.startsWith("newos-netmode")) root.netMode = out
            else root.torPercent = out
        }
    }
    P5Support.DataSource {
        id: launcher
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }
    function run(cmd) { launcher.connectSource(cmd) }
    function term(cmd) { run("konsole -e bash -c '" + cmd + "; exec bash'") }

    fullRepresentation: ColumnLayout {
        spacing: 24
        Layout.preferredWidth: 6 * root.unit + 5 * root.gap
        Layout.preferredHeight: 4 * root.unit + 3 * root.gap + 90

        Text {
            text: "Start"
            color: "white"
            font.pixelSize: 44
            font.weight: Font.Light
        }

        GridLayout {
            columns: 6
            rowSpacing: root.gap
            columnSpacing: root.gap

            // Row 1
            Tile {
                wide: true
                label: "Network"
                icon: root.netMode === "tor" ? "security-high-symbolic"
                    : root.netMode === "direct" ? "security-low-symbolic" : "network-offline-symbolic"
                bigText: root.netMode === "tor" ? "TOR" : root.netMode.toUpperCase()
                subText: root.netMode === "tor"
                         ? (root.torPercent === "100" ? "Connected · anonymous" : "Connecting… " + root.torPercent + "%")
                         : root.netMode === "direct" ? "Real IP · not anonymous" : "No network"
                onClicked: root.run("newos-netpolicy")
            }
            Tile {
                wide: true
                label: Qt.formatDate(root.now, "dddd")
                bigText: Qt.formatTime(root.now, "HH:mm")
                subText: Qt.formatDate(root.now, "d MMMM yyyy") + " · UTC"
            }
            Tile { label: "Tor Browser"; icon: "internet-web-browser-symbolic"; onClicked: root.run("torbrowser-launcher") }
            Tile { label: "Terminal";    icon: "utilities-terminal-symbolic";   onClicked: root.run("konsole") }

            // Row 2
            Tile { label: "Files";       icon: "folder-symbolic";               onClicked: root.run("dolphin") }
            Tile { label: "Recon";       icon: "edit-find-symbolic";            onClicked: root.term("echo nmap via Tor: proxychains4 -q nmap -sT -Pn TARGET") }
            Tile { label: "Web";         icon: "applications-internet-symbolic"; onClicked: root.run("burpsuite") }
            Tile { label: "Exploit";     icon: "dialog-warning-symbolic";       onClicked: root.term("msfconsole") }
            Tile { label: "Wireless";    icon: "network-wireless-symbolic";     onClicked: root.term("echo Wireless tools need direct mode: newos-netmode direct") }
            Tile { label: "Passwords";   icon: "dialog-password-symbolic";      onClicked: root.term("john --help | head -n 20") }

            // Row 3
            Tile { wide: true; label: "App Network Settings"; icon: "preferences-system-network-symbolic"; onClicked: root.run("newos-netpolicy") }
            Tile { label: "Settings";    icon: "preferences-system-symbolic";   onClicked: root.run("systemsettings") }
            Tile { label: "All tools";   icon: "view-app-grid-symbolic";        onClicked: root.run("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu") }
        }
    }

    // A Windows 8 style tile in dark glass
    component Tile: Rectangle {
        id: tile
        property bool wide: false
        property string label
        property string icon: ""
        property string bigText: ""
        property string subText: ""
        signal clicked()

        Layout.columnSpan: wide ? 2 : 1
        Layout.preferredWidth: wide ? 2 * root.unit + root.gap : root.unit
        Layout.preferredHeight: root.unit
        color: Qt.rgba(1, 1, 1, mouse.pressed ? 0.22 : mouse.containsMouse ? 0.15 : 0.08)
        border.color: Qt.rgba(1, 1, 1, mouse.containsMouse ? 0.45 : 0.14)
        border.width: 1
        scale: mouse.pressed ? 0.97 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90 } }

        Kirigami.Icon {
            visible: tile.icon !== "" && tile.bigText === ""
            source: tile.icon
            isMask: true
            color: "white"
            width: 44; height: 44
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -8
        }
        Column {
            visible: tile.bigText !== ""
            anchors { left: parent.left; top: parent.top; margins: 14 }
            spacing: 2
            Text { text: tile.bigText; color: "white"; font.pixelSize: 40; font.weight: Font.Light }
            Text { text: tile.subText; color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: 13 }
        }
        Text {
            text: tile.label
            color: "white"
            font.pixelSize: 13
            anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.clicked()
        }
    }
}
