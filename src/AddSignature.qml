import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Shapes

// Turns a chosen picture into a named signature: shows the picture beside the
// result with the paper removed, a threshold to tune it, and a name.
Rectangle {
    id: dialog

    property color accent: "#FFD60A"
    property color accentForeground: "black"
    property string error: ""
    property var certs: []             // the database's certificates: {id, name, organization}
    property string certId: "new"      // "new" makes a fresh certificate for this signature on save
    property bool certListOpen: false
    property string importError: ""
    signal saved(string name)

    function open() {
        error = "";
        importError = "";
        threshold.value = 0.25;
        backend.setPreviewThreshold(0.25);
        nameField.text = backend.previewName;
        orgField.clear();
        certId = "new";
        visible = true;
        refreshCerts();
        nameField.forceActiveFocus();
        nameField.selectAll();
    }
    function close() {
        visible = false;
    }

    // The certificate is an explicit choice: a fresh one made for this
    // signature on save, or an existing one picked from the list.
    function refreshCerts(preselect) {
        certs = backend.signingCertificates();
        if (preselect !== undefined) {
            certId = preselect;
        } else if (certId !== "new" && !certs.some(cert => cert.id === certId)) {
            certId = "new";  // a certificate that's gone falls back to a new one
        }
        certListOpen = false;
    }
    function save() {
        const name = nameField.text.trim();
        const invalid = backend.signatures.validateName(name);
        if (invalid !== "") {
            error = invalid;
            return;
        }
        const failure = backend.saveSignature(name, orgField.text.trim(), certId === "new" ? "" : certId);
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
        radius: theme.radius
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
                    radius: Math.min(8, theme.radius)
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
                    radius: Math.min(8, theme.radius)
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
                Material.roundedScale: theme.radius
                onTextChanged: dialog.error = ""
                onAccepted: dialog.save()
                Keys.onEscapePressed: dialog.close()

                // The Material floating label, but always visible (a
                // placeholderText would only float up on focus).
                Label {
                    x: 12
                    y: -9
                    text: "Name"
                    color: nameField.activeFocus ? dialog.accent : "#8e8e93"
                    font.pixelSize: 11
                    leftPadding: 4
                    rightPadding: 4
                    background: Rectangle { color: "#1c1c1e" }
                }
            }

            TextField {
                id: orgField
                Layout.fillWidth: true
                Layout.topMargin: 12
                onAccepted: dialog.save()
                Keys.onEscapePressed: dialog.close()

                Label {
                    x: 12
                    y: -9
                    text: "Organization"
                    color: orgField.activeFocus ? dialog.accent : "#8e8e93"
                    font.pixelSize: 11
                    leftPadding: 4
                    rightPadding: 4
                    background: Rectangle { color: "#1c1c1e" }
                }
            }

            Label {
                Layout.topMargin: 4
                visible: dialog.error !== "" || dialog.replacing
                text: dialog.error !== "" ? dialog.error : "This replaces the saved signature “" + nameField.text.trim() + "”."
                color: dialog.error !== "" ? dialog.accent : "#b8b8bc"
                font.pixelSize: 12
            }

            // A row stating which certificate this signature uses: a fresh
            // one made on save (the default), or an existing one picked from
            // the list, which also imports a .p12 from elsewhere.
            ColumnLayout {
                id: certBlock
                Layout.fillWidth: true
                Layout.topMargin: 14
                spacing: 4

                Rectangle {
                    id: certRow
                    Layout.fillWidth: true
                    height: 56
                    radius: 12
                    border.color: dialog.certListOpen ? dialog.accent : "#5a5a5e"
                    border.width: dialog.certListOpen ? 2 : 1
                    color: "transparent"

                    Label {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 150
                        verticalAlignment: Text.AlignVCenter
                        text: {
                            const name = nameField.text.trim() !== "" ? nameField.text.trim() : "…";
                            const org = orgField.text.trim();
                            if (dialog.certId === "new")
                                return name + (org !== "" ? " · " + org : "");
                            const cert = dialog.certs.find(c => c.id === dialog.certId);
                            return cert ? cert.name + (cert.organization !== "" && cert.organization !== cert.name ? " · " + cert.organization : "") : "…";
                        }
                        color: "white"
                        font.pixelSize: 15
                        elide: Text.ElideRight
                    }
                    Label {
                        visible: dialog.certId === "new"
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 44
                        text: "created on save"
                        color: "#8e8e93"
                        font.pixelSize: 11
                        background: Rectangle { color: "#2c2c2e"; radius: 999 }
                        leftPadding: 8
                        rightPadding: 8
                        topPadding: 2
                        bottomPadding: 2
                    }
                    Label {
                        id: certInfo
                        text: "ⓘ"
                        color: certInfoHover.hovered ? "white" : "#8e8e93"
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 10

                        HoverHandler { id: certInfoHover }
                        ToolTip.visible: certInfoHover.hovered
                        ToolTip.delay: 200
                        ToolTip.text: "This certificate cryptographically seals every copy you save, so any later change to the file is detectable. Self-signed, so it proves the file wasn't touched, not that you are you (not QES)."
                    }

                    Label {
                        x: 12
                        y: -9
                        text: "Certificate"
                        color: dialog.certListOpen ? dialog.accent : "#8e8e93"
                        font.pixelSize: 11
                        leftPadding: 4
                        rightPadding: 4
                        background: Rectangle { color: "#1c1c1e" }
                    }
                }

                Label {
                    visible: dialog.importError !== ""
                    text: dialog.importError
                    color: dialog.accent
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Label {
                    text: dialog.certListOpen ? "Close list"
                        : (dialog.certs.length === 0 ? "More options…" : "Change…")
                    color: "#b8b8bc"
                    font.pixelSize: 13
                    textFormat: Text.RichText
                    font.underline: true

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dialog.certListOpen = !dialog.certListOpen
                    }
                }

                ColumnLayout {
                    visible: dialog.certListOpen
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        // The first entry switches back to a fresh certificate.
                        model: [{id: "new", name: "Create a new certificate", organization: ""}].concat(dialog.certs)

                        delegate: Item {
                            id: certChoice

                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            height: 36

                            Rectangle {
                                anchors.fill: parent
                                radius: 7
                                color: certChoiceMouse.containsMouse ? "#3a3a3d" : "transparent"
                            }
                            Label {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                verticalAlignment: Text.AlignVCenter
                                text: certChoice.modelData.name + (certChoice.modelData.organization !== "" && certChoice.modelData.organization !== certChoice.modelData.name ? " · " + certChoice.modelData.organization : "")
                                color: certChoice.modelData.id === dialog.certId ? dialog.accent : "white"
                                font.pixelSize: 14
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                visible: certChoice.modelData.id === dialog.certId
                                text: "✓"
                                color: dialog.accent
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: certChoiceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dialog.certId = certChoice.modelData.id;
                                    dialog.certListOpen = false;
                                }
                            }
                        }
                    }

                    // Importing joins the list: pick a file, and its password
                    // is asked for only when the file turns out protected.
                    Item {
                        Layout.fillWidth: true
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: importRowMouse.containsMouse ? "#3a3a3d" : "transparent"
                        }
                        Label {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            text: "Import from a .p12 file…"
                            color: "white"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: importRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.importCertificate()
                        }
                    }
                }
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

    // The password of an imported .p12 file, asked for only when the file
    // turns out to be protected. The app never stores it.
    Rectangle {
        id: passwordDialog
        visible: false
        anchors.fill: parent
        color: "#000000b0"

        MouseArea { anchors.fill: parent }
        Keys.onEscapePressed: cancel()

        function open() {
            passwordField.text = "";
            error = "";
            visible = true;
            passwordField.forceActiveFocus();
        }
        function cancel() {
            visible = false;
            backend.cancelImport();
        }
        function accept() {
            backend.importCertificatePassword(passwordField.text);
        }

        property string error: ""

        Rectangle {
            anchors.centerIn: parent
            width: 420
            height: pwLayout.implicitHeight + 48
            radius: 14
            color: "#1c1c1e"

            ColumnLayout {
                id: pwLayout
                anchors.fill: parent
                anchors.margins: 24
                spacing: 0

                Label { text: "Certificate password"; color: "white"; font.pixelSize: 17; font.weight: Font.DemiBold }
                Label {
                    Layout.topMargin: 4
                    Layout.bottomMargin: 18
                    text: "The certificate file is protected. Its password is asked once for the import and never stored."
                    color: "#b8b8bc"
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    onAccepted: passwordDialog.accept()
                    Keys.onEscapePressed: passwordDialog.cancel()
                }

                Label {
                    Layout.topMargin: 8
                    visible: passwordDialog.error !== ""
                    text: passwordDialog.error
                    color: dialog.accent
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.topMargin: 20
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    BarButton {
                        text: "Cancel"
                        accent: dialog.accent
                        onClicked: passwordDialog.cancel()
                    }
                    BarButton {
                        text: "Import"
                        primary: true
                        accent: dialog.accent
                        accentForeground: dialog.accentForeground
                        onClicked: passwordDialog.accept()
                    }
                }
            }
        }
    }

    Connections {
        target: backend
        function onCertificateImportNeedsPassword() { passwordDialog.open(); }
        function onCertificateImportFailed(message) { dialog.importError = message; }
        function onCertificateImported(nickname) { dialog.refreshCerts(nickname); }
    }
}
