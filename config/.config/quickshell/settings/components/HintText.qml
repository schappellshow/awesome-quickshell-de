import QtQuick
import "../../common"

// A small muted paragraph under a control, explaining it.
Text {
    width: parent.width
    wrapMode: Text.Wrap
    font.family: Theme.fontFamily
    font.pointSize: 8
    color: Theme.muted
}
