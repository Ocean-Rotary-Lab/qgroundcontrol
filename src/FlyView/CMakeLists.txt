# ============================================================================
# Flight Display Module
# In-flight view, telemetry displays, and vehicle control UI
# ============================================================================

qt_add_library(FlyViewModule STATIC)

qt_add_qml_module(FlyViewModule
    URI QGroundControl.FlyView
    VERSION 1.0
    RESOURCE_PREFIX /qml
    SOURCES
        RobotStlGeometry.cc
        RobotStlGeometry.h
    QML_FILES
        CustomGuidedActionsController.qml
        DefaultChecklist.qml
        DepthViewPanel.qml
        FixedWingChecklist.qml
        FlightDisplayViewDummy.qml
        FlightDisplayViewVideoOutput.qml
        FlightDisplayViewQtMultimedia.qml
        FlightDisplayViewUVC.qml
        FlightDisplayViewVideo.qml
        FlyView.qml
        FlyViewAdditionalActionsButton.qml
        FlyViewAdditionalActionsList.qml
        FlyViewAdditionalActionsPanel.qml
        FlyViewAdditionalCustomActionsList.qml
        FlyViewBottomRightRowLayout.qml
        FlyViewCustomLayer.qml
        FlyViewInsetViewer.qml
        FlyViewInstrumentPanel.qml
        FlyViewGripperButton.qml
        FlyViewGripperDropPanel.qml
        FlyViewMap.qml
        FlyViewMissionCompleteDialog.qml
        FlyViewPreFlightChecklistPopup.qml
        FlyViewToolStrip.qml
        FlyViewToolStripActionList.qml

        FlyViewTopRightColumnLayout.qml
        FlyViewTopRightPanel.qml
        FlyViewVideo.qml
        FlyViewWidgetLayer.qml
        GuidedActionConfirm.qml
        GuidedActionLand.qml
        GuidedActionPause.qml
        GuidedActionRTL.qml
        GuidedActionsController.qml
        GuidedActionTakeoff.qml
        GuidedToolStripAction.qml
        GuidedValueSlider.qml
        MultiRotorChecklist.qml
        MultiVehicleList.qml
        ObstacleDistanceOverlay.qml
        ObstacleDistanceOverlayMap.qml
        ObstacleDistanceOverlayVideo.qml
        OnScreenCameraTrackingController.qml
        OnScreenGimbalController.qml
        PreFlightBatteryCheck.qml
        PreFlightCheckList.qml
        PreFlightCheckListShowAction.qml
        PreFlightGPSCheck.qml
        PreFlightRCCheck.qml
        PreFlightSensorsHealthCheck.qml
        PreFlightSoundCheck.qml
        ProximityRadarValues.qml
        ProximityRadarVideoView.qml
        RoverChecklist.qml
        RobotStatePanel.qml
        SixDofStatusPanel.qml
        SubChecklist.qml
        TelemetryValuesBar.qml
        TerrainProgress.qml
        VehicleWarnings.qml
        VirtualJoystick.qml
        VTOLChecklist.qml
)

target_link_libraries(FlyViewModule PUBLIC Qt6::Quick3D)

install(FILES
    "${CMAKE_SOURCE_DIR}/robot_visual/single_link_version/meshes/base_link.STL"
    "${CMAKE_SOURCE_DIR}/robot_visual/single_link_version/meshes/base_link.STL.colors"
    DESTINATION "robot_visual/single_link_version/meshes"
)

install(FILES
    "${CMAKE_SOURCE_DIR}/robot_visual/single_link_version/urdf/robot.urdf"
    DESTINATION "robot_visual/single_link_version/urdf"
)

qt_add_resources(FlyViewModule flyview_resources
    PREFIX "/res"
    BASE "${CMAKE_SOURCE_DIR}/resources"
    FILES
        "${CMAKE_SOURCE_DIR}/resources/Gripper.svg"
        "${CMAKE_SOURCE_DIR}/resources/land.svg"
        "${CMAKE_SOURCE_DIR}/resources/NoVideoBackground.jpg"
        "${CMAKE_SOURCE_DIR}/resources/pause-mission.svg"
)

qt_add_resources(FlyViewModule flyview_qmlimages
    PREFIX "/qmlimages"
    BASE "${CMAKE_SOURCE_DIR}/resources"
    FILES
        "${CMAKE_SOURCE_DIR}/resources/check.svg"
)
