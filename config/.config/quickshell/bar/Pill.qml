import QtQuick
import "../common"

// Opaque rounded section floating against the transparent bar background —
// same look as the old wibar's section_pill().
Rectangle {
    id: pill

    property int padV: 8
    property int padH: 4
    default property alias content: col.data

    color: Theme.base
    radius: Theme.radius
    implicitWidth: col.implicitWidth + padH * 2
    implicitHeight: col.implicitHeight + padV * 2

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 4
    }
}
