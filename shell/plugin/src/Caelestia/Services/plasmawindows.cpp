// SPDX-License-Identifier: GPL-3.0-only
#include "plasmawindows.hpp"

#include <QCoreApplication>
#include <QLoggingCategory>
#include <QUuid>

namespace caelestia::services {

namespace {

Q_LOGGING_CATEGORY(logPlasmaWindows, "caelestia.services.plasmawindows");

// get_window_by_uuid, which is what lets us address a window without mirroring
// KWin's entire window list. get_icon needs 7, so 12 covers both.
constexpr int kRequiredVersion = 20;

bool s_connectionGone = false;

} // namespace

PlasmaWindowHandle::PlasmaWindowHandle(::org_kde_plasma_window* window)
    : QtWayland::org_kde_plasma_window(window) {}

PlasmaWindowHandle::~PlasmaWindowHandle() {
    if (!s_connectionGone && isInitialized()) {
        destroy();
    }
}

QString PlasmaWindowHandle::uuid() const {
    return m_uuid;
}

void PlasmaWindowHandle::setUuid(const QString& uuid) {
    m_uuid = uuid;
}

void PlasmaWindowHandle::org_kde_plasma_window_title_changed(const QString& title) {
    if (m_title != title) {
        m_title = title;
        emit titleChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_app_id_changed(const QString& app_id) {
    if (m_appId != app_id) {
        m_appId = app_id;
        emit appIdChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_state_changed(uint32_t flags) {
    bool active = (flags & QtWayland::org_kde_plasma_window_management::state_active);
    bool minimized = (flags & QtWayland::org_kde_plasma_window_management::state_minimized);
    bool maximized = (flags & QtWayland::org_kde_plasma_window_management::state_maximized);
    bool fullscreen = (flags & QtWayland::org_kde_plasma_window_management::state_fullscreen);
    bool demandsAttention = (flags & QtWayland::org_kde_plasma_window_management::state_demands_attention);
    bool skipTaskbar = (flags & QtWayland::org_kde_plasma_window_management::state_skiptaskbar);

    bool changed = false;
    if (m_isActive != active) {
        m_isActive = active;
        changed = true;
    }
    if (m_isMinimized != minimized) {
        m_isMinimized = minimized;
        changed = true;
    }
    if (m_isMaximized != maximized) {
        m_isMaximized = maximized;
        changed = true;
    }
    if (m_isFullscreen != fullscreen) {
        m_isFullscreen = fullscreen;
        changed = true;
    }
    if (m_demandsAttention != demandsAttention) {
        m_demandsAttention = demandsAttention;
        changed = true;
    }
    if (m_skipTaskbar != skipTaskbar) {
        m_skipTaskbar = skipTaskbar;
        changed = true;
    }

    if (changed) {
        emit stateChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_geometry(int32_t x, int32_t y, uint32_t width, uint32_t height) {
    if (m_x != x || m_y != y || m_width != width || m_height != height) {
        m_x = x;
        m_y = y;
        m_width = width;
        m_height = height;
        emit geometryChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_client_geometry(int32_t x, int32_t y, uint32_t width, uint32_t height) {
    if (m_x != x || m_y != y || m_width != width || m_height != height) {
        m_x = x;
        m_y = y;
        m_width = width;
        m_height = height;
        emit geometryChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_initial_state() {
    m_hasInitialState = true;
    emit stateChanged();
    emit geometryChanged();
    emit desktopsChanged();
}

void PlasmaWindowHandle::org_kde_plasma_window_virtual_desktop_changed(int32_t number) {
    if (number >= 0) {
        const int oneBased = number + 1;
        const QString numStr = QString::number(oneBased);
        if (!m_desktops.contains(numStr)) {
            m_desktops.clear();
            m_desktops.append(numStr);
            emit desktopsChanged();
        }
    } else {
        if (!m_desktops.isEmpty()) {
            m_desktops.clear();
            emit desktopsChanged();
        }
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_pid_changed(uint32_t pid) {
    if (m_pid != pid) {
        m_pid = pid;
        emit pidChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_virtual_desktop_entered(const QString& id) {
    if (!m_desktops.contains(id)) {
        m_desktops.append(id);
        emit desktopsChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_virtual_desktop_left(const QString& id) {
    if (m_desktops.removeOne(id)) {
        emit desktopsChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_application_menu(
    const QString& service_name, const QString& object_path) {
    if (m_menuServiceName != service_name || m_menuObjectPath != object_path) {
        m_menuServiceName = service_name;
        m_menuObjectPath = object_path;
        emit appMenuChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_activity_entered(const QString& id) {
    if (!m_activities.contains(id)) {
        m_activities.append(id);
        emit activitiesChanged();
    }
}

void PlasmaWindowHandle::org_kde_plasma_window_activity_left(const QString& id) {
    if (m_activities.removeOne(id))
        emit activitiesChanged();
}

void PlasmaWindowHandle::org_kde_plasma_window_unmapped() {
    emit unmapped();
}

PlasmaWindowManagement::PlasmaWindowManagement(QObject* parent)
    : QWaylandClientExtensionTemplate<PlasmaWindowManagement>(kRequiredVersion) {
    connect(this, &QWaylandClientExtension::activeChanged, this, [this]() {
        if (isActive()) {
            requestStackingOrder();
        } else {
            qCWarning(logPlasmaWindows) << "org_kde_plasma_window_management deactivated";
        }
    });
    setParent(parent);
    initialize();
    if (isActive()) {
        requestStackingOrder();
    }
}

PlasmaWindowManagement::~PlasmaWindowManagement() = default;

void PlasmaWindowManagement::requestStackingOrder() {
    if (!isActive()) {
        return;
    }
    if (this->QWaylandClientExtension::version() >= 17) {
        auto* stacking_order_obj = get_stacking_order();
        if (stacking_order_obj) {
            auto* wrapper = new PlasmaStackingOrder(stacking_order_obj, this);
            connect(wrapper, &PlasmaStackingOrder::done, this, &PlasmaWindowManagement::stackingOrderReceived);
            connect(wrapper, &PlasmaStackingOrder::done, wrapper, &QObject::deleteLater);
        }
    }
}

void PlasmaWindowManagement::org_kde_plasma_window_management_window_with_uuid(uint32_t id, const QString& uuid) {
    emit windowWithUuid(id, uuid);
}

void PlasmaWindowManagement::org_kde_plasma_window_management_window(uint32_t id) {}

void PlasmaWindowManagement::org_kde_plasma_window_management_stacking_order_uuid_changed(const QString& uuids) {
    emit stackingOrderReceived(uuids.split(QLatin1Char(';'), Qt::SkipEmptyParts));
}

void PlasmaWindowManagement::org_kde_plasma_window_management_stacking_order_changed(wl_array* ids) {}

void PlasmaWindowManagement::org_kde_plasma_window_management_stacking_order_changed_2() {
    requestStackingOrder();
}

PlasmaStackingOrder::PlasmaStackingOrder(struct ::org_kde_plasma_stacking_order* object, QObject* parent)
    : QObject(parent)
    , QtWayland::org_kde_plasma_stacking_order(object) {}

PlasmaStackingOrder::~PlasmaStackingOrder() {
    // The done event is a protocol destructor, and a shutdown deletes the manager
    // these wrappers are parented to. Both leave nothing to send.
    if (!s_connectionGone && isInitialized())
        ::org_kde_plasma_stacking_order_destroy(object());
}

void PlasmaStackingOrder::org_kde_plasma_stacking_order_window(const QString& uuid) {
    m_uuids.append(uuid);
}

void PlasmaStackingOrder::org_kde_plasma_stacking_order_done() {
    emit done(m_uuids);
}

PlasmaWindows::PlasmaWindows(QObject* parent)
    : QObject(parent) {
    if (auto* app = QCoreApplication::instance()) {
        connect(app, &QCoreApplication::aboutToQuit, this, &PlasmaWindows::shutdown);
    }

    available();
}

PlasmaWindows* PlasmaWindows::instance() {
    static auto* s_instance = new PlasmaWindows();
    return s_instance;
}

QString PlasmaWindows::normaliseUuid(const QString& uuid) {
    const auto parsed = QUuid::fromString(uuid);
    return parsed.isNull() ? uuid : parsed.toString(QUuid::WithBraces);
}

bool PlasmaWindows::available() {
    if (s_connectionGone) {
        return false;
    }
    if (!m_management) {
        m_management = new PlasmaWindowManagement(this);
        connect(m_management, &PlasmaWindowManagement::windowWithUuid, this, &PlasmaWindows::onWindowWithUuid);
        connect(m_management, &PlasmaWindowManagement::windowMapped, this, &PlasmaWindows::onWindowMapped);
        connect(m_management, &PlasmaWindowManagement::stackingOrderReceived, this, [this](const QStringList& uuids) {
            QStringList order;
            order.reserve(uuids.size());
            for (const auto& uuid : uuids) {
                const auto key = normaliseUuid(uuid);
                if (!m_handles.contains(key))
                    onWindowWithUuid(0, uuid);
                order.append(key);
            }
            if (order != m_stackingOrder) {
                m_stackingOrder = order;
                emit stackingOrderChanged();
            }
        });
    }
    bool active = m_management->isActive();
    return active;
}

void PlasmaWindows::refresh() {
    if (m_management) {
        m_management->requestStackingOrder();
    }
}

void PlasmaWindows::onWindowWithUuid(uint32_t id, const QString& raw_uuid) {
    const auto key = normaliseUuid(raw_uuid);

    if (m_handles.contains(key)) {
        return;
    }

    auto* window = m_management->get_window_by_uuid(raw_uuid);
    auto* handle = new PlasmaWindowHandle(window);
    handle->setUuid(key);
    handle->setParent(this);
    connect(handle, &PlasmaWindowHandle::unmapped, this, [this, key]() {
        forget(key);
    });

    m_handles.insert(key, handle);
    emit windowAdded(key);
}

void PlasmaWindows::onWindowMapped(uint32_t id) {}

PlasmaWindowHandle* PlasmaWindows::handleFor(const QString& uuid) {
    if (uuid.isEmpty() || !available()) {
        return nullptr;
    }

    const auto key = normaliseUuid(uuid);
    if (const auto it = m_handles.constFind(key); it != m_handles.constEnd()) {
        return *it;
    }

    auto* handle = new PlasmaWindowHandle(m_management->get_window_by_uuid(key));
    handle->setUuid(key);
    handle->setParent(this);
    connect(handle, &PlasmaWindowHandle::unmapped, this, [this, key]() {
        forget(key);
    });
    m_handles.insert(key, handle);
    emit windowAdded(key);
    return handle;
}

void PlasmaWindows::forget(const QString& uuid) {
    const auto key = normaliseUuid(uuid);
    if (auto* handle = m_handles.take(key)) {
        handle->deleteLater();
    }
    // KWin republishes the stack only when it changes, so a closed window would
    // otherwise keep its place in the list.
    if (m_stackingOrder.removeAll(key) > 0) {
        emit stackingOrderChanged();
    }
    emit handleLost(key);
}

void PlasmaWindows::shutdown() {
    if (s_connectionGone) {
        return;
    }

    const auto uuids = m_handles.keys();
    for (const auto& uuid : uuids) {
        delete m_handles.take(uuid);
    }

    delete m_management;
    m_management = nullptr;

    s_connectionGone = true;
}

} // namespace caelestia::services
