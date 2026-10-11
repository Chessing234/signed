import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Turns a chosen picture into a named signature: shows the picture beside the
// result with the paper removed, a threshold to tune it, and a name.
Rectangle {
    id: dialog

    property color accent: "#FFD60A"
    property color accentForeground: "black"
    property string error: ""
    signal saved(string name)

    function open() {
        error = "";
        threshold.value = 0.25;
        backend.setPreviewThreshold(0.25);
        nameField.text = backend.previewName;
        visible = true;
        nameField.forceActiveFocus();
        nameField.selectAll();
    }
    function close() {
        visible = false;
    }
    function save() {
        const name = nameField.text.trim();
        const invalid = backend.signatures.validateName(name);
        if (invalid !== "") {
            error = invalid;
            return;
        }
        const failure = backend.saveSignature(name);
        if (failure !== "") {
            error = failure;
            return;
        }
        close();
        saved(name);
    }

    readonly property bool replacing: backend.signatures.contains(nameField.text.trim())

    visible: false
    anchors.fill: parent
    color: "#000000b0"

    MouseArea { anchors.fill: parent }
    Keys.onEscapePressed: close()

    Rectangle {
        anchors.centerIn: parent
        width: 620
        height: layout.implicitHeight + 48
        radius: 14
        color: "#1c1c1e"

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: 24
            spacing: 0

            Label { text: "Add signature"; color: "white"; font.pixelSize: 17; font.weight: Font.DemiBold }
            Label {
                Layout.topMargin: 4
                Layout.bottomMargin: 18
                text: "Use a scan or a well-lit photo of your signature on white paper."
                color: "#b8b8bc"
                font.pixelSize: 13
            }

            RowLayout {
                spacing: 14
                Layout.fillWidth: true

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 170
                    radius: 8
                    color: "#e9e4da"
                    clip: true
                    Image {
                        anchors.fill: parent
                        anchors.margins: 8
                        source: dialog.visible ? "image://preview/source/" + backend.previewRevision : ""
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        mipmap: true
                    }
                }
                Label { text: "→"; color: "#8e8e93"; font.pixelSize: 20 }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 170
                    radius: 8
                    clip: true
                    color: "white"

                    // A checkerboard shows what became transparent.
                    Grid {
                        anchors.fill: parent
                        columns: Math.ceil(width / 8)
                        Repeater {
                            model: Math.ceil(parent.width / 8) * Math.ceil(parent.height / 8)
                            Rectangle {
                                required property int index
                                width: 8
                                height: 8
                                readonly property int columns: Math.ceil(parent.width / 8)
                                color: (Math.floor(index / columns) + index % columns) % 2 ? "#eeeeee" : "white"
                            }
                        }
                    }
                    Image {
                        anchors.fill: parent
                        anchors.margins: 12
                        source: dialog.visible && !backend.previewEmpty ? "image://preview/result/" + backend.previewRevision : ""
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        mipmap: true
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: backend.previewEmpty
                        text: "No ink left — move the slider toward Less."
                        color: "#666"
                        font.pixelSize: 12
                    }
                }
            }

            Label {
                Layout.topMargin: 18
                text: "Paper threshold"
                color: "#b8b8bc"
                font.pixelSize: 12
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: "Less"; color: "#8e8e93"; font.pixelSize: 12 }
                Slider {
                    id: threshold
                    Layout.fillWidth: true
                    from: 0.05
                    to: 0.6
                    value: 0.25
                    onMoved: backend.setPreviewThreshold(value)
                }
                Label { text: "More"; color: "#8e8e93"; font.pixelSize: 12 }
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                Layout.topMargin: 10
                placeholderText: "Name"
                onTextChanged: dialog.error = ""
                onAccepted: dialog.save()
                Keys.onEscapePressed: dialog.close()
            }

            Label {
                Layout.topMargin: 4
                visible: dialog.error !== "" || dialog.replacing
                text: dialog.error !== "" ? dialog.error : "This replaces the saved signature “" + nameField.text.trim() + "”."
                color: dialog.error !== "" ? dialog.accent : "#b8b8bc"
                font.pixelSize: 12
            }

            RowLayout {
                Layout.topMargin: 20
                Layout.fillWidth: true
                spacing: 10
                BarButton {
                    text: "Choose another image…"
                    accent: dialog.accent
                    onClicked: backend.chooseSignatureImage()
                }
                Item { Layout.fillWidth: true }
                BarButton {
                    text: "Cancel"
                    accent: dialog.accent
                    onClicked: dialog.close()
                }
                BarButton {
                    text: dialog.replacing ? "Replace signature" : "Save signature"
                    primary: true
                    enabled: !backend.previewEmpty
                    accent: dialog.accent
                    accentForeground: dialog.accentForeground
                    onClicked: dialog.save()
                }
            }
        }
    }
}
