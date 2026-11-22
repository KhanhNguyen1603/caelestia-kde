import QtQuick
import org.kde.kscreenlocker as ScreenLocker

Item {
    id: root

    property var authenticatorTarget: {
        try {
            return authenticator;
        } catch (e) {
            return null;
        }
    }
    readonly property var activeAuthenticator: authenticatorTarget

    property string authMessage: ""
    property string pendingPassword: ""
    property bool viewVisible: true
    property bool showPrompt: false
    property bool expectingPrompt: false

    readonly property bool busy: Boolean(activeAuthenticator && (activeAuthenticator.busy || activeAuthenticator.pamTimeout))
    readonly property bool pamTimeout: Boolean(activeAuthenticator && activeAuthenticator.pamTimeout)
    readonly property bool unlocked: Boolean(activeAuthenticator && activeAuthenticator.unlocked)
    readonly property bool isAuthenticating: pamTimeout
    readonly property bool graceLocked: pamTimeout

    property int lockoutSecondsRemaining: 0
    readonly property int lockoutMinutesRemaining: Math.ceil(lockoutSecondsRemaining / 60)
    readonly property bool lockoutActive: lockoutSecondsRemaining > 0
    readonly property string lockoutText: lockoutMinutesRemaining > 0 ? qsTr("%1 min left").arg(lockoutMinutesRemaining) : ""

    property int fprintTries: 0
    property int maxFprintTries: 3
    property int notificationDismissInterval: 3000

    signal messageChanged(string message)
    signal shakeRequested()
    signal focusSecretRequested()
    signal clearPasswordRequested()
    signal notificationRepeated()
    signal succeeded()

    function isExactFailMsg(msg) {
        if (!msg) return false;
        var trimmed = (typeof msg === "string") ? msg.trim() : "";
        var lower = trimmed.toLowerCase();
        var localized = i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed").trim();
        return lower === "unlocking failed" ||
               lower === "unlocking failed." ||
               trimmed === localized ||
               trimmed === (localized + ".");
    }

    function extractTimeInSeconds(text) {
        if (!text || typeof text !== "string") return -1;
        var hrMatch = text.match(/\b(\d+)\s*(?:hours?|hrs?|hr)\b/i);
        var minMatch = text.match(/\b(\d+)\s*(?:minutes?|mins?|min)\b/i);
        var secMatch = text.match(/\b(\d+)\s*(?:seconds?|secs?|sec)\b/i);

        var totalSec = 0;
        var found = false;

        if (hrMatch) { totalSec += parseInt(hrMatch[1], 10) * 3600; found = true; }
        if (minMatch) { totalSec += parseInt(minMatch[1], 10) * 60; found = true; }
        if (secMatch) { totalSec += parseInt(secMatch[1], 10); found = true; }

        return found ? totalSec : -1;
    }

    function stripTimeLines(text) {
        if (!text || typeof text !== "string") return "";
        var lines = text.split("\n");
        var kept = [];
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;
            if (extractTimeInSeconds(line) > 0) {
                continue;
            }
            if (isExactFailMsg(line)) {
                continue;
            }
            kept.push(line);
        }
        return kept.join("\n");
    }

    function handleMessage(msg) {
        if (!msg || (typeof msg === "string" && msg.trim().length === 0)) return;

        var extractedSec = extractTimeInSeconds(msg);
        if (extractedSec > 0) {
            root.lockoutSecondsRemaining = extractedSec;
            lockoutCountdownTimer.restart();
        }

        var filteredMsg = stripTimeLines(msg);
        if (!filteredMsg || filteredMsg.trim().length === 0 || isExactFailMsg(filteredMsg)) return;

        var lower = (typeof filteredMsg === "string") ? filteredMsg.trim().toLowerCase() : "";
        if (lower === "password:" || lower === "password" || lower === "passwd:" || lower === "passwd") return;

        if (typeof parent !== "undefined" && typeof parent.notification !== "undefined") {
            if (!parent.notification) {
                parent.notification += filteredMsg;
            } else if (parent.notification.includes(filteredMsg)) {
                root.notificationRepeated();
            } else {
                parent.notification += "\n" + filteredMsg;
            }
            root.authMessage = parent.notification;
        } else {
            if (!root.authMessage) {
                root.authMessage = filteredMsg;
            } else if (!root.authMessage.includes(filteredMsg)) {
                root.authMessage += "\n" + filteredMsg;
            } else {
                root.notificationRepeated();
            }
        }

        notificationRemoveTimer.restart();
        root.messageChanged(root.authMessage);
    }

    function clearAuthMessage() {
        root.authMessage = "";
        if (typeof parent !== "undefined" && typeof parent.notification !== "undefined") {
            parent.notification = "";
        }
        if (typeof root !== "undefined" && typeof root.notification !== "undefined") {
            root.notification = "";
        }
        notificationRemoveTimer.stop();
        root.messageChanged("");
    }

    function ensureAuthenticating() {
        if (!root.viewVisible || (activeAuthenticator && activeAuthenticator.unlocked)) return;
        if (activeAuthenticator &&
            !activeAuthenticator.promptForSecret &&
            !activeAuthenticator.busy &&
            !activeAuthenticator.pamTimeout &&
            typeof activeAuthenticator.startAuthenticating === "function") {
            activeAuthenticator.startAuthenticating();
        }
    }

    function respond(pass) {
        if (!pass || pass.length === 0) return;
        root.clearAuthMessage();
        if (activeAuthenticator && activeAuthenticator.pamTimeout) {
            root.pendingPassword = pass;
        } else if (activeAuthenticator && typeof activeAuthenticator.respond === "function") {
            activeAuthenticator.respond(pass);
        }
    }

    function startLogin(pass) {
        root.respond(pass);
    }

    // Heart beat keeping the backend active for as long as we are in visible state
    // Exact 1:1 match with upstream LockScreenUi.qml:170-175
    Timer {
        id: backendHeartbeatTimer
        interval: 1000
        repeat: true
        running: root.viewVisible && Boolean(activeAuthenticator) && !(activeAuthenticator && activeAuthenticator.unlocked)
        onTriggered: {
            if (activeAuthenticator &&
                !activeAuthenticator.promptForSecret &&
                !activeAuthenticator.busy &&
                !activeAuthenticator.pamTimeout &&
                typeof activeAuthenticator.startAuthenticating === "function") {
                activeAuthenticator.startAuthenticating();
            }
        }
    }

    Timer {
        id: notificationRemoveTimer
        interval: root.notificationDismissInterval
        onTriggered: {
            root.clearAuthMessage();
        }
    }

    Timer {
        id: lockoutCountdownTimer
        interval: 1000
        repeat: true
        running: root.lockoutSecondsRemaining > 0
        onTriggered: {
            if (root.lockoutSecondsRemaining > 0) {
                root.lockoutSecondsRemaining--;
            }
        }
    }

    Connections {
        target: activeAuthenticator
        ignoreUnknownSignals: true

        function onFailed(kind, auth) {
            // Only interactive (password) failure resets the conversation; non-interactive errors are handled separately
            if (kind !== 0) {
                if (kind & ScreenLocker.Authenticator.Fingerprint) {
                    root.fprintTries++;
                    if (root.fprintTries >= root.maxFprintTries) {
                        root.handleMessage(i18ndc("plasma_shell_org.kde.plasma.desktop",
                            "@info:status", "Maximum fingerprint attempts reached. Please use password."));
                    }
                }
                return;
            }

            root.pendingPassword = "";
            var authErr = (auth && auth.errorMessage) ? auth.errorMessage :
                          (activeAuthenticator && activeAuthenticator.errorMessage ? activeAuthenticator.errorMessage :
                          (activeAuthenticator && activeAuthenticator.infoMessage ? activeAuthenticator.infoMessage : ""));
            const msg = authErr || i18ndc("plasma_shell_org.kde.plasma.desktop", "@info:status", "Unlocking failed");
            root.handleMessage(msg);
            root.clearPasswordRequested();

            if (activeAuthenticator && typeof activeAuthenticator.startAuthenticating === "function") {
                activeAuthenticator.startAuthenticating();
            }
            root.shakeRequested();
        }

        function onNoninteractiveError(kind, auth) {
            if (kind & ScreenLocker.Authenticator.Fingerprint) {
                root.fprintTries++;
                if (root.fprintTries >= root.maxFprintTries) {
                    root.pendingPassword = "";
                    root.handleMessage(i18ndc("plasma_shell_org.kde.plasma.desktop",
                        "@info:status", "Maximum fingerprint attempts reached. Please use password."));
                } else if (auth && auth.errorMessage) {
                    root.handleMessage(auth.errorMessage);
                }
            }
        }

        function onSucceeded() {
            backendHeartbeatTimer.stop();
            lockoutCountdownTimer.stop();
            root.pendingPassword = "";
            root.lockoutSecondsRemaining = 0;
            root.fprintTries = 0;

            if (activeAuthenticator && typeof activeAuthenticator.stopAuthenticating === "function") {
                activeAuthenticator.stopAuthenticating();
            }
            root.succeeded();
            Qt.quit();
        }

        function onPamTimeoutChanged() {
            if (activeAuthenticator && !activeAuthenticator.pamTimeout && root.pendingPassword.length > 0) {
                if (typeof activeAuthenticator.respond === "function") {
                    activeAuthenticator.respond(root.pendingPassword);
                }
                root.pendingPassword = "";
                root.focusSecretRequested();
            }
        }

        function onInfoMessageChanged() {
            if (activeAuthenticator && activeAuthenticator.infoMessage) {
                root.handleMessage(activeAuthenticator.infoMessage);
            }
        }

        function onErrorMessageChanged() {
            if (activeAuthenticator && activeAuthenticator.errorMessage) {
                root.handleMessage(activeAuthenticator.errorMessage);
            }
        }

        function onPromptChanged() {
            if (activeAuthenticator && activeAuthenticator.prompt) {
                root.handleMessage(activeAuthenticator.prompt);
            }
        }

        function onPromptForSecretChanged() {
            root.focusSecretRequested();
            var show = root.showPrompt || Boolean(activeAuthenticator && activeAuthenticator.showPrompt);
            if (show && activeAuthenticator && activeAuthenticator.promptForSecret) {
                root.handleMessage(activeAuthenticator.promptForSecret);
            }
        }
    }
}
