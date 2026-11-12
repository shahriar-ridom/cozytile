import QtQuick
import QtQuick.Shapes
import "../config"

// One tonal piece of the bar. Edges: "none" | "round" | "curve" (S-curve, trapezoid-like).
// Pieces butt against each other so the whole bar reads as a single composition.
Item {
    id: root
    property color tone: Theme.barCapFill
    property string leftEdge: "none"
    property string rightEdge: "none"
    property int slant: Theme.edgeSlant
    property int radius: Theme.barRadius
    property int padding: Theme.pad
    property alias spacing: row.spacing
    default property alias content: row.data

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight

    Behavior on tone { ColorAnimation { duration: Theme.animNormal } }

    function outline(w, h, s, r, le, re) {
        let p = (le === "round") ? `M ${r} 0` : "M 0 0";
        if (re === "round")
            p += ` L ${w - r} 0 A ${r} ${r} 0 0 1 ${w} ${r} L ${w} ${h - r} A ${r} ${r} 0 0 1 ${w - r} ${h}`;
        else if (re === "curve")
            p += ` L ${w} 0 C ${w} ${h * 0.55} ${w - s} ${h * 0.45} ${w - s} ${h}`;
        else
            p += ` L ${w} 0 L ${w} ${h}`;
        if (le === "round")
            p += ` L ${r} ${h} A ${r} ${r} 0 0 1 0 ${h - r} L 0 ${r} A ${r} ${r} 0 0 1 ${r} 0`;
        else if (le === "curve")
            p += ` L ${s} ${h} C ${s} ${h * 0.45} 0 ${h * 0.55} 0 0`;
        else
            p += ` L 0 ${h}`;
        return p + " Z";
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: root.tone
            PathSvg { path: root.outline(root.width, root.height, root.slant, root.radius, root.leftEdge, root.rightEdge) }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap
    }
}
