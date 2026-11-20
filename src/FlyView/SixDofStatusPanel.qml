import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: panel

    property var vehicle
    property var _manualAxes: vehicle ? vehicle.manualControlAxes : []
    property real _nowMs: Date.now()
    readonly property bool _connected: !!vehicle && !vehicle.vehicleLinkManager.communicationLost
    readonly property bool _localAvailable: _connected && vehicle.localPosition.telemetryAvailable
    readonly property bool _attitudeAvailable: _connected && vehicle.vehicle.telemetryAvailable
    readonly property bool _inputAvailable: _connected && vehicle.manualControlUpdatedMs > 0 &&
                                             _nowMs - vehicle.manualControlUpdatedMs < 1500

    readonly property var _poseRows: [
        { label: qsTr("x · North"), fact: vehicle ? vehicle.localPosition.x : null, source: "local", unit: "m" },
        { label: qsTr("y · East"), fact: vehicle ? vehicle.localPosition.y : null, source: "local", unit: "m" },
        { label: qsTr("z · Down"), fact: vehicle ? vehicle.localPosition.z : null, source: "local", unit: "m" },
        { label: qsTr("Roll"), fact: vehicle ? vehicle.vehicle.roll : null, source: "attitude", unit: "°" },
        { label: qsTr("Pitch"), fact: vehicle ? vehicle.vehicle.pitch : null, source: "attitude", unit: "°" },
        { label: qsTr("Yaw"), fact: vehicle ? vehicle.vehicle.heading : null, source: "attitude", unit: "°" }
    ]
    readonly property var _motionRows: [
        { label: qsTr("vx · North"), fact: vehicle ? vehicle.localPosition.vx : null, source: "local", unit: "m/s" },
        { label: qsTr("vy · East"), fact: vehicle ? vehicle.localPosition.vy : null, source: "local", unit: "m/s" },
        { label: qsTr("vz · Down"), fact: vehicle ? vehicle.localPosition.vz : null, source: "local", unit: "m/s" },
        { label: qsTr("p · Roll rate"), fact: vehicle ? vehicle.vehicle.rollRate : null, source: "attitude", unit: "°/s" },
        { label: qsTr("q · Pitch rate"), fact: vehicle ? vehicle.vehicle.pitchRate : null, source: "attitude", unit: "°/s" },
        { label: qsTr("r · Yaw rate"), fact: vehicle ? vehicle.vehicle.yawRate : null, source: "attitude", unit: "°/s" }
    ]
    readonly property var _inputRows: [
        { label: qsTr("x · Forward"), axis: 0 },
        { label: qsTr("y · Lateral"), axis: 1 },
        { label: qsTr("z · Thrust"), axis: 2 },
        { label: qsTr("r · Yaw"), axis: 3 },
        { label: qsTr("s · Pitch"), axis: 4 },
        { label: qsTr("t · Roll"), axis: 5 }
    ]

    function displayValue(value, unit, available) {
        if (!available || typeof value !== "number" || !isFinite(value)) {
            return "—"
        }
        return value.toFixed(2) + (unit ? " " + unit : "")
    }

    color: qgcPal.window
    border.color: qgcPal.groupBorder
    clip: true

    QGCPalette { id: qgcPal }

    Timer {
        interval: 500
        running: panel.visible
        repeat: true
        onTriggered: panel._nowMs = Date.now()
    }

    ScrollView {
        id: statusScroll
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: statusScroll.availableWidth
            spacing: ScreenTools.defaultFontPixelHeight * 0.6

            QGCLabel {
                text: qsTr("6-DOF ROBOT STATUS")
                font.bold: true
                font.pointSize: ScreenTools.largeFontPointSize
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            QGCLabel {
                text: vehicle ? qsTr("Vehicle %1").arg(vehicle.id) : qsTr("No vehicle connected")
                Layout.fillWidth: true
            }

            QGCLabel {
                text: qsTr("Pose · local NED / degrees")
                font.bold: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
            }

            Repeater {
                model: panel._poseRows
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    QGCLabel { text: modelData.label; Layout.fillWidth: true }
                    QGCLabel {
                        text: panel.displayValue(modelData.fact ? modelData.fact.rawValue : null,
                                                 modelData.unit,
                                                 modelData.source === "local" ? panel._localAvailable : panel._attitudeAvailable)
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            QGCLabel {
                text: qsTr("Motion · NED velocity / body rates")
                font.bold: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
            }

            Repeater {
                model: panel._motionRows
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    QGCLabel { text: modelData.label; Layout.fillWidth: true }
                    QGCLabel {
                        text: panel.displayValue(modelData.fact ? modelData.fact.rawValue : null,
                                                 modelData.unit,
                                                 modelData.source === "local" ? panel._localAvailable : panel._attitudeAvailable)
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            QGCLabel {
                text: qsTr("Control input · QGC MANUAL_CONTROL")
                font.bold: true
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            Repeater {
                model: panel._inputRows
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    QGCLabel { text: modelData.label; Layout.fillWidth: true }
                    QGCLabel {
                        text: panel.displayValue(panel._manualAxes.length > modelData.axis
                                                 ? panel._manualAxes[modelData.axis] : null,
                                                 "", panel._inputAvailable)
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            QGCLabel {
                text: qsTr("Normalized axes; thrust range depends on vehicle. — means no recent input.")
                font.pointSize: ScreenTools.smallFontPointSize
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.5
            }
        }
    }
}
