import QtQuick

// Fixed-size slot for a ComboRow option's icon. Collapses to zero width when
// there is no icon, so every dropdown that passes plain strings lays out
// exactly as it did before.
Item {
    id: root

    property string path: ""

    width: path !== "" ? 18 : 0
    height: 18
    visible: path !== ""

    Image {
        // Cursor arrows are taller than they are wide and vary from 16px to
        // 64px between themes, so fit into the slot rather than assuming a
        // shape. sourceSize is deliberately unset: the files are already
        // small, and forcing one would upscale the 16px themes on load.
        anchors.fill: parent
        source: root.path !== "" ? "file://" + root.path : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }
}
