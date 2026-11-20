import QtQuick
import QtQuick3D
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: panel

    property var vehicle
    property url meshUrl: QGroundControl.loadGlobalSetting("RobotVisualMeshUrl", cadGeometry.defaultSource.toString())
    readonly property bool _attitudeAvailable: !!vehicle && !vehicle.vehicleLinkManager.communicationLost &&
                                               vehicle.vehicle.telemetryAvailable
    readonly property bool _positionAvailable: !!vehicle && !vehicle.vehicleLinkManager.communicationLost &&
                                               vehicle.localPosition.telemetryAvailable
    readonly property real _roll: _attitudeAvailable ? finiteOr(vehicle.roll.rawValue) : 0
    readonly property real _pitch: _attitudeAvailable ? finiteOr(vehicle.pitch.rawValue) : 0
    readonly property real _yaw: _attitudeAvailable ? finiteOr(vehicle.heading.rawValue) : 0

    function finiteOr(value) {
        return typeof value === "number" && isFinite(value) ? value : 0
    }

    function positionText() {
        if (!_positionAvailable) {
            return qsTr("Position: waiting for local NED data")
        }
        return qsTr("N %1  E %2  D %3 m")
            .arg(finiteOr(vehicle.localPosition.x.rawValue).toFixed(1))
            .arg(finiteOr(vehicle.localPosition.y.rawValue).toFixed(1))
            .arg(finiteOr(vehicle.localPosition.z.rawValue).toFixed(1))
    }

    color: qgcPal.window
    border.color: qgcPal.groupBorder
    clip: true

    QGCPalette { id: qgcPal }

    FileDialog {
        id: meshPicker
        title: qsTr("Select the robot base_link STL")
        nameFilters: [qsTr("STL mesh (*.stl *.STL)")]
        onAccepted: {
            panel.meshUrl = selectedFile
            QGroundControl.saveGlobalSetting("RobotVisualMeshUrl", selectedFile.toString())
        }
    }

    RowLayout {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: ScreenTools.defaultFontPixelWidth

        QGCLabel {
            text: qsTr("SIMULATED ROBOT STATE")
            font.bold: true
            Layout.fillWidth: true
            wrapMode: Text.Wrap
        }
        QGCButton {
            text: qsTr("Model")
            onClicked: meshPicker.open()
        }
        QGCLabel {
            text: !vehicle || vehicle.vehicleLinkManager.communicationLost
                  ? qsTr("OFFLINE") : vehicle.armed ? qsTr("ARMED") : qsTr("DISARMED")
            color: vehicle && vehicle.armed ? "#df5a45" : qgcPal.text
            font.bold: true
            font.pointSize: ScreenTools.smallFontPointSize
        }
    }

    View3D {
        id: robotView
        anchors.top: header.bottom
        anchors.bottom: readout.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
        camera: sceneCamera
        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Color
            clearColor: "#132230"
            antialiasingMode: SceneEnvironment.MSAA
        }

        PerspectiveCamera {
            id: sceneCamera
            position: Qt.vector3d(255, 198, -345)
            eulerRotation: Qt.vector3d(-25, 144, 0)
            clipFar: 2000
            fieldOfView: 45
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-35, 30, 0)
            brightness: 1.5
            ambientColor: "#7798a8"
        }

        PrincipledMaterial { id: frameMaterial; baseColor: "#f5b543"; roughness: 0.65 }
        PrincipledMaterial { id: hullMaterial; baseColor: "#d7e3e8"; metalness: 0.25; roughness: 0.4 }
        PrincipledMaterial {
            id: cadMaterial
            baseColor: cadGeometry.colored ? "#ffffff" : "#d7e3e8"
            vertexColorsEnabled: cadGeometry.colored
            metalness: 0.12
            roughness: 0.62
        }
        PrincipledMaterial { id: floatMaterial; baseColor: "#e8d073"; roughness: 0.8 }
        PrincipledMaterial { id: thrusterMaterial; baseColor: "#283e48"; metalness: 0.2; roughness: 0.6 }
        PrincipledMaterial { id: cameraMaterial; baseColor: "#265a83"; metalness: 0.15; roughness: 0.2 }

        // In this fixed camera, local -Z is forward, +X is starboard, and +Y is up.
        // Separate nodes keep NED yaw, pitch and roll in the expected body order.
        Node {
            eulerRotation.y: -panel._yaw
            Node {
                eulerRotation.x: panel._pitch
                Node {
                    eulerRotation.z: -panel._roll

                    Model {
                        geometry: RobotStlGeometry {
                            id: cadGeometry
                            source: panel.meshUrl
                        }
                        visible: cadGeometry.loaded
                        materials: [cadMaterial]
                    }

                    Node {
                        visible: !cadGeometry.loaded

                        Model {
                            source: "#Cylinder"
                            eulerRotation.x: 90
                            scale: Qt.vector3d(0.62, 2.4, 0.62)
                            materials: [hullMaterial]
                        }

                        Repeater3D {
                            model: 2
                            delegate: Model {
                                required property int index
                                source: "#Cube"
                                x: index === 0 ? -91 : 91
                                scale: Qt.vector3d(0.13, 0.13, 2.9)
                                materials: [frameMaterial]
                            }
                        }

                        Repeater3D {
                            model: 2
                            delegate: Model {
                                required property int index
                                source: "#Cube"
                                z: index === 0 ? -124 : 124
                                scale: Qt.vector3d(1.95, 0.12, 0.13)
                                materials: [frameMaterial]
                            }
                        }

                        Repeater3D {
                            model: 2
                            delegate: Model {
                                required property int index
                                source: "#Cube"
                                position: Qt.vector3d(index === 0 ? -48 : 48, 43, 0)
                                scale: Qt.vector3d(0.62, 0.20, 2.3)
                                materials: [floatMaterial]
                            }
                        }

                        Model {
                            source: "#Cube"
                            position: Qt.vector3d(0, 19, -146)
                            scale: Qt.vector3d(0.50, 0.23, 0.17)
                            materials: [cameraMaterial]
                        }

                        // Eight independently placed thruster housings: four vertical,
                        // and four canted horizontal. This is a schematic until a mesh is exported.
                        Repeater3D {
                            model: 8
                            delegate: Node {
                                required property int index
                                readonly property bool vertical: index < 4
                                position: Qt.vector3d(index % 2 === 0 ? -115 : 115,
                                                      0,
                                                      vertical ? (Math.floor(index / 2) === 0 ? -112 : 112)
                                                               : (Math.floor((index - 4) / 2) === 0 ? -58 : 58))
                                eulerRotation: vertical ? Qt.vector3d(0, 0, 0)
                                                        : Qt.vector3d(90, index % 2 === 0 ? -42 : 42, 0)

                                Model {
                                    source: "#Cylinder"
                                    scale: Qt.vector3d(0.47, 0.55, 0.47)
                                    materials: [thrusterMaterial]
                                }
                                Model {
                                    source: "#Cylinder"
                                    y: 30
                                    scale: Qt.vector3d(0.55, 0.08, 0.55)
                                    materials: [frameMaterial]
                                }
                            }
                        }
                    }
                }
            }
        }

    }

    Column {
        id: readout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.15

        QGCLabel {
            text: panel._attitudeAvailable
                  ? qsTr("R %1°  P %2°  Y %3°").arg(panel._roll.toFixed(1)).arg(panel._pitch.toFixed(1)).arg(panel._yaw.toFixed(1))
                  : qsTr("Attitude: waiting for telemetry")
            width: parent.width
            wrapMode: Text.Wrap
            font.pointSize: ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text: panel.positionText()
            width: parent.width
            wrapMode: Text.Wrap
            font.pointSize: ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text: vehicle ? qsTr("Mode: %1").arg(vehicle.flightMode) : qsTr("Mode: —")
            width: parent.width
            wrapMode: Text.Wrap
            font.pointSize: ScreenTools.smallFontPointSize
        }
        QGCLabel {
            text: cadGeometry.loaded ? (cadGeometry.colored ? qsTr("Robot mesh · local part colors")
                                                          : qsTr("Robot mesh · no part colors"))
                                     : cadGeometry.errorString.length > 0 ? cadGeometry.errorString
                                                                          : qsTr("Eight-thruster schematic")
            width: parent.width
            wrapMode: Text.Wrap
            font.pointSize: ScreenTools.smallFontPointSize
        }
    }
}
