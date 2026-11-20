import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id: panel

    property string streamUrl: QGroundControl.loadGlobalSetting("ZED2iDepthStreamUrl", "")

    function applyUrl() {
        streamUrl = urlField.text.trim()
        QGroundControl.saveGlobalSetting("ZED2iDepthStreamUrl", streamUrl)
    }

    color: qgcPal.window
    border.color: qgcPal.groupBorder
    clip: true

    QGCPalette { id: qgcPal }

    QGCLabel {
        id: title
        text: qsTr("ZED2i DEPTH VIEW")
        font.bold: true
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: ScreenTools.defaultFontPixelWidth
    }

    Rectangle {
        id: viewport
        color: "#101820"
        anchors.top: title.bottom
        anchors.bottom: urlRow.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
        clip: true

        VideoOutput {
            id: depthOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
            visible: depthPlayer.hasVideo
        }

        QGCLabel {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - ScreenTools.defaultFontPixelWidth * 3)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: "white"
            visible: !depthPlayer.hasVideo
            text: panel.streamUrl.length === 0
                  ? qsTr("Waiting for a ZED2i colorized depth video stream")
                  : depthPlayer.errorString.length > 0
                    ? depthPlayer.errorString
                    : qsTr("Waiting for depth video frames")
        }
    }

    MediaPlayer {
        id: depthPlayer
        source: panel.streamUrl
        videoOutput: depthOutput
        onSourceChanged: {
            if (source.toString().length > 0) {
                play()
            } else {
                stop()
            }
        }
        Component.onCompleted: {
            if (source.toString().length > 0) {
                play()
            }
        }
    }

    RowLayout {
        id: urlRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
        spacing: ScreenTools.defaultFontPixelWidth * 0.5

        TextField {
            id: urlField
            Layout.fillWidth: true
            text: panel.streamUrl
            placeholderText: qsTr("Depth video URL")
            selectByMouse: true
            onAccepted: panel.applyUrl()
        }

        QGCButton {
            text: qsTr("Open")
            onClicked: panel.applyUrl()
        }
    }
}
