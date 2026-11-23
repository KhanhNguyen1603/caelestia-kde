// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QHash>
#include <QObject>
#include <QtWaylandClient/QWaylandClientExtension>

#include "qwayland-plasma-window-management.h"

namespace caelestia::services {

/// One org_kde_plasma_window handle, held for as long as something has a use
/// for the window it names.
class PlasmaWindowHandle : public QObject, public QtWayland::org_kde_plasma_window {
    Q_OBJECT

public:
    explicit PlasmaWindowHandle(::org_kde_plasma_window* window);
    ~PlasmaWindowHandle() override;

    QString uuid() const;
    void setUuid(const QString& uuid);

    QString title() const { return m_title; }

    QString appId() const { return m_appId; }

    uint32_t pid() const { return m_pid; }

    int x() const { return m_x; }

    int y() const { return m_y; }

    uint32_t width() const { return m_width; }

    uint32_t height() const { return m_height; }

    bool isActive() const { return m_isActive; }

    bool isMinimized() const { return m_isMinimized; }

    bool isMaximized() const { return m_isMaximized; }

    bool isFullscreen() const { return m_isFullscreen; }

    bool demandsAttention() const { return m_demandsAttention; }

    bool skipTaskbar() const { return m_skipTaskbar; }

    QStringList desktops() const { return m_desktops; }

    QString menuServiceName() const { return m_menuServiceName; }

    QString menuObjectPath() const { return m_menuObjectPath; }

    QStringList activities() const { return m_activities; }

    /// Whether KWin has sent this window's state. Until then it reads as an
    /// unminimised, empty window at the origin.
    bool hasInitialState() const { return m_hasInitialState; }

    /// Sets or clears one window state flag.
    ///
    /// The protocol request carries a flags bitfield (which states are being
    /// touched) and a state bitfield (their new values), so clearing a flag is
    /// flags=flag, state=0. Passing flags=0 matches no state at all and does
    /// nothing, which is what made the "restore" paths silently no-op.
    void setState(uint32_t flag, bool set) { set_state(flag, set ? flag : 0); }

signals:
    void titleChanged();
    void appIdChanged();
    void pidChanged();
    void geometryChanged();
    void stateChanged();
    void desktopsChanged();
    void appMenuChanged();
    void activitiesChanged();

    void unmapped();

protected:
    void org_kde_plasma_window_title_changed(const QString& title) override;
    void org_kde_plasma_window_app_id_changed(const QString& app_id) override;
    void org_kde_plasma_window_state_changed(uint32_t flags) override;
    void org_kde_plasma_window_geometry(int32_t x, int32_t y, uint32_t width, uint32_t height) override;
    void org_kde_plasma_window_client_geometry(int32_t x, int32_t y, uint32_t width, uint32_t height) override;
    void org_kde_plasma_window_initial_state() override;
    void org_kde_plasma_window_virtual_desktop_changed(int32_t number) override;
    void org_kde_plasma_window_pid_changed(uint32_t pid) override;
    void org_kde_plasma_window_virtual_desktop_entered(const QString& id) override;
    void org_kde_plasma_window_virtual_desktop_left(const QString& id) override;
    void org_kde_plasma_window_application_menu(const QString& service_name, const QString& object_path) override;
    void org_kde_plasma_window_activity_entered(const QString& id) override;
    void org_kde_plasma_window_activity_left(const QString& id) override;
    void org_kde_plasma_window_unmapped() override;

private:
    QString m_uuid;
    QString m_title;
    QString m_appId;
    uint32_t m_pid = 0;
    int m_x = 0;
    int m_y = 0;
    uint32_t m_width = 0;
    uint32_t m_height = 0;
    bool m_isActive = false;
    bool m_isMinimized = false;
    bool m_isMaximized = false;
    bool m_isFullscreen = false;
    bool m_demandsAttention = false;
    bool m_skipTaskbar = false;
    bool m_hasInitialState = false;
    QStringList m_desktops;
    QString m_menuServiceName;
    QString m_menuObjectPath;
    QStringList m_activities;
};

class PlasmaWindowManagement : public QWaylandClientExtensionTemplate<PlasmaWindowManagement>,
                               public QtWayland::org_kde_plasma_window_management {
    Q_OBJECT

public:
    explicit PlasmaWindowManagement(QObject* parent = nullptr);
    ~PlasmaWindowManagement() override;

    void requestStackingOrder();

signals:
    void windowWithUuid(uint32_t id, const QString& uuid);
    void windowMapped(uint32_t id);
    void stackingOrderReceived(const QStringList& uuids);

protected:
    void org_kde_plasma_window_management_window_with_uuid(uint32_t id, const QString& uuid) override;
    void org_kde_plasma_window_management_window(uint32_t id) override;
    void org_kde_plasma_window_management_stacking_order_changed(wl_array* ids) override;
    void org_kde_plasma_window_management_stacking_order_uuid_changed(const QString& uuids) override;
    void org_kde_plasma_window_management_stacking_order_changed_2() override;
};

class PlasmaStackingOrder : public QObject, public QtWayland::org_kde_plasma_stacking_order {
    Q_OBJECT

public:
    explicit PlasmaStackingOrder(struct ::org_kde_plasma_stacking_order* object, QObject* parent = nullptr);
    ~PlasmaStackingOrder() override;

protected:
    void org_kde_plasma_stacking_order_window(const QString& uuid) override;
    void org_kde_plasma_stacking_order_done() override;

signals:
    void done(const QStringList& uuids);

private:
    QStringList m_uuids;
};

class PlasmaWindows : public QObject {
    Q_OBJECT

public:
    static PlasmaWindows* instance();

    bool available();
    void refresh();

    /// The handle for @p uuid, or nullptr if the interface is unavailable or
    /// the connection is already gone. Uuids are normalised, so callers need
    /// not care whether theirs arrived brace-wrapped.
    PlasmaWindowHandle* handleFor(const QString& uuid);

    /// The handle for @p uuid if there already is one. Unlike handleFor, it
    /// never asks KWin for a window, which may have closed.
    PlasmaWindowHandle* existingHandle(const QString& uuid) const { return m_handles.value(normaliseUuid(uuid)); }

    QList<QString> windowUuids() const { return m_handles.keys(); }

    /// Window uuids from the bottom of KWin's stack to the top.
    QStringList stackingOrder() const { return m_stackingOrder; }

    /// KWin hands out window ids as QUuid::toString(), i.e. brace-wrapped.
    static QString normaliseUuid(const QString& uuid);

signals:
    void windowAdded(const QString& uuid);
    void stackingOrderChanged();

    void handleLost(const QString& uuid);

private slots:
    void onWindowWithUuid(uint32_t id, const QString& uuid);
    void onWindowMapped(uint32_t id);

private:
    explicit PlasmaWindows(QObject* parent = nullptr);

    void forget(const QString& uuid);
    void shutdown();

    PlasmaWindowManagement* m_management = nullptr;
    QHash<QString, PlasmaWindowHandle*> m_handles;
    QStringList m_stackingOrder;
};

} // namespace caelestia::services
