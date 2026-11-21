import QtQuick
import "../common"
import "EditorShapes.js" as Shapes

// One annotation, drawn in image pixels: a small Canvas for strokes, a Text
// for labels, a magnified-down copy of the image for the redact box.
Item {
    id: sv

    property var shape: null          // see EditorShapes.js; null = nothing
    property Item image: null         // the screenshot, for pixelation
    property bool emphasized: false

    readonly property var b: shape ? Shapes.bounds(shape) : ({ x: 0, y: 0, w: 0, h: 0 })
    readonly property real pad: shape ? Shapes.pad(shape) : 0
    readonly property string kind: shape ? shape.t : ""

    visible: shape !== null
    x: b.x - pad
    y: b.y - pad
    width: b.w + 2 * pad
    height: b.h + 2 * pad

    Canvas {
        anchors.fill: parent
        visible: sv.kind !== "" && sv.kind !== "text" && sv.kind !== "pix"
        renderStrategy: Canvas.Immediate
        renderTarget: Canvas.Image
        // Repaint when the shape (or the canvas size, which clears it) changes.
        property var s: sv.shape
        onSChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (sv.shape && visible)
                Shapes.paint(ctx, sv.shape, sv.x, sv.y);
        }
    }

    // Pixelate: the region of the image at full size (mipmapped), drawn into
    // a layer a fraction of its size so the downscale averages each block,
    // then stretched back with nearest-neighbor. Sampling the image straight
    // into the small texture would pick single pixels, not an average.
    Item {
        id: pix
        anchors.fill: parent
        visible: sv.kind === "pix" && sv.image !== null
        layer.enabled: visible
        layer.smooth: false
        layer.textureSize: {
            const k = sv.shape ? Shapes.pixBlock(sv.shape) : 8;
            return Qt.size(Math.max(1, Math.ceil(sv.b.w / k)), Math.max(1, Math.ceil(sv.b.h / k)));
        }
        ShaderEffectSource {
            width: pix.width
            height: pix.height
            sourceItem: sv.image
            sourceRect: Qt.rect(sv.b.x, sv.b.y, Math.max(1, sv.b.w), Math.max(1, sv.b.h))
            mipmap: true
            smooth: true
        }
    }

    Text {
        visible: sv.kind === "text"
        text: sv.shape && sv.shape.text ? sv.shape.text : ""
        color: sv.shape ? sv.shape.c : "white"
        font.family: Theme.fontFamily
        font.bold: true
        font.pixelSize: sv.shape ? Shapes.fontPx(sv.shape.w) : 20
        style: Text.Outline
        styleColor: sv.shape ? Shapes.contrast(sv.shape.c) : "black"
    }
}
