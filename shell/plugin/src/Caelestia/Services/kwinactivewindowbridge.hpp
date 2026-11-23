#pragma once

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

namespace caelestia::services {

class KWinWorkspaceState;
class PlasmaWindowHandle;

class KWinActiveWindowBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap activeWindow READ activeWindow NOTIFY activeWindowChanged)
    Q_PROPERTY(QVariantMap lastActiveWindow READ lastActiveWindow NOTIFY lastActiveWindowChanged)
    Q_PROPERTY(QString activeOutputName READ activeOutputName WRITE setActiveOutputName NOTIFY activeOutputNameChanged)
    Q_PROPERTY(QVariantList windowList READ windowList NOTIFY windowListChanged)
    // Outputs whose topmost visible window is fullscreen.
    Q_PROPERTY(QStringList fullscreenOutputs READ fullscreenOutputs NOTIFY fullscreenOutputsChanged)
    Q_PROPERTY(QString pendingFocusAddress READ pendingFocusAddress NOTIFY pendingFocusAddressChanged)
    Q_PROPERTY(QString highlightedAddress READ highlightedAddress NOTIFY highlightedAddressChanged)
    QML_ELEMENT
    QML_SINGLETON

public:
    ~KWinActiveWindowBridge() override;

    static KWinActiveWindowBridge* create(QQmlEngine* engine, QJSEngine* jsEngine);

    QVariantMap activeWindow() const;
    QVariantMap lastActiveWindow() const;
    QString activeOutputName() const;
    Q_INVOKABLE void setActiveOutputName(const QString& outputName);

    QVariantList windowList() const;
    QStringList fullscreenOutputs() const;
    QString pendingFocusAddress() const;
    QString highlightedAddress() const;

    Q_INVOKABLE QVariantList windowsForWorkspace(const QVariant& workspace, bool includeOnAllWorkspaces = true) const;

    Q_INVOKABLE QString cursorOutputName() const;
    Q_INVOKABLE void focusWindow(const QString& address);
    Q_INVOKABLE void closeWindow(const QString& address);
    Q_INVOKABLE void minimizeWindow(const QString& address);
    Q_INVOKABLE void maximizeWindow(const QString& address, bool horz = true, bool vert = true);
    Q_INVOKABLE void raiseWindow(const QString& address);
    Q_INVOKABLE void setWindowProperty(const QString& address, const QString& property, bool enable);
    Q_INVOKABLE void setWindowDesktop(const QString& address, int desktopId);
    Q_INVOKABLE void sendToOutput(const QString& address, const QString& outputName);
    Q_INVOKABLE void setFullscreen(const QString& address, bool fullscreen);
    Q_INVOKABLE void setMaximized(const QString& address, bool maximized);
    Q_INVOKABLE void highlightWindow(const QString& address);
    Q_INVOKABLE void clearHighlight();
    Q_INVOKABLE void showAppMenu(const QString& service, const QString& objectPath, int x, int y, int actionId = 0);

    Q_INVOKABLE void refreshWindows();

signals:
    void activeWindowChanged();
    void lastActiveWindowChanged();
    void activeOutputNameChanged();
    void windowListChanged();
    void fullscreenOutputsChanged();
    void pendingFocusAddressChanged();
    void highlightedAddressChanged();

private slots:
    void onWindowAdded(const QString& uuid);
    void onWindowLost(const QString& uuid);
    void scheduleWindowListUpdate();
    void buildWindowList();
    void scheduleFullscreenUpdate();
    void updateFullscreenOutputs();

private:
    // Private, so QML builds the singleton through create().
    explicit KWinActiveWindowBridge(QObject* parent = nullptr);

    QVariantMap windowToVariant(PlasmaWindowHandle* w) const;
    // The desktop ids a window is on, with numeric ids resolved to uuids, so
    // callers compare one representation.
    QStringList desktopUuids(const PlasmaWindowHandle* window) const;
    QString getOutputNameForGeometry(int x, int y, int w, int h) const;
    void onStateChanged(PlasmaWindowHandle* handle);
    // Rebuilds m_windowIndex from the current m_windowList. Call after any
    // operation that inserts, removes, or reorders entries.
    void rebuildIndex();

    QVariantMap m_activeWindow;
    QVariantMap m_lastActiveWindow;
    QVariantList m_windowList;
    QHash<QString, QVariantMap> m_windowCache;
    QHash<QString, int> m_windowIndex; // uuid → index in m_windowList, O(1) lookup
    QString m_activeOutputName;
    QString m_pendingFocusAddress;
    QString m_highlightedAddress;
    QStringList m_fullscreenOutputs;
    QPointer<KWinWorkspaceState> m_workspaceState;

    QTimer m_updateTimer;
    QTimer m_fullscreenTimer;
};

} // namespace caelestia::services
