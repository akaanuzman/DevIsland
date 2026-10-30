# v0.3.3 — üst konumda fare olaylarının kaybolması

Kullanıcı bildirimi: serbest konumda çalışıyor, yalnızca üste sabitliyken hover ve tıklama büyütmüyor.

## Doğrulanan bulgular

Gerçek NSHostingView ağacında başlık 340×38 pt olarak yerleşiyor, hitTest HeaderInputView döndürüyor ve mouseDown/mouseUp liste callback’ine ulaşıyor. Yani sorun yalnızca callback’in varlığı değil, sistemin olayı bu pencereye teslim etmesi.

Eski controller ile gerçek NSPanel seviyesi testte **3** çıktı. Başta verilen statusBar ayarından sonra isFloatingPanel kullanımı pencereyi floating seviyesine taşıyordu. Sistem menü/status pencereleri 24/25 seviyelerindedir; üstteki ada görünse bile onların altında kalabiliyordu. Aynı testte çentik yüksekliği ile toplam kompakt yükseklik eşitti (38 pt): kameranın altında gerçek bir hedef alan yoktu.

Düzeltme öncesi iki assertion başarısız, sonrasında geçti. Bu, kod/yapılandırma kusurunun tekrar üretimidir; kullanıcının masaüstündeki canlı olay kaydı değildir. Canlı UI bağlantısı bu ortamda timeout verdi.

| Önce | Sonra | Etki |
| --- | --- | --- |
| Panel seviyesi 3 | Üstte statusBar + 1; serbest halde floating | Sistem çubuğuyla çakışan üst pencere sıralaması düzelir |
| Kompakt alan kamera yüksekliği kadar | Kameranın altında 6 pt gerçek şerit | Üst ortada kullanılabilir hover/tıklama hedefi kalır |
| Yalnızca pencereye teslim edilen olaylar | Üstte mouse-only dış hareket takibi ve kamera alanına sınırlı click fallback | Çentik/sistem çubuğu alanındaki olaylar da işlenir |

Dış click fallback yalnızca fiziksel kamera dikdörtgenindedir. Kamera dışındaki diğer uygulama menüsü/status item tıklamaları işlenmez, olaylar tüketilmez. Klavye izlenmez; fare verisi saklanmaz veya gönderilmez. Serbest konumda fallback kapalıdır; normal AppKit giriş yolu korunur. Panel gizlenince/kapanınca monitor kaldırılır.

Eski uygulama arka planda çalışırken yeni kopyayı açmak eski süreci kullanmaya devam edebilir. Yeni sürümü denemeden önce Dev Island menüsünden Çık seçilmelidir.
