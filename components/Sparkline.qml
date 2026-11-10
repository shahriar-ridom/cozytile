import QtQuick
import "../config"

// Filled line graph of a rolling series. `values` oldest first; scaled to 0..maxValue.
Canvas {
    id: root
    property var values: []
    property real maxValue: 1
    property int samples: 60
    property color lineColor: Theme.accent

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        // faint guide lines
        ctx.strokeStyle = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07);
        ctx.lineWidth = 1;
        for (let g = 1; g < 4; g++) {
            const gy = Math.round(height * g / 4) + 0.5;
            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(width, gy); ctx.stroke();
        }
        const v = values;
        if (!v || v.length < 2) return;
        const step = width / (samples - 1);
        const x0 = width - (v.length - 1) * step;
        const y = i => height - 2 - Math.max(0, Math.min(1, v[i] / maxValue)) * (height - 4);
        ctx.beginPath();
        ctx.moveTo(x0, y(0));
        for (let i = 1; i < v.length; i++) ctx.lineTo(x0 + i * step, y(i));
        ctx.strokeStyle = lineColor; ctx.lineWidth = 1.6; ctx.lineJoin = "round"; ctx.stroke();
        ctx.lineTo(x0 + (v.length - 1) * step, height); ctx.lineTo(x0, height); ctx.closePath();
        ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.16);
        ctx.fill();
    }
}
