# Dev Island v0.3.2 — görünür üst sabitleme

| Önce | Sonra | Etki |
| --- | --- | --- |
| Üst konuma dönüş yalnızca sağ tık/ayarlar | Serbest adada görünür pin düğmesi | Tek tıklamayla ekranın üst ortasına sabitlenir |
| SwiftUI hover takibi | NSHostingView üzerinde activeAlways takip alanı | Başka uygulama odaktayken hover alır |
| Sürükleme sonrası hover baskısı | Sabitlemede etkileşim durumunun sıfırlanması | Üstteki ada hover veya tıklamayla açılır |

Pin düğmesi native NSButton’dır; sürükleme overlay’inin altına gömülmez. Kendi hit alanı sürükleme/tıklama eylemlerinden ayrıdır. Sadece serbest konumda görünür; tooltip ve erişilebilir ad TR/EN’dir. Üste sabitleme listeyi kompakt hale getirir; sonra hover 120 ms ile açar ve çıkışta 400 ms ile kapatır. Tıklanan liste çıkışta açık kalır; tekrar tıklama veya Escape ile kapanır.

Takip alanı panelin tamamını ve yeniden boyutlanan görünür alanını izler, animasyon boyunca aynı NSTrackingArea korunur. Özel olaylar yalnızca kendi sahibi tarafından işlenir; SwiftUI’nin diğer tracking olayları super’a bırakılır. Çentik güvenli alanı ve sürükleme davranışı korunur.
