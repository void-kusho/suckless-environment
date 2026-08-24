import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

/*
 * Tokyo Night — SDDM Login Theme
 * Minimal, suckless-inspired login screen
 *
 * Colors:
 *   Background:    #1a1b26
 *   Foreground:    #a9b1d6
 *   Selection:     #7aa2f7
 *   Border:        #414868
 *   Red (error):   #f7768e
 *   Bright white:  #c0caf5
 */

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1b26"

    // Layout
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: 320

        // User avatar
        Image {
            id: avatar
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            source: sddm.currentUser.iconUrl || ""
            fillMode: Image.PreserveAspectCrop
            visible: source != ""

            layer.enabled: true
            layer.effect: Item {
                // Circular avatar mask would go here
            }
        }

        // Fallback avatar (circle with initial)
        Rectangle {
            id: avatarFallback
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            radius: 40
            color: "#414868"
            visible: avatar.source == ""

            Text {
                anchors.centerIn: parent
                text: sddm.currentUser.name ? sddm.currentUser.name.charAt(0).toUpperCase() : "?"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 32
                font.weight: Font.Bold
                color: "#7aa2f7"
            }
        }

        // Username
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: sddm.currentUser.name || ""
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 18
            font.weight: Font.Medium
            color: "#c0caf5"
        }

        // Spacer
        Item { Layout.preferredHeight: 8 }

        // Password input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 6
            color: "#24283b"
            border.color: passwordInput.activeFocus ? "#7aa2f7" : "#414868"
            border.width: passwordInput.activeFocus ? 2 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                // Lock icon
                Text {
                    text: "\uf023"  // FontAwesome lock icon (Nerd Font)
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 14
                    color: "#565f89"
                }

                TextInput {
                    id: passwordInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    echoMode: TextInput.Password
                    color: "#a9b1d6"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 14
                    clip: true
                    focus: true
                    selectByMouse: true
                    selectionColor: "#7aa2f7"

                    Keys.onReturnPressed: loginButton.clicked()
                    Keys.onEnterPressed: loginButton.clicked()

                    // Placeholder
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 14
                        color: "#565f89"
                        visible: !passwordInput.text && !passwordInput.activeFocus
                    }
                }
            }
        }

        // Error message
        Text {
            id: errorText
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 12
            color: "#f7768e"
            wrapMode: Text.WordWrap
            text: sddm.lastError || ""
            visible: text != ""
        }

        // Login button
        Rectangle {
            id: loginButton
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 6
            color: loginMouseArea.containsPress ? "#89b4fa" : "#7aa2f7"

            property alias clicked: loginMouseArea.clicked

            Text {
                anchors.centerIn: parent
                text: "Login"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 14
                font.weight: Font.Medium
                color: "#1a1b26"
            }

            MouseArea {
                id: loginMouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    errorText.text = ""
                    sddm.login(sddm.currentUser.name, passwordInput.text, sddm.lastSession)
                }
            }

            Connections {
                target: sddm
                function onLoginFailed() {
                    errorText.text = sddm.lastError
                    passwordInput.text = ""
                    passwordInput.forceActiveFocus()
                }
                function onLoginSucceeded() {
                    // Session manager will handle the transition
                }
            }
        }

        // Session selector
        ComboBox {
            id: sessionCombo
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            model: sddm.sessions
            textRole: "display"
            currentIndex: sddm.lastSessionIndex >= 0 ? sddm.lastSessionIndex : 0

            background: Rectangle {
                radius: 4
                color: "#24283b"
                border.color: sessionCombo.activeFocus ? "#7aa2f7" : "#414868"
                border.width: sessionCombo.activeFocus ? 2 : 1
            }

            contentItem: Text {
                leftPadding: 12
                text: sessionCombo.displayText
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 12
                color: "#a9b1d6"
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Bottom row: layout switcher + power buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Layout label
            Text {
                text: sddm.layoutName || ""
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 12
                color: "#565f89"
                visible: text != ""
            }

            Item { Layout.fillWidth: true }

            // Suspend button
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 4
                color: suspendMouse.containsPress ? "#414868" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf186"  // FontAwesome moon/sleep icon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 14
                    color: "#565f89"
                }

                MouseArea {
                    id: suspendMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.suspend()
                }
            }

            // Reboot button
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 4
                color: rebootMouse.containsPress ? "#414868" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf021"  // FontAwesome refresh icon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 14
                    color: "#565f89"
                }

                MouseArea {
                    id: rebootMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.reboot()
                }
            }

            // Shutdown button
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 4
                color: shutdownMouse.containsPress ? "#f7768e" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf011"  // FontAwesome power icon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 14
                    color: shutdownMouse.containsPress ? "#1a1b26" : "#f7768e"
                }

                MouseArea {
                    id: shutdownMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.powerOff()
                }
            }
        }
    }

    // Keyboard focus on click anywhere
    MouseArea {
        anchors.fill: parent
        onClicked: passwordInput.forceActiveFocus()
    }

    // Auto-focus password field
    Component.onCompleted: passwordInput.forceActiveFocus()
}
