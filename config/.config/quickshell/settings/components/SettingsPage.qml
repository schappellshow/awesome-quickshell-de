import QtQuick
import "../../common"

// Base for every settings page: scrollable column with a title header.
Flickable {
    id: page

    property string title
    default property alias content: col.data

    anchors.fill: parent
    contentHeight: header.implicitHeight + col.implicitHeight + 56
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Text {
        id: header
        x: 24
        y: 18
        text: page.title
        font.family: Theme.fontFamily
        font.bold: true
        font.pointSize: 14
        color: Theme.text
    }

    Column {
        id: col
        x: 24
        y: header.y + header.implicitHeight + 14
        width: page.width - 48
        spacing: 14
    }
}
