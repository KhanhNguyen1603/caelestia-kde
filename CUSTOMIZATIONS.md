# Tổng hợp các thay đổi và tối ưu hóa (Customizations & Optimizations)

Tài liệu này tổng hợp toàn bộ các chỉnh sửa, tối ưu hóa và tính năng mới trên fork [KhanhNguyen1603/caelestia-kde](https://github.com/KhanhNguyen1603/caelestia-kde.git) dựa trên bản phát hành **`v2.7.6`** của upstream [`caelestia-kde/caelestia`](https://github.com/caelestia-kde/caelestia).

> **Cấu trúc chuỗi commit (Layered Atomic Commits):**
> - **Tầng 1 (10 commits PR-ready):** Các bản vá lỗi và tính năng sạch, đạt chuẩn CI upstream (0 lỗi linter/hygiene mới, không kèm tài liệu fork).
> - **Tầng 2 (5 commits Fork-only):** Các tùy biến cá nhân, chuyển hướng updater về fork và tài liệu nội bộ này.

---

## Tầng 1 — Các cải tiến & bản vá lỗi (PR-ready)

### 1. Biểu tượng Desktop Super Small (32px)
* **Tệp ảnh hưởng:** `shell/modules/background/desktopicons/ViewOptions.qml`, `shell/modules/nexus/pages/desktop/DesktopSettingsPage.qml`, `shell/services/DesktopLayout.qml`
* **Chi tiết:** Bổ sung mức kích thước biểu tượng **Super Small (32px)** bên cạnh các mức mặc định 48px, 64px, 80px, 96px.

### 2. Bảo vệ an toàn con trỏ màn hình khi Output Teardown (Lock/DPMS/Unplug)
* **Tệp ảnh hưởng:** `shell/modules/background/DesktopIcons.qml`, `shell/services/DesktopLayout.qml`, `shell/modules/dashboard/Content.qml`
* **Chi tiết:**
  * Lưu trữ tên màn hình đã đăng ký (`registeredScreenName` / `screenName`) trong `DesktopIcons.qml` và kiểm tra khớp tham chiếu controller trong `DesktopLayout.unregisterController(screenName, controller)` để triệt tiêu `TypeError: Cannot read property 'name' of null` và ngăn màn hình cũ bị `deleteLater` xóa nhầm controller của màn hình mới.
  * Thêm guard `screenState` khác `null` trong `shell/modules/dashboard/Content.qml`.

### 3. Căn đều lề 4 cạnh lưới Desktop & tránh bị che dưới viền màn hình
* **Tệp ảnh hưởng:** `shell/modules/background/DesktopIcons.qml`, `tests/test_desktop_widget_arrangement.sh`
* **Chi tiết:**
  * Kéo giãn `cellWidth`/`cellHeight` để lấp đầy vùng khả dụng (giữ tối thiểu `baseCellWidth`/`baseCellHeight`), giúp 4 cạnh đều nhau thay vì dồn toàn bộ pixel dư sang phải và dưới.
  * Đảm bảo `baseMargin` không nhỏ hơn `Config.border.thickness` để icon không bị chui xuống dưới viền màn hình.

### 4. AutoScheme đợi `Colours.schemeLoaded` trước khi quyết định chế độ Sáng/Tối
* **Tệp ảnh hưởng:** `shell/services/AutoScheme.qml`
* **Chi tiết:** Chặn `AutoScheme.apply()` chạy trước khi file màu trên đĩa được đọc xong (`Colours.schemeLoaded`), đồng thời so sánh với `Colours.currentLight` thay vì `Colours.light` để tránh tự đảo nhầm sang dark khi khởi động.

### 5. Tự động chèn cờ thực thi (`-e` / `--`) trong `Launch.terminalCommand`
* **Tệp ảnh hưởng:** `shell/utils/Launch.qml`, `shell/modules/launcher/items/CalcItem.qml`, `shell/modules/nexus/pages/UpdatesPage.qml`
* **Chi tiết:** Tự động chèn `--` (cho `foot`, `footclient`, `gnome-terminal`, `ptyxis`, `blackbox`) hoặc `-e` (cho `ghostty`, `alacritty`, `kitty`, `konsole`, `wezterm`, ...) khi chạy lệnh trong terminal mà user chưa chỉ định sẵn cờ.

### 6. Bảng "Create New..." tạo tệp & thư mục mới trên Desktop
* **Tệp ảnh hưởng:** `shell/modules/background/desktopicons/CreateNewPanel.qml`, `shell/modules/background/DesktopContextMenu.qml`, `shell/modules/background/DesktopIcons.qml`, `shell/modules/drawers/ContentWindow.qml`, `shell/modules/nexus/pages/desktop/ContextMenuPage.qml`, `shell/services/ContextMenuStore.qml`, `shell/services/DesktopLayout.qml`
* **Chi tiết:** Thêm mục **Create New...** trong menu chuột phải Desktop, mở bảng tạo Folder / Text File / Markdown / New File với tự động đánh số khi trùng tên (`New Folder (1)`) và tích hợp vào danh sách `desktopPopups` của `ContentWindow.qml`.

### 7. Tách riêng cài đặt bo góc viền trên và viền dưới (`roundingTop` / `roundingBottom`)
* **Tệp ảnh hưởng:** `shell/plugin/src/Caelestia/Config/borderconfig.hpp`, `shell/plugin/src/Caelestia/Blobs/*`, `shell/modules/drawers/ContentWindow.qml`, `shell/modules/drawers/Interactions.qml`, `shell/modules/drawers/blur/BlurCorners.qml`, `shell/modules/nexus/pages/wallandstyle/AppearancePage.qml`, `shell/modules/nexus/PageRowIndex.qml`
* **Chi tiết:** Tách `border.rounding` thành `roundingTop` và `roundingBottom` (có tương thích ngược `syncJson`), cập nhật SDF shader, giữ nguyên bản tối ưu `BlurCorners.qml` của upstream và tương thích với per-panel `bar.isIsland` + `edgeThickness*` của `v2.7.6`, có nút reset riêng và đã cập nhật `PageRowIndex.qml` cho tìm kiếm Nexus.

### 8. Khôi phục plugin `org.kde.image` khi shell sở hữu wallpaper và `skwd` đã dừng
* **Tệp ảnh hưởng:** `shell/services/Wallpapers.qml`
* **Chi tiết:** Tích hợp vào `applyWallpaperEngine()`; khi shell thực sự sở hữu wallpaper (`quickshell` hoặc `auto` khi `skwd-walld` không chạy), chỉ chuyển desktop đang kẹt ở plugin `org.skwd.wall.plasma` về `org.kde.image` mà không đụng tới plugin do người dùng chủ động chọn.

### 9. Tự động chuyển cặp hình nền Sáng/Tối theo thay đổi giao diện
* **Tệp ảnh hưởng:** `shell/services/Wallpapers.qml`
* **Chi tiết:** Tự động nhận diện cặp ảnh sáng/tối theo chuẩn KDE Wallpaper Package (`contents/images/` <-> `contents/images_dark/`) và các hậu tố thông dụng (`_dark`/`_light`, `-dark`/`-light`, `.dark`/`.light`, `_night`/`_day`, ...) khi `Colours.currentLight` đổi, có chống vòng lặp ping-pong.

### 10. Không ẩn Visualizer, Lyrics và Desktop Widgets khi bấm `Meta + D` (Show Desktop)
* **Tệp ảnh hưởng:** `shell/services/Kwin.qml`, `shell/services/PlasmaWidgets.qml`
* **Chi tiết:** Kiểm tra `if (root.showingDesktop) return false;` trong `Kwin.windowHidesDesktopWidgets()` và thêm `Kwin.showingDesktop` vào dependency của `windowHidesVisualizer`, giúp Visualizer, Desktop Lyrics, Desktop Shapes và System Widget hiện ngay khi bật Show Desktop (`Meta + D`) thay vì bị auto-hide nhầm do cửa sổ maximized chưa có `minimized = true`.

---

## Tầng 2 — Tùy biến nội bộ của Fork (Fork-only)

### 11. Thẻ gạt Keep Awake ở Sidebar & khóa sprite Khủng Long cổ điển
* **Tệp ảnh hưởng:** `shell/modules/sidebar/DinoGame.qml`, `shell/modules/sidebar/NotifDock.qml`
* **Chi tiết:** Khóa game khủng long sử dụng sprite `dino` cổ điển và thay thẻ gạt ở chân NotifDock thành nút **Keep Awake** (biểu tượng cà phê) gắn với `IdleInhibitor.enabled`.

### 12. Xóa khung ảnh động trang trí trong Power Menu
* **Tệp ảnh hưởng:** `shell/modules/session/Content.qml`
* **Chi tiết:** Bỏ khung GIF trang trí giữa các nút nguồn để menu gọn và mở nhanh hơn.

### 13. Chuyển hướng Updater về Fork & ép build cục bộ
* **Tệp ảnh hưởng:** `scripts/08-build-shell.sh`, `update.sh`, `shell/services/UpdateChecker.qml`, `src/bin/caelestia-check-updates`, `src/bin/caelestia-update`
* **Chi tiết:** Trỏ toàn bộ URL kiểm tra/cập nhật từ `caelestia-kde/caelestia` về `KhanhNguyen1603/caelestia-kde` và đặt mặc định `CAELESTIA_FORCE_BUILD_SHELL=1` để luôn biên dịch C++ plugin từ mã nguồn fork.

### 14. Khôi phục Built-in Cava Visualizer cho Quickshell Wallpaper
* **Tệp ảnh hưởng:** `shell/modules/background/Visualiser.qml`, `shell/modules/background/Background.qml`, `shell/modules/nexus/pages/desktop/DesktopAddonsPage.qml`
* **Chi tiết:** Khôi phục widget C++ `VisualiserBars` + `libcava` từ `v2.6.3` (không bật `MultiEffect` blur cho siêu nhẹ), chỉ chạy khi `Config.background.wallpaperEnabled` đang bật (tự lọc im lặng `isSilent()` và tự ngủ `m_settled` khi không có tiếng); tự nhường cho Plasma Visualizer nếu chuyển sang `skwd / Plasma`. Mở khóa các nút điều khiển tương ứng trong `DesktopAddonsPage.qml`.
