# v0.3.4 — oturum adı ve animasyonlu durum maskotları

| Önce | Sonra | Kullanıcıya etkisi |
| --- | --- | --- |
| Kompakt başlıkta yalnızca genel maskot ve sayaç | 30 pt oturum maskotu + 120 pt ad alanı + sayaç; 36 pt başlık, çentikte güvenli yükseklik korunur | Hangi projeye dönüleceği adayı açmadan anlaşılır. |
| Kartta `session.state.symbol` | Aynı oturuma bağlı 44 pt seçili karakter | Soru, çalışma, plan ve izin pozları doğrudan durumun yanında görünür. |
| Açılır listedeki 22×24 pt statik simge | 32 pt oturum maskotu; durum metni korunur | Birden fazla oturumun farklı durumları aynı anda anlaşılır. |
| Başlık yalnızca global `CompanionActivity` kullanır | Bildirimde ilgili oturum; normalde mevcut öncelikli oturum | Başlık adı, kart ve animasyon aynı oturumu gösterir. |

## Arayüz ve davranış

- `SessionPresentation`: sessionID, gizlilik uygulanmış name, state, pose ve yalnızca eşleşen canlı tamamlanmanın celebrationStarted değeri. Kalıcı veri değildir.
- `CompanionResolver.pose(for:celebrating:)` ortak durum eşlemesini sağlar. `AppModel.sessionPresentation(for:)` ve `islandSession(alertSessionID:)` bütün ada yüzeylerini besler.
- Etiket > proje adı önceliği korunur; proje gizleme bütün yeni ad alanlarını ve başlığın erişilebilirlik metnini “Claude Code” yapar.
- Başlık boyutu ada/ekran geometrisine bağlıdır, başlık metnine bağlı değildir. Kamera iki simetrik kanadın arasında boş bırakılır. Kompakt genişlik normal ekranda 352 pt; çentikte çentik genişliği + 352 pt, ekran genişliği −16 pt ile sınırlı. Ad alanı en çok 120 pt.
- Kart maskotu ve her satır kendi oturumunu izler. Ayarlardaki SessionRow varsayılan olarak statik ikon kullanmayı sürdürür. Masaüstü etkinlik paneli ortak oturum listesini kullanır.
- Kutlama mevcut olay kapısından geçer. Aynı oturum/olay tek başlangıç zamanını paylaşır; görüntüyü tekrar oluşturmak veya okundu işaretlemek saati sıfırlamaz. Tekrar teslim ve geçmiş replay yeniden kutlatmaz. Mevcut tek canlı kutlama politikası değişmez.
- Görünmeyen ada/panel ve uyku halinde Timeline durur. Reduce Motion mevcut sabit poz davranışını korur. Yeni ses/bildirim, hook veya tercih şeması yoktur.
- Üste sabitleme, kamera altındaki gerçek giriş şeridi, native header input, mouse fallback, sürükleme eşiği, hover ve bildirim zamanlayıcıları korunur.

## Doğrulama

Yeni testler SessionPresentationTests ve SessionMascotTests içindedir: durumların birbirine karışmaması, ad/etiket/gizlilik, kamera kanatları, bildirimden öncelikli oturuma dönüş, üç karakter/üç tema/uzun ad, compact host yüksekliği, gerçek tamamlanma olayında ortak saat, duplikasyon ve replay, statik ayarlar ikonları ve durum çizimleri.

Önizlemeler gerçek üretim SwiftUI görünümlerinden render edilir. 84 PNG ve 30 GIF üretilir; bunların 42’si karakter/tema/durum bildirimleri, 6’sı oturum listesi içindeki animasyonlardır. Altı liste GIF’i de 16 kare / 10 farklı kare içerir. Bunlar canlı WindowServer/FPS testi değildir.

Canlı fiziksel ekran, masaüstündeki pointer, çoklu ekran, Spaces/tam ekran ve Instruments CPU/FPS kabulü bekler. Paketli açılış bu ortamda LaunchServices -10827 verdi; paket içinden render CLI exit 134 verdi, SwiftPM release renderı başarılıdır. Ad-hoc imza yerel kullanıma yöneliktir; Developer ID/notarization yapılmadı.
