import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.Toolbar

Item {
    id: _root

    // These are used by MainRootWindow and the flight widget layer.
    property var planController: _planController
    property var guidedController: _guidedController
    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var _missionController: _planController.missionController
    property var _geoFenceController: _planController.geoFenceController
    property var _rallyPointController: _planController.rallyPointController
    property var _guidedController: guidedActionsController
    property var _guidedValueSlider: guidedValueSlider
    property var _widgetLayer: widgetLayer
    property real _margins: ScreenTools.defaultFontPixelWidth / 2
    property real _toolsMargin: ScreenTools.defaultFontPixelWidth * 0.75
    property real _widgetMargin: ScreenTools.defaultFontPixelWidth * 0.75
    property real _fullItemZorder: 0

    PlanMasterController {
        id: _planController
        flyView: true
        Component.onCompleted: start()
    }

    QGCToolInsets {
        id: _toolInsets
        topEdgeLeftInset: toolbar.height
        topEdgeCenterInset: topEdgeLeftInset
        topEdgeRightInset: topEdgeLeftInset
    }

    Item {
        id: videoArea
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: QGroundControl.videoManager.fullScreen ? parent.right : visualColumn.left

        // PipState still needs a valid host, although this view never swaps video.
        Item { id: videoPipHost; visible: false }

        FlyViewVideo {
            id: videoControl
            anchors.fill: parent
            pipView: videoPipHost
            embedded: true
        }

        FlyViewWidgetLayer {
            id: widgetLayer
            anchors.fill: parent
            anchors.margins: _widgetMargin
            anchors.topMargin: toolbar.height + _widgetMargin
            z: _fullItemZorder + 2
            parentToolInsets: _toolInsets
            mapControl: null
            viewer3DCameraController: null
            visible: !QGroundControl.videoManager.fullScreen
        }

        FlyViewCustomLayer {
            id: customOverlay
            anchors.fill: widgetLayer
            z: _fullItemZorder + 2
            parentToolInsets: widgetLayer.totalToolInsets
            mapControl: null
            visible: !QGroundControl.videoManager.fullScreen
        }

        GuidedActionsController {
            id: guidedActionsController
            missionController: _missionController
            guidedValueSlider: _guidedValueSlider
        }

        GuidedValueSlider {
            id: guidedValueSlider
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: toolbar.height
            z: QGroundControl.zOrderTopMost
            visible: false
        }
    }

    Item {
        id: visualColumn
        width: Math.min(ScreenTools.defaultFontPixelWidth * 64, _root.width * 0.36)
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        anchors.right: statusPanel.left
        visible: !QGroundControl.videoManager.fullScreen

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
            spacing: ScreenTools.defaultFontPixelWidth

            RobotStatePanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: visualColumn.height * 0.56
                vehicle: _activeVehicle
            }

            DepthViewPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: visualColumn.height * 0.44
            }
        }
    }

    SixDofStatusPanel {
        id: statusPanel
        width: Math.min(ScreenTools.defaultFontPixelWidth * 38, _root.width * 0.29)
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        vehicle: _activeVehicle
        visible: !QGroundControl.videoManager.fullScreen
    }

    FlyViewToolBar {
        id: toolbar
        guidedValueSlider: _guidedValueSlider
        visible: !QGroundControl.videoManager.fullScreen
    }
}
