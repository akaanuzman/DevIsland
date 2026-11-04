# Dev Island 0.4.1 — üste sabitliyken taşıma

## Kullanım

Adanın üzerine gel veya tıkla. Oturum listesi/bildirim kartındaki **Taşı** alanını sürükle. Tek tıklama adayı üstten ayırıp menü çubuğunun altına indirir. Floating başlıktaki pin düğmesi yeniden üst ortaya sabitler. Eski uygulamadan Çıkıp 0.4.1 kopyasını açmak gerekir.

| Before | After | What this changes |
| --- | --- | --- |
| Pinli başlık menü çubuğu hizasında; kamera altında yalnızca 6 pt erişim alanı | Açılan panelde menü çubuğunun tamamen altında 64×32 pt Taşı hedefi | Dar üst bölgeyi yakalamadan tek hareketle ayırıp taşıma |
| Üstteki dar başlıktan ayırma zorunluluğu | Taşı alanına tek tıkla visibleFrame.maxY − 16 konumuna ayırma | Önce serbest alana alıp normal başlıktan taşıma alternatifi |
| Gövde noktası header oranına sıkıştırılabiliyordu | Gövdenin gerçek x/y tutma mesafesi saklanır | Çentik başlığı 44→36 pt değişirken tutulan nokta imleç altında kalır |
| Her native input güncellemesi Escape iptal hedefini değiştirebilirdi | İptal hedefini yalnızca mouse-down sahibi belirler | Üst başlık yenilense de gövdedeki taşıma doğru iptal olur |
| AppKit varsayılan pencere hareketi devreye girebilir | isMovable=false, isMovableByWindowBackground=false, mouseDownCanMoveWindow=false | Pencereyi tek sürükleme koordinatörü taşır |

Kompakt yükseklik büyümedi; hook sözleşmesi, tercihler, maskotlar, renkler, pin, bildirim ve animasyon zamanlayıcıları korunur. Native borderless düğme, ImageRenderer önizlemelerinde aynı boyutlu çizilmiş etiketle temsil edilir; gerçek uygulama native düğmeyi kullanır.

## Doğrulama

Tam Swift paketi: **132 test; 131 başarılı, 1 fiziksel NSScreen testi atlandı, 0 hata**. Altı yeni test gerçek NSPanel/NSHostingView içindeki Taşı inputunu bulur: hedefin dört köşesi, menü altı konumu, native mouse-down/drag/up, tek tıkla ayırma, header güncellenirken Escape sahibinin korunması, yukarı açılan floating panel ve bildirim kartı. Son önizleme düzenlemesinden sonra bu altı test ayrıca tekrar geçti.

11 VS Code testi ve 5 yayın testi başarılı. Paketli bridge/naming/SwiftData, 10 eşzamanlı köprü süreci, codesign --verify --deep --strict ve ZIP bütünlüğü başarılı.

Canlı CUA açılışı denendi; getApp(dist/Dev Island.app) **-10005 timeoutReached** verdi. Son uygulama envanterinde Dev Island doğrulanamadı. Fiziksel mouse/trackpad, gerçek menü çubuğu ve farklı ölçekli ekranlarda canlı kabul bekliyor. Bu turdaki native host testleri veya PNG/GIF önizlemeleri fiziksel masaüstü doğrulaması olarak sayılmıyor.

Paket yerel ad-hoc build 12’dir; resmi uzaktan yayın değildir. Developer ID/Secrets/Pages ve beta güncelleme kabulü UPDATES.md’deki önceki dış kurulumları bekler.
