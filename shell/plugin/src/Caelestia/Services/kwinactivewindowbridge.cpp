#include "kwinactivewindowbridge.hpp"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QGuiApplication>
#include <QScreen>
#include <QTimer>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusMessage>

#include "kwinworkspacestate.hpp"
#include "plasmawindows.hpp"

namespace caelestia::services {

namespace {

// The shell's own panels and popups never cover an app. Its normal windows,
// such as Nexus, do.
bool isShellSurface(const PlasmaWindowHandle* window) {
    static const QStringList shellAppIds = { QStringLiteral("quickshell"), QStringLiteral("org.quickshell"),
        QStringLiteral("plasmashell"), QStringLiteral("org.kde.plasmashell") };
    return window->skipTaskbar() && !window->isFullscreen() && shellAppIds.contains(window->appId());
}

} // namespace

KWinActiveWindowBridge::KWinActiveWindowBridge(QObject* parent)
    : QObject(parent) {

    m_updateTimer.setSingleShot(true);
    m_updateTimer.setInterval(50);
    connect(&m_updateTimer, &QTimer::timeout, this, &KWinActiveWindowBridge::buildWindowList);

    // Zero, so the result follows each batch of KWin events rather than each event.
    m_fullscreenTimer.setSingleShot(true);
    m_fullscreenTimer.setInterval(0);
    connect(&m_fullscreenTimer, &QTimer::timeout, this, &KWinActiveWindowBridge::updateFullscreenOutputs);

    auto* plasmaWindows = PlasmaWindows::instance();
    connect(plasmaWindows, &PlasmaWindows::windowAdded, this, &KWinActiveWindowBridge::onWindowAdded);
    connect(plasmaWindows, &PlasmaWindows::handleLost, this, &KWinActiveWindowBridge::onWindowLost);
    connect(
        plasmaWindows, &PlasmaWindows::stackingOrderChanged, this, &KWinActiveWindowBridge::scheduleFullscreenUpdate);
    // Adding or removing a screen can change which output a window is on.
    connect(qGuiApp, &QGuiApplication::screenAdded, this, &KWinActiveWindowBridge::scheduleFullscreenUpdate);
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, &KWinActiveWindowBridge::scheduleFullscreenUpdate);
    // After a reload, the shared PlasmaWindows still holds handles that no new
    // windowAdded will announce.
    for (const QString& uuid : plasmaWindows->windowUuids())
        onWindowAdded(uuid);

    // Clear any stale highlight from a previous session or crash on startup
    clearHighlight();
}

KWinActiveWindowBridge::~KWinActiveWindowBridge() {
    clearHighlight();
}

KWinActiveWindowBridge* KWinActiveWindowBridge::create(QQmlEngine* engine, QJSEngine*) {
    auto* bridge = new KWinActiveWindowBridge;
    // Whether a window is visible depends on the desktop its output shows, which
    // only the workspace state tracks. Asking the engine for it creates it on
    // demand; KWinWorkspaceState::instance() returns null until something else
    // has asked for it.
    auto* state = engine->singletonInstance<KWinWorkspaceState*>("Caelestia.Services", "KWinWorkspaceState");
    if (state) {
        bridge->m_workspaceState = state;
        for (const auto signal : { &KWinWorkspaceState::activeIdChanged, &KWinWorkspaceState::activeByOutputChanged,
                 &KWinWorkspaceState::workspacesChanged, &KWinWorkspaceState::showingDesktopChanged,
                 &KWinWorkspaceState::currentActivityChanged }) {
            connect(state, signal, bridge, &KWinActiveWindowBridge::scheduleFullscreenUpdate);
        }
    }
    return bridge;
}

QVariantMap KWinActiveWindowBridge::activeWindow() const {
    return m_activeWindow;
}

QVariantMap KWinActiveWindowBridge::lastActiveWindow() const {
    return m_lastActiveWindow;
}

QString KWinActiveWindowBridge::activeOutputName() const {
    return m_activeOutputName;
}

QString KWinActiveWindowBridge::highlightedAddress() const {
    return m_highlightedAddress;
}

void KWinActiveWindowBridge::setActiveOutputName(const QString& outputName) {
    if (m_activeOutputName != outputName) {
        m_activeOutputName = outputName;
        emit activeOutputNameChanged();
    }
}

QVariantList KWinActiveWindowBridge::windowList() const {
    return m_windowList;
}

QStringList KWinActiveWindowBridge::fullscreenOutputs() const {
    return m_fullscreenOutputs;
}

QVariantList KWinActiveWindowBridge::windowsForWorkspace(const QVariant& workspace, bool includeOnAllWorkspaces) const {
    bool isInt = false;
    const int targetId = workspace.toInt(&isInt);
    const bool hasNumberTarget = isInt && targetId > 0;
    const QString targetUuid = workspace.toString();
    const bool hasStringTarget = !hasNumberTarget && !targetUuid.isEmpty();

    auto* wsState = KWinWorkspaceState::instance();

    QVariantList out;
    for (const QVariant& v : m_windowList) {
        const QVariantMap window = v.toMap();
        const QVariantMap ws = window.value(QStringLiteral("workspace")).toMap();
        if (ws.isEmpty()) {
            out.push_back(v);
            continue;
        }
        int id = ws.value(QStringLiteral("id")).toInt();
        const QString uuid = ws.value(QStringLiteral("uuid")).toString();

        if (id <= 0 && !uuid.isEmpty() && wsState) {
            const int resolved = wsState->indexForId(uuid);
            if (resolved > 0) {
                id = resolved;
            }
        }

        const bool onAll = (id == -1 || id == 0) && uuid.isEmpty();
        if (onAll) {
            if (includeOnAllWorkspaces)
                out.push_back(v);
            continue;
        }
        if (!hasNumberTarget && !hasStringTarget) {
            out.push_back(v);
            continue;
        }
        if (hasNumberTarget) {
            if (id > 0 && id == targetId) {
                out.push_back(v);
                continue;
            }
            if (!uuid.isEmpty() && wsState && uuid == wsState->uuidForIndex(targetId)) {
                out.push_back(v);
                continue;
            }
        }
        if (hasStringTarget) {
            if (!uuid.isEmpty() && uuid == targetUuid) {
                out.push_back(v);
                continue;
            }
            if (id > 0 && wsState && wsState->uuidForIndex(id) == targetUuid) {
                out.push_back(v);
                continue;
            }
        }
    }
    return out;
}

QString KWinActiveWindowBridge::pendingFocusAddress() const {
    return m_pendingFocusAddress;
}

QString KWinActiveWindowBridge::cursorOutputName() const {
    const auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"), QStringLiteral("activeOutputName"));
    return QDBusConnection::sessionBus().call(message).arguments().value(0).toString();
}

void KWinActiveWindowBridge::onWindowAdded(const QString& uuid) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(uuid)) {
        connect(handle, &PlasmaWindowHandle::titleChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        connect(handle, &PlasmaWindowHandle::appIdChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        connect(handle, &PlasmaWindowHandle::geometryChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        connect(handle, &PlasmaWindowHandle::stateChanged, this, [this, handle]() {
            onStateChanged(handle);
        });
        connect(handle, &PlasmaWindowHandle::desktopsChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        connect(handle, &PlasmaWindowHandle::appMenuChanged, this, &KWinActiveWindowBridge::scheduleWindowListUpdate);
        for (const auto signal : { &PlasmaWindowHandle::appIdChanged, &PlasmaWindowHandle::geometryChanged,
                 &PlasmaWindowHandle::stateChanged, &PlasmaWindowHandle::desktopsChanged,
                 &PlasmaWindowHandle::activitiesChanged }) {
            connect(handle, signal, this, &KWinActiveWindowBridge::scheduleFullscreenUpdate);
        }
        scheduleWindowListUpdate();
        scheduleFullscreenUpdate();
    }
}

void KWinActiveWindowBridge::onWindowLost(const QString& uuid) {
    if (!m_highlightedAddress.isEmpty() && m_highlightedAddress == uuid) {
        clearHighlight();
    }
    if (m_lastActiveWindow.value(QStringLiteral("address")).toString() == uuid) {
        m_lastActiveWindow.clear();
        emit lastActiveWindowChanged();
    }
    scheduleWindowListUpdate();
    scheduleFullscreenUpdate();
}

void KWinActiveWindowBridge::onStateChanged(PlasmaWindowHandle* handle) {
    const QString uuid = handle->uuid();
    const bool isNowActive = handle->isActive();
    const bool wasActive = m_activeWindow.value(QStringLiteral("address")).toString() == uuid;

    if (isNowActive && !wasActive) {
        const QString oldUuid = m_activeWindow.value(QStringLiteral("address")).toString();
        if (!oldUuid.isEmpty()) {
            const int oldIdx = m_windowIndex.value(oldUuid, -1);
            if (oldIdx >= 0 && oldIdx < m_windowList.size()) {
                QVariantMap map = m_windowList[oldIdx].toMap();
                map[QStringLiteral("focused")] = false;
                map[QStringLiteral("floating")] = !map.value(QStringLiteral("fullscreen")).toBool() &&
                                                  !map.value(QStringLiteral("maximized")).toBool();
                m_windowList[oldIdx] = map;
                m_windowCache[oldUuid] = map;
            }
        }
        QVariantMap w = windowToVariant(handle);
        const int newIdx = m_windowIndex.value(uuid, -1);
        if (newIdx >= 0 && newIdx < m_windowList.size()) {
            QVariantMap map = m_windowList[newIdx].toMap();
            map[QStringLiteral("focused")] = true;
            m_windowList[newIdx] = map;
            m_windowCache[uuid] = map;
            w = map;
        }
        emit windowListChanged();
        if (m_activeWindow != w) {
            m_activeWindow = w;
            emit activeWindowChanged();
            const QString newOutput = w.value(QStringLiteral("output")).toString();
            if (!newOutput.isEmpty())
                setActiveOutputName(newOutput);
            if (m_activeWindow.value(QStringLiteral("address")).toString() == m_pendingFocusAddress) {
                m_pendingFocusAddress.clear();
                emit pendingFocusAddressChanged();
            }
        }
        if (m_lastActiveWindow != w) {
            m_lastActiveWindow = w;
            emit lastActiveWindowChanged();
        }
        return;
    }

    if (!isNowActive && wasActive) {
        const int idx = m_windowIndex.value(uuid, -1);
        if (idx >= 0 && idx < m_windowList.size()) {
            QVariantMap map = m_windowList[idx].toMap();
            map[QStringLiteral("focused")] = false;
            m_windowList[idx] = map;
            m_windowCache[uuid] = map;
        }
        m_activeWindow.clear();
        emit windowListChanged();
        emit activeWindowChanged();
        return;
    }

    scheduleWindowListUpdate();
}

void KWinActiveWindowBridge::scheduleWindowListUpdate() {
    if (!m_updateTimer.isActive()) {
        m_updateTimer.start();
    }
}

void KWinActiveWindowBridge::scheduleFullscreenUpdate() {
    m_fullscreenTimer.start();
}

void KWinActiveWindowBridge::updateFullscreenOutputs() {
    if (!m_workspaceState)
        return;
    QStringList outputs;
    if (!m_workspaceState->showingDesktop()) {
        const QString activity = m_workspaceState->currentActivity();
        const QVariantMap desktopByOutput = m_workspaceState->activeByOutput();
        const int currentDesktop = qMax(m_workspaceState->activeId(), 1);

        auto* plasmaWindows = PlasmaWindows::instance();
        // The stack starts at the bottom, so each visible window replaces the one below it on its output.
        for (const QString& uuid : plasmaWindows->stackingOrder()) {
            const auto* window = plasmaWindows->existingHandle(uuid);
            if (!window || !window->hasInitialState() || window->isMinimized() || isShellSurface(window))
                continue;
            const QStringList activities = window->activities();
            if (!activity.isEmpty() && !activities.isEmpty() && !activities.contains(activity))
                continue;
            const QString output =
                getOutputNameForGeometry(window->x(), window->y(), window->width(), window->height());
            if (output.isEmpty())
                continue;
            // Empty means every desktop. Only filter once we know which desktop the
            // output shows, so a workspace list that has not arrived hides nothing.
            const QStringList desktops = desktopUuids(window);
            if (!desktops.isEmpty()) {
                const int perOutput = desktopByOutput.value(output).toInt();
                const int desktop = perOutput > 0 ? perOutput : currentDesktop;
                const QString desktopUuid = m_workspaceState->uuidForIndex(desktop);
                if (!desktopUuid.isEmpty() && !desktops.contains(desktopUuid))
                    continue;
            }
            outputs.removeOne(output);
            if (window->isFullscreen())
                outputs.append(output);
        }
        outputs.sort();
    }

    if (outputs != m_fullscreenOutputs) {
        m_fullscreenOutputs = outputs;
        emit fullscreenOutputsChanged();
    }
}

QStringList KWinActiveWindowBridge::desktopUuids(const PlasmaWindowHandle* window) const {
    QStringList uuids;
    for (const QString& id : window->desktops()) {
        bool isNumber = false;
        const int index = id.toInt(&isNumber);
        if (isNumber && m_workspaceState) {
            const QString uuid = m_workspaceState->uuidForIndex(index);
            uuids.append(uuid.isEmpty() ? id : uuid);
        } else {
            uuids.append(id);
        }
    }
    return uuids;
}

void KWinActiveWindowBridge::rebuildIndex() {
    m_windowIndex.clear();
    m_windowIndex.reserve(m_windowList.size());
    for (int i = 0; i < m_windowList.size(); ++i) {
        const QString addr = m_windowList[i].toMap().value(QStringLiteral("address")).toString();
        if (!addr.isEmpty())
            m_windowIndex.insert(addr, i);
    }
}

void KWinActiveWindowBridge::sendToOutput(const QString& address, const QString& outputName) {
    if (address.isEmpty() || outputName.isEmpty()) {
        return;
    }

    QScreen* target = nullptr;
    for (QScreen* screen : QGuiApplication::screens()) {
        if (screen->name() == outputName) {
            target = screen;
            break;
        }
    }
    if (!target) {
        return;
    }

    QVariantMap window;
    const int idx = m_windowIndex.value(address, -1);
    if (idx >= 0 && idx < m_windowList.size())
        window = m_windowList[idx].toMap();
    if (window.isEmpty()) {
        return;
    }

    const QString currentName = window.value(QStringLiteral("output")).toString();
    QScreen* current = nullptr;
    for (QScreen* screen : QGuiApplication::screens()) {
        if (screen->name() == currentName) {
            current = screen;
            break;
        }
    }
    if (!current || current == target) {
        return;
    }

    const QPoint from = current->geometry().center();
    const QPoint to = target->geometry().center();
    QString action;
    if (qAbs(to.x() - from.x()) >= qAbs(to.y() - from.y())) {
        action = to.x() > from.x() ? QStringLiteral("Window One Screen to the Right")
                                   : QStringLiteral("Window One Screen to the Left");
    } else {
        action = to.y() > from.y() ? QStringLiteral("Window One Screen Down") : QStringLiteral("Window One Screen Up");
    }

    focusWindow(address);

    QTimer::singleShot(120, this, [action]() {
        QDBusMessage msg =
            QDBusMessage::createMethodCall(QStringLiteral("org.kde.kglobalaccel"), QStringLiteral("/component/kwin"),
                QStringLiteral("org.kde.kglobalaccel.Component"), QStringLiteral("invokeShortcut"));
        msg << action;
        QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
    });
}

QString KWinActiveWindowBridge::getOutputNameForGeometry(int x, int y, int w, int h) const {
    const QRect windowRect(x, y, w, h);

    QScreen* bestScreen = nullptr;
    int maxIntersectArea = 0;

    for (QScreen* screen : QGuiApplication::screens()) {
        const QRect intersect = screen->geometry().intersected(windowRect);
        const int area = intersect.width() * intersect.height();
        if (area > maxIntersectArea) {
            maxIntersectArea = area;
            bestScreen = screen;
        }
    }

    if (!bestScreen) {
        qreal bestDistance = -1;
        const QPoint windowCentre = windowRect.center();
        for (QScreen* screen : QGuiApplication::screens()) {
            const QPoint delta = screen->geometry().center() - windowCentre;
            const qreal distance =
                static_cast<qreal>(delta.x()) * delta.x() + static_cast<qreal>(delta.y()) * delta.y();
            if (bestDistance < 0 || distance < bestDistance) {
                bestDistance = distance;
                bestScreen = screen;
            }
        }
    }

    return bestScreen ? bestScreen->name() : QString();
}

QVariantMap KWinActiveWindowBridge::windowToVariant(PlasmaWindowHandle* w) const {
    QVariant desktopId = -1;
    QVariant desktopUuid = QString();
    if (!w->desktops().isEmpty()) {
        QString firstDesktop = w->desktops().first();
        bool ok;
        int parsed = firstDesktop.toInt(&ok);
        if (ok) {
            desktopId = parsed;
            if (auto wsState = KWinWorkspaceState::instance()) {
                QString resolvedUuid = wsState->uuidForIndex(parsed);
                desktopUuid = resolvedUuid.isEmpty() ? firstDesktop : resolvedUuid;
            } else {
                desktopUuid = firstDesktop;
            }
        } else {
            desktopUuid = firstDesktop;
            if (auto wsState = KWinWorkspaceState::instance()) {
                int idx = wsState->indexForId(firstDesktop);
                if (idx != -1)
                    desktopId = idx;
            }
        }
    }

    QVariantMap map = { { QStringLiteral("address"), w->uuid() }, { QStringLiteral("pid"), w->pid() },
        { QStringLiteral("title"), w->title() }, { QStringLiteral("class"), w->appId() },
        { QStringLiteral("x"), w->x() }, { QStringLiteral("y"), w->y() }, { QStringLiteral("width"), w->width() },
        { QStringLiteral("height"), w->height() }, { QStringLiteral("fullscreen"), w->isFullscreen() },
        { QStringLiteral("maximized"), w->isMaximized() }, { QStringLiteral("minimized"), w->isMinimized() },
        { QStringLiteral("focused"), w->isActive() },
        { QStringLiteral("floating"), !w->isFullscreen() && !w->isMaximized() },
        { QStringLiteral("output"), getOutputNameForGeometry(w->x(), w->y(), w->width(), w->height()) },
        { QStringLiteral("menuService"), w->menuServiceName() }, { QStringLiteral("menuObject"), w->menuObjectPath() },
        { QStringLiteral("workspace"),
            QVariantMap{ { QStringLiteral("id"), desktopId }, { QStringLiteral("uuid"), desktopUuid } } } };
    return map;
}

void KWinActiveWindowBridge::buildWindowList() {
    QVariantList newList;
    QVariantMap newActiveWindow;
    bool activeWindowFound = false;

    auto* plasmaWindows = PlasmaWindows::instance();
    for (const QString& uuid : plasmaWindows->windowUuids()) {
        if (auto* handle = plasmaWindows->handleFor(uuid)) {
            QVariantMap w = windowToVariant(handle);
            newList.append(w);
            if (handle->isActive()) {
                newActiveWindow = w;
                activeWindowFound = true;
            }
        }
    }

    if (newList != m_windowList) {
        m_windowList = newList;
        m_windowCache.clear();
        for (const QVariant& v : m_windowList) {
            const QVariantMap map = v.toMap();
            m_windowCache.insert(map.value(QStringLiteral("address")).toString(), map);
        }
        rebuildIndex();
        emit windowListChanged();
    }

    if (activeWindowFound && m_activeWindow != newActiveWindow) {
        m_activeWindow = newActiveWindow;
        emit activeWindowChanged();
        if (m_lastActiveWindow != newActiveWindow) {
            m_lastActiveWindow = newActiveWindow;
            emit lastActiveWindowChanged();
        }

        const QString newOutput = newActiveWindow.value(QStringLiteral("output")).toString();
        if (!newOutput.isEmpty())
            setActiveOutputName(newOutput);

        if (m_activeWindow.value(QStringLiteral("address")).toString() == m_pendingFocusAddress) {
            m_pendingFocusAddress.clear();
            emit pendingFocusAddressChanged();
        }
    } else if (!activeWindowFound && !m_activeWindow.isEmpty()) {
        m_activeWindow.clear();
        emit activeWindowChanged();
    }

    const QString lastAddr = m_lastActiveWindow.value(QStringLiteral("address")).toString();
    if (!lastAddr.isEmpty()) {
        const int idx = m_windowIndex.value(lastAddr, -1);
        if (idx >= 0 && idx < m_windowList.size()) {
            const QVariantMap updated = m_windowList[idx].toMap();
            if (m_lastActiveWindow != updated) {
                m_lastActiveWindow = updated;
                emit lastActiveWindowChanged();
            }
        } else {
            m_lastActiveWindow.clear();
            emit lastActiveWindowChanged();
        }
    }
}

void KWinActiveWindowBridge::focusWindow(const QString& address) {
    if (!m_highlightedAddress.isEmpty()) {
        clearHighlight();
    }
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        m_pendingFocusAddress = address;
        emit pendingFocusAddressChanged();

        handle->setState(QtWayland::org_kde_plasma_window_management::state_minimized, false);
        handle->setState(QtWayland::org_kde_plasma_window_management::state_active, true);
    }
}

void KWinActiveWindowBridge::closeWindow(const QString& address) {
    if (!m_highlightedAddress.isEmpty() && m_highlightedAddress == address) {
        clearHighlight();
    }
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        handle->close();
    }
}

void KWinActiveWindowBridge::minimizeWindow(const QString& address) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        handle->setState(QtWayland::org_kde_plasma_window_management::state_minimized, true);
    }
}

void KWinActiveWindowBridge::maximizeWindow(const QString& address, bool horz, bool vert) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        const auto max = QtWayland::org_kde_plasma_window_management::state_maximized;
        handle->setState(max, horz || vert);
    }
}

void KWinActiveWindowBridge::raiseWindow(const QString& address) {
    focusWindow(address);
}

void KWinActiveWindowBridge::setWindowProperty(const QString& address, const QString& property, bool enable) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        uint32_t state = 0;
        if (property == QStringLiteral("keep_above"))
            state = QtWayland::org_kde_plasma_window_management::state_keep_above;
        else if (property == QStringLiteral("keep_below"))
            state = QtWayland::org_kde_plasma_window_management::state_keep_below;
        else if (property == QStringLiteral("skip_taskbar"))
            state = QtWayland::org_kde_plasma_window_management::state_skiptaskbar;
        else if (property == QStringLiteral("demands_attention"))
            state = QtWayland::org_kde_plasma_window_management::state_demands_attention;

        if (state != 0) {
            handle->setState(state, enable);
        }
    }
}

void KWinActiveWindowBridge::setWindowDesktop(const QString& address, int desktopId) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        if (auto wsState = KWinWorkspaceState::instance()) {
            QString uuid = wsState->uuidForIndex(desktopId);
            if (!uuid.isEmpty()) {
                QStringList currentDesktops = handle->desktops();
                for (const QString& oldUuid : currentDesktops) {
                    if (oldUuid != uuid) {
                        handle->request_leave_virtual_desktop(oldUuid);
                    }
                }
                handle->request_enter_virtual_desktop(uuid);
            }
        }
    }
}

void KWinActiveWindowBridge::setFullscreen(const QString& address, bool fullscreen) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        handle->setState(QtWayland::org_kde_plasma_window_management::state_fullscreen, fullscreen);
    }
}

void KWinActiveWindowBridge::setMaximized(const QString& address, bool maximized) {
    if (auto* handle = PlasmaWindows::instance()->handleFor(address)) {
        handle->setState(QtWayland::org_kde_plasma_window_management::state_maximized, maximized);
    }
}

void KWinActiveWindowBridge::highlightWindow(const QString& address) {
    if (address == m_highlightedAddress && !address.isEmpty()) {
        return;
    }
    m_highlightedAddress = address;
    emit highlightedAddressChanged();

    auto msg =
        QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/org/kde/KWin/HighlightWindow"),
            QStringLiteral("org.kde.KWin.HighlightWindow"), QStringLiteral("highlightWindows"));
    QStringList list;
    if (!address.isEmpty()) {
        list << address;
    }
    msg << list;
    QDBusConnection::sessionBus().send(msg);
}

void KWinActiveWindowBridge::clearHighlight() {
    if (!m_highlightedAddress.isEmpty()) {
        highlightWindow(QString());
    } else {
        auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
            QStringLiteral("/org/kde/KWin/HighlightWindow"), QStringLiteral("org.kde.KWin.HighlightWindow"),
            QStringLiteral("highlightWindows"));
        msg << QStringList();
        QDBusConnection::sessionBus().send(msg);
    }
}

void KWinActiveWindowBridge::showAppMenu(
    const QString& service, const QString& objectPath, int x, int y, int actionId) {
    QString svc = service;
    QString path = objectPath;
    if (svc.isEmpty() && path.isEmpty()) {
        svc = m_activeWindow.value(QStringLiteral("menuService")).toString();
        path = m_activeWindow.value(QStringLiteral("menuObject")).toString();
        if (svc.isEmpty()) {
            svc = m_lastActiveWindow.value(QStringLiteral("menuService")).toString();
            path = m_lastActiveWindow.value(QStringLiteral("menuObject")).toString();
        }
    }
    if (svc.isEmpty())
        return;
    if (path.isEmpty())
        path = QStringLiteral("/");

    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.kappmenu"), QStringLiteral("/KAppMenu"),
        QStringLiteral("org.kde.kappmenu"), QStringLiteral("showMenu"));
    msg << x << y << svc << QDBusObjectPath(path) << actionId;
    QDBusConnection::sessionBus().send(msg);
}

void KWinActiveWindowBridge::refreshWindows() {
    if (auto* plasmaWindows = PlasmaWindows::instance()) {
        plasmaWindows->refresh();
    }
    scheduleWindowListUpdate();
}

} // namespace caelestia::services
