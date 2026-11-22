// NEWOS default layout: Windows 8 style.
// One full-width dark glass taskbar at the bottom, a Start button that opens
// the full-screen app grid, and the Live Tiles "Start" group on the desktop.

var panel = new Panel;
panel.location = "bottom";
panel.height = Math.round(gridUnit * 2.4);
panel.floating = false;
panel.hiding = "none";

var start = panel.addWidget("org.kde.plasma.kickerdash");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "/usr/share/newos/start.svg");

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:torbrowser.desktop",
    "applications:newos-netpolicy.desktop"
]);

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");

var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "shortDate");

panel.addWidget("org.kde.plasma.showdesktop");

var all = desktops();
for (var i = 0; i < all.length; i++) {
    var d = all[i];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/NEWOS/contents/images/3840x2160.svg");
    if (i === 0) {
        d.addWidget("org.newos.livetiles", 64, 48, 960, 640);
    }
}
