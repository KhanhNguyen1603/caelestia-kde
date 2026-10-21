# Tổng hợp các thay đổi và tối ưu hóa (Customizations & Optimizations)

Tài liệu này tổng hợp toàn bộ các chỉnh sửa, tối ưu hóa và tính năng mới đã được thực hiện trên kho lưu trữ của bạn [caelestia-kde](https://github.com/KhanhNguyen1603/caelestia-kde.git) dựa trên phiên bản phát hành mới nhất **v2.6.3** (`ladybug-me/caelestia-kde`).

> **Phạm vi tài liệu:** Chỉ ghi lại những thay đổi còn tồn tại trong mã nguồn hiện tại. Các thử nghiệm đã bị gỡ hoặc tính năng cũ đã được upstream giải quyết trong hệ thống Desktop Widgets không được liệt kê.

---

## 1. Dọn dẹp giao diện

### 🦖 Trò chơi Khủng Long cổ điển & Thẻ gạt Keep Awake (Ly Cafe)
* **Tệp tin ảnh hưởng:**
  * [DinoGame.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/sidebar/DinoGame.qml)
  * [NotifDock.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/sidebar/NotifDock.qml)
* **Chi tiết:** Mở lại game giải trí khi Sidebar trống thông báo. Mã nguồn `DinoGame.qml` đã được sửa đổi để **chỉ chạy duy nhất chú Khủng Long Pixel gốc**, loại bỏ hoàn toàn chế độ `Caelestia Mode` (chạy ảnh động anime Herta `kurukuru.gif`) — vẫn giữ lại **ảnh Herta đứng tĩnh** `kurukuru_stand.png` vẽ trên nền khủng long. Đồng thời chuyển đổi thẻ gạt ở cuối sidebar thành thẻ **Keep Awake** (biểu tượng ly cà phê ☕) kết nối trực tiếp với service `IdleInhibitor.enabled` để bật/tắt chế độ chống ngủ gật / chống tắt màn hình tự động một cách tiện lợi.

### 🚪 Xóa ảnh động trang trí trong Menu Nguồn (Power Menu)
* **Tệp tin ảnh hưởng:**
  * [Content.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/session/Content.qml)
* **Chi tiết:** Loại bỏ hoàn toàn khung ảnh động trang trí (Herta xoay/Khủng long) nằm ở giữa các nút Đăng xuất và Tắt máy, giúp menu nguồn thẳng hàng dọc tinh tế và mở tức thì.

---

## 2. Chức năng mới & Tự động hóa

### 🔄 Chuyển hướng máy chủ kiểm tra cập nhật & Vô hiệu hóa Prebuilt Shell
* **Tệp tin ảnh hưởng:**
  * [UpdateChecker.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/services/UpdateChecker.qml)
  * [caelestia-check-updates](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/src/bin/caelestia-check-updates)
  * [caelestia-update](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/src/bin/caelestia-update)
  * [08-build-shell.sh](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/scripts/08-build-shell.sh)
  * [update.sh](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/update.sh)
* **Chi tiết:** 
  * Thay thế liên kết hardcode của kho lưu trữ gốc từ `ladybug-me/caelestia-kde` sang repository `KhanhNguyen1603/caelestia-kde` để tự động kiểm tra và tải các bản cập nhật từ Fork của bạn.
  * Thiết lập mặc định `CAELESTIA_FORCE_BUILD_SHELL=1` trong build script để ngăn chặn script tự ý tải file build sẵn từ GitHub release của `ladybug-me`, đảm bảo mọi bản build luôn được biên dịch 100% từ mã nguồn fork của bạn.

### 🎵 Tối ưu hóa Trích xuất Ảnh bìa & Tìm kiếm Lời bài hát Nâng cao
* **Tệp tin ảnh hưởng:**
  * [Players.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/services/Players.qml)
  * [CoverArt.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/components/widgets/CoverArt.qml)
  * [lyrics.hpp](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/plugin/src/Caelestia/Services/lyrics.hpp)
  * [lyrics.cpp](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/plugin/src/Caelestia/Services/lyrics.cpp)
* **Chi tiết:** 
  * **Trích xuất Youtube Thumbnail Toàn năng (`Regex`):** Sử dụng biểu thức Regex toàn năng hỗ trợ nhận diện 100% tất cả các định dạng URL của YouTube (`www.youtube.com`, `music.youtube.com`, `m.youtube.com`, `shorts`, `embed`, `youtu.be`), luôn lấy trực tiếp ảnh thumbnail gốc chất lượng cao từ YouTube.
  * **Khóa cấm iTunes API cho YouTube & Spotify:** Khóa cấm YouTube và Spotify gửi yêu cầu tra cứu sang iTunes API (vì 2 nền tảng này luôn có sẵn ảnh chính chủ), loại bỏ hoàn toàn các lỗi lấy nhầm ảnh rác iTunes khi xem video. Các trình phát nhạc địa phương (VLC, MPV, file mp3...) vẫn giữ nguyên tính năng tra cứu iTunes API khi thiếu ảnh.
  * **Bộ lọc tiêu đề thông minh (`cleanTrackTitle`):** Tự động cắt bỏ các đoạn rác nối `• Ca sĩ` (như `Mùa Don't Đến • Hanja, Dewie`), loại bỏ các cặp ngoặc `(feat...)`, `[Official Video]`, `Remix`, và các ngoặc bỏ dở do bị rút gọn `...`.
  * **Lọc tiêu đề Tạm dừng & Quảng cáo (`isPlaceholderTitle`):** Tự động nhận diện và loại bỏ các chuỗi tạm dừng trình duyệt (`Spotify - Web Player...`) và Quảng cáo (`Spotify – Advertisement`, `quảng cáo`) để giữ nguyên giao diện sạch sẽ, không tìm lời rác cho Quảng cáo.
  * **Tìm kiếm LRCLIB qua Fuzzy Search (`?q=`):** Chuyển sang dùng `?q=cleanTitle` trên LRCLIB giúp tìm kiếm chính xác các bài hát có chứa chữ số hay dấu gạch ngang (như `3107 4`, `3107-4`).
  * **Kiểm tra Thời lượng nghiêm ngặt cho LRCLIB & NetEase (`<= 1.0s`):** Bắt buộc thời lượng bài hát trên cả 2 backend LRCLIB và NetEase Music lệch không quá 1.0s (`std::abs(duration - m_duration) <= 1.0`), loại bỏ hoàn toàn việc bắt nhầm bài hát rác khi xem video.

### 📐 Tách biệt cài đặt bo góc trên và bo góc dưới (Border Rounding)
* **Tệp tin ảnh hưởng:**
  * [borderconfig.hpp](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/plugin/src/Caelestia/Config/borderconfig.hpp)
  * [AppearancePage.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/nexus/pages/wallandstyle/AppearancePage.qml)
  * [BlurCorners.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/drawers/blur/BlurCorners.qml)
  * [ContentWindow.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/drawers/ContentWindow.qml)
  * C++ Blobs plugin shader uniforms
* **Chi tiết:** 
  * Tách thuộc tính cấu hình `GlobalConfig.border.rounding` thành 2 cấu hình riêng biệt: `roundingTop` (bo góc cạnh trên) và `roundingBottom` (bo góc cạnh dưới).
  * Hỗ trợ tinh chỉnh thẩm mỹ độc lập cho thanh bar/panel và viền màn hình theo ý thích cá nhân.

### 🖼️ Hỗ trợ hình nền động sáng/tối & Tự động đồng bộ KDE Plasma
* **Tệp tin ảnh hưởng:**
  * [Wallpapers.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/services/Wallpapers.qml)
* **Chi tiết:** 
  * Tự động nhận diện biến thể hình nền sáng/tối (`contents/images/` <-> `contents/images_dark/` theo chuẩn KDE Wallpaper Package, hoặc các quy ước hậu tố `_dark`/`_light`, `-dark`/`-light`, `.dark`/`.light`, `_night`/`_day`).
  * Tự động tráo đổi hình nền tương ứng và đồng bộ sang desktop KDE Plasma khi người dùng chuyển đổi giữa chế độ Light và Dark.

### 🖥️ Tùy biến biểu tượng & Lưới màn hình nền (Desktop Icons & Grid)
* **Tệp tin ảnh hưởng:**
  * [DesktopLayout.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/services/DesktopLayout.qml)
  * [DesktopIcons.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/background/DesktopIcons.qml)
  * [ViewOptions.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/background/desktopicons/ViewOptions.qml)
  * [DesktopPage.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/nexus/pages/DesktopPage.qml)
* **Chi tiết:**
  * **Kích thước biểu tượng Super Small (32px):** Bổ sung thêm tùy chọn 32px vào danh mục kích thước biểu tượng desktop (cùng với Small 48px, Medium 64px, Large 96px, Huge 128px), giúp người dùng sắp xếp gọn gàng nhiều file/thư mục mà không chiếm diện tích màn hình.
  * **Rút gọn lề lưới desktop (Base Margin 8px):** Tinh chỉnh khoảng cách lề cơ bản từ 32px xuống 8px (`Tokens.padding.small * root.effectiveScale`), tối đa hóa vùng hiển thị lưới ứng dụng trên mọi kích cỡ màn hình.

### 💻 Hỗ trợ tương thích đa dạng Terminal Emulator cho ứng dụng dòng lệnh (CLI Apps)
* **Tệp tin ảnh hưởng:**
  * [Launch.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/utils/Launch.qml)
  * [UpdatesPage.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/nexus/pages/UpdatesPage.qml)
  * [CalcItem.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/launcher/items/CalcItem.qml)
  * [Dock.qml](file:///home/qkhanh/Code/Kde%20caelestia/caelestia-dots-kde/shell/modules/bar/components/Dock.qml)
* **Chi tiết:**
  * **Tự động chèn cờ thực thi (`-e` / `--`):** Khắc phục lỗi khi mở các ứng dụng CLI (như Neovim, htop, btop...) được ghim trên Dock hoặc tìm từ Launcher khi người dùng thiết lập terminal mặc định là Ghostty, Alacritty, Konsole, Kitty, WezTerm hoặc GNOME Terminal / Ptyxis.
  * Tự động bổ sung cờ `-e` cho các terminal theo chuẩn POSIX/xterm (hoặc `--` cho họ GNOME) khi chạy script `wrap_term_launch.sh`, đồng thời vẫn bảo đảm mở terminal trống bình thường qua phím tắt hay menu chuột phải.
  * **Ngăn chặn kẹt hiệu ứng xoay (spinner) trên Dock:** Khi mở ứng dụng CLI (`runInTerminal`), Dock không kích hoạt hiệu ứng xoay, loại bỏ triệt để lỗi icon Neovim/CLI bị xoay vĩnh viễn trên thanh dock do cửa sổ terminal mở lên không trùng định danh appClass.
