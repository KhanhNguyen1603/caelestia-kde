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
    // kscreenlocker keeps a prompt open until it is answered and leaves prompt/promptForSecret
    // set after the conversation ends, so track whether a live prompt is waiting.
    property bool promptPending: false
    // PamAuthenticators::AuthenticatorsState values (Idle = 0, Authenticating = 1).
    // Plasma <= 6.6 does not register PamAuthenticators as a QML type, so avoid its QML enum namespace.
    readonly property int idleState: 0
    readonly property int authenticatingState: 1

    readonly property bool busy: Boolean(activeAuthenticator && (activeAuthenticator.busy || activeAuthenticator.pamTimeout || activeAuthenticator.inPasswordDelay))
    readonly property bool pamTimeout: Boolean(activeAuthenticator && (activeAuthenticator.pamTimeout || activeAuthenticator.inPasswordDelay))
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

    onActiveAuthenticatorChanged: root.promptPending = root.hasOpenPrompt(activeAuthenticator)
    Component.onCompleted: root.promptPending = root.hasOpenPrompt(activeAuthenticator)

    function isAuthenticatingState(auth) {
        return Boolean(auth) && (typeof auth.state === "undefined" || auth.state === root.authenticatingState);
    }

    function hasOpenPrompt(auth) {
        if (!auth || auth.unlocked || auth.busy || auth.pamTimeout || auth.inPasswordDelay) return false;
        if (!root.isAuthenticatingState(auth)) return false;
        return Boolean(auth.promptForSecret || auth.prompt);
    }

    function flushPendingPassword() {
        if (!activeAuthenticator || root.pamTimeout || !root.promptPending || !root.isAuthenticatingState(activeAuthenticator) || root.pendingPassword.length === 0) return;
        root.promptPending = false;
        if (typeof activeAuthenticator.respond === "function") {
            activeAuthenticator.respond(root.pendingPassword);
        }
        root.pendingPassword = "";
        root.focusSecretRequested();
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
        if (!filteredMsg || filteredMsg.trim().length === 0) return;

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
            !root.promptPending &&
            !activeAuthenticator.busy &&
            !root.pamTimeout &&
            typeof activeAuthenticator.startAuthenticating === "function") {
            activeAuthenticator.startAuthenticating();
        }
    }

    function respond(pass) {
        if (!pass || pass.length === 0) return;
        root.clearAuthMessage();
        if (!activeAuthenticator) return;
        if (activeAuthenticator.pamTimeout || activeAuthenticator.inPasswordDelay) {
            root.pendingPassword = pass;
            return;
        }
        if (root.promptPending && root.isAuthenticatingState(activeAuthenticator) && typeof activeAuthenticator.respond === "function") {
            root.promptPending = false;
            root.pendingPassword = "";
            activeAuthenticator.respond(pass);
            return;
        }
        root.pendingPassword = pass;
        if (!activeAuthenticator.busy && typeof activeAuthenticator.startAuthenticating === "function") {
            activeAuthenticator.startAuthenticating();
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
                !root.promptPending &&
                !activeAuthenticator.busy &&
                !root.pamTimeout &&
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
            root.promptPending = false;
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
            root.promptPending = false;
            root.lockoutSecondsRemaining = 0;
            root.fprintTries = 0;

            if (activeAuthenticator && typeof activeAuthenticator.stopAuthenticating === "function") {
                activeAuthenticator.stopAuthenticating();
            }
            root.succeeded();
            Qt.quit();
        }

        function onStateChanged() {
            if (activeAuthenticator && activeAuthenticator.state === root.idleState) {
                root.promptPending = false;
            }
        }

        function onPamTimeoutChanged() {
            root.flushPendingPassword();
        }

        function onInPasswordDelayChanged() {
            root.flushPendingPassword();
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
            root.promptPending = Boolean(activeAuthenticator && activeAuthenticator.prompt) && root.isAuthenticatingState(activeAuthenticator);
            if (activeAuthenticator && activeAuthenticator.prompt) {
                root.handleMessage(activeAuthenticator.prompt);
            }
            if (root.promptPending && root.pendingPassword.length > 0) {
                // Defer past PamAuthenticator::promptInternal(), which records m_pendingPrompt after emitting this signal.
                Qt.callLater(root.flushPendingPassword);
            }
        }

        function onPromptForSecretChanged() {
            root.promptPending = Boolean(activeAuthenticator && activeAuthenticator.promptForSecret) && root.isAuthenticatingState(activeAuthenticator);
            root.focusSecretRequested();
            var show = root.showPrompt || Boolean(activeAuthenticator && activeAuthenticator.showPrompt);
            if (show && activeAuthenticator && activeAuthenticator.promptForSecret) {
                root.handleMessage(activeAuthenticator.promptForSecret);
            }
            if (root.promptPending && root.pendingPassword.length > 0) {
                // Defer past PamAuthenticator::promptInternal(), which records m_pendingPrompt after emitting this signal.
                Qt.callLater(root.flushPendingPassword);
            }
        }
    }
}
