import QtQuick
import "../common"

// Opaque rounded section floating against the bar background — same look as
// the old wibar's section_pill(). One pill per slot; the bar reparents
// sections into `container` in layout order (Bar.qml reflow()).
//
// A Grid rather than a Column so the same pill works for a vertical or a
// horizontal bar: one column or one row, with the cell alignment centring
// sections across the bar so they don't each need their own anchors.
Rectangle {
    id: pill

    property bool vertical: BarEdge.vertical
    // Padding along the bar and across it. Swapping them with the
    // orientation keeps a horizontal bar as thin as a vertical one is
    // narrow, rather than making it tall.
    property int padAlong: 8
    property int padAcross: 4

    readonly property alias container: grid
    default property alias content: grid.data

    // An empty slot draws nothing at all: with no visible sections the grid
    // has no implicit size, and a bare rounded rectangle sitting on the bar
    // would be a puzzle rather than a hint.
    visible: grid.implicitWidth > 0 && grid.implicitHeight > 0

    color: Theme.base
    radius: Theme.radius
    implicitWidth: grid.implicitWidth
        + (pill.vertical ? pill.padAcross : pill.padAlong) * 2
    implicitHeight: grid.implicitHeight
        + (pill.vertical ? pill.padAlong : pill.padAcross) * 2

    Grid {
        id: grid
        anchors.centerIn: parent
        // One column, or one row wide enough for anything. `rows` is left
        // alone deliberately: setting both means that when the bar changes
        // edge, QML re-evaluates them one at a time and Grid spends an
        // instant believing it is 1×1, which it complains about. Only
        // `columns` moving avoids that state entirely. Every Grid in the bar
        // switches orientation this way. The unused columns cost one
        // trailing `spacing` and nothing else.
        columns: pill.vertical ? 1 : 99
        spacing: 4
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
    }
}
