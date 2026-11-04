# Dev Island — ilerleyen fazlar

İlk sürüme bağımlılık oluşturmayan gelecek işlerin kaydı. Mobil bildirim ilk fazdan bilinçli olarak çıkarıldı. Sağlayıcı seçimi henüz yapılmadı.

## Faz 1.5 — dağıtılabilir beta kabulü

- Gerçek Claude oturumlarını VS Code, Cursor, Warp ve Apple Terminal’de test et.
- Bildirim/Automation izinlerinin reddedilmesi ve sonradan verilmesi.
- İkinci, temiz Apple Silicon Mac; macOS 14 tabanı ve güncel macOS.
- Çentik, harici ekran, kapak kapalı kullanım, Spaces, tam ekran, uyku/uyanma.
- VoiceOver ve klavye akışlarının fiziksel doğrulaması.
- Instruments ile CPU, enerji, disk yazımı ve 1 saniyelik canlı olay hedefi.
- Developer ID sertifikalarıyla imza, notarization, staple, temiz makinede Gatekeeper doğrulaması.
- Ürün adı ve dağıtım kimliğini kesinleştir. v0.3 özel di monogramını, turuncu kimliği ve üç piksel maskotu içerir.

## Faz 2 — v0.2/v0.3 kaynak uygulaması tamamlandı

- Ortak durum motoruyla çalışan native piksel Clawd.
- Ada, masaüstü ve ayarlar için aynı çizim bileşeni.
- Çalışma, soru, plan, izin, tek seferlik kutlama, hata ve bağlantı kesilmesi pozları.
- Sürükleme, kalıcı konum, boyutlandırma ve şeffaf alanlarda mouse geçişi.
- Ada + maskot / yalnızca ada / yalnızca maskot; ikinci bildirim/ses yok.
- Tema ve malzeme ayrı; macOS 26 Liquid Glass, eski sürümlere frosted fallback.
- Canlı cihaz, enerji, çoklu ekran ve erişilebilirlik kabulü VALIDATION.md üzerinden izlenir.

v0.3: Clawd, Kedi ve Robot; karakter başına renk, uygulama rengini izleme, kendi silüetine göre hit maskesi. Sade macOS arayüzü, tema koordinatörü ve ölçülen kompakt ada yerleşimi eklendi.

Sonraki maskot genişlemeleri: kullanıcının sprite yüklemesi ve isteğe bağlı gezinme. Bunlar v0.3 kapsamı değildir.

## Faz 3 — telefona bildirim

### Kullanıcı ihtiyacı

Mac’ten uzaktayken “proje soru/plan/izin bekliyor” veya “yanıt tamamlandı” uyarısını telefonda görmek. İlk mobil sürüm yalnızca bildirim ve durum gösterimi hedefler; uzaktan komut/izin onayı ayrı bir ürün kararıdır.

### Araştırılan yollar

| Yol | Avantaj | Gereksinim / sınır |
| --- | --- | --- |
| Pushover | iOS ve Android; Mac’ten doğrudan HTTPS; kendi sunucumuz olmadan küçük pilot | Üçüncü taraf uygulama, kullanıcı anahtarları ve güncel ücret/kota kontrolü |
| Kendi web uygulamamız + Web Push | Kendi ürün deneyimi, mağaza uygulamasına ihtiyaç olmadan | Eşleştirme/backend/push aboneliği; iPhone’da ana ekrana eklenmiş web uygulaması |
| Kendi iOS/Android companion uygulamamız | QR eşleştirme ve en bütünleşik deneyim | Ayrı mobil uygulama, APNs/FCM, backend, mağaza ve sürekli bakım |

Pushover’ın planlama araştırmasında görülen bireysel fiyatı platform başına tek seferlik 4,99 USD idi. Bu yalnızca 29 Ekim 2026 araştırma notudur; faz açıldığında fiyat ve hizmet şartları yeniden doğrulanır. iOS ana ekran Web Push desteği 16.4+ ile belgelenmiştir; hedef sürümler yine güncel belgelerle doğrulanır.

### Faz açıldığında kararlaştırılacaklar

- Sağlayıcı ve telefon işletim sistemi kapsamı.
- Mac/telefon eşleştirmesi, anahtarların Keychain’de tutulması, iptal ve cihaz kaybı.
- Varsayılan payload yalnızca durum; proje adını paylaşma ayrı tercih. Kod/komut/soru gönderimi varsayılan kapalı.
- Çevrimdışı kuyruk, tekrar engelleme, teslim süresi ve eski bildirimin sona ermesi.
- Kullanıcı Mac’te aktifken mobil uyarıların azaltılması.
- Mac uyurken yeni yerel Claude olayı üretilemeyeceğinin açık anlatılması.
- Push tesliminin garanti olmadığının ürün davranışına yansıtılması; uzaktan eylem hedeflenirse ayrı kimlik doğrulama tasarımı.

Kaynaklar: [Pushover API](https://pushover.net/api), [Pushover fiyatlandırma](https://pushover.net/pricing), [WebKit iOS Web Push](https://webkit.org/blog/13878/).

## Daha sonraki uyumluluk işleri

- VS Code için tamamlandı (v0.3.6); Cursor eklentisiyle doğru terminal paneline dönüş sonraki uyumluluk kapsamıdır.
- Warp mevcut pane/sekme yönlendirmesi için yeni resmî API çıkarsa adaptör.
- Intel/macOS sürüm matrisi ve universal binary.
- SSH, tmux, uzak Claude oturumları; oturum sahibine dönüş protokolü.
- Diğer ajanlar için sağlayıcı adaptörleri; izin ve tamamlanma sözleşmelerini ayrı doğrula.
- v0.4 güncelleme altyapısının gerçek Developer ID/Pages kurulumu ve iki imzalı beta arasında uçtan uca kabulü; otomatik geri alma ileride ayrı değerlendirilecek.

## v0.3.1 — eklenen yerel etkileşimler

Üst kenara yapışan ada; kalıcı sürükle-bırak konumu, yukarı açılan panel, varsayılan konuma dönüş, gülümseyen kedi ve ayrı renk sıfırlama eylemleri kaynakta eklendi. Fiziksel ekran/LaunchServices engeli nedeniyle canlı kabul VALIDATION.md üzerinden ayrıca izlenir.

### v0.3.4 — oturum sunumu
Kompakt oturum adı, bildirim ve oturum satırlarında oturuma özgü animasyonlu maskotlar eklendi. Hook ve kalıcı tercih şeması korunur. Fiziksel ekran/pointer, Focus, gerçek terminal senaryoları ve Instruments ölçümü dağıtılabilir beta kabulüne dahildir.

### v0.3.5 — gerçek Claude adları
Hook session_title ve yerel kayıtların oturum kimliğiyle eşlenmesi eklendi. İzlenen mevcut oturumlarda ad tamamlama/yeniden adlandırma, gizlilik ve eski kayıt uyumluluğu korunur. Yerel kayıt formatları sürüm değiştikçe uyumluluk testleri güncellenmelidir. Serbest VS Code tab başlığını okuma, Accessibility/ekran tarama kapsamı değildir.

### v0.3.6 — VS Code tam pencere/terminal dönüşü
VS Code local macOS için pencereye özel VSIX ve PID ancestry/instance eşlemesi tamamlandı; gerçek 3 pencere/5 terminalde doğrulandı. Cursor ve diğer IDE'lerde aynı düzey, remote/SSH/dev-container ve tmux paneli sonraki uyumluluk işleridir. Native ada düğmesinin fiziksel mouse kabulü, ikinci Mac ve imzalı dağıtım ayrıca takip edilir.

### v0.3.7 — maskot ve kapatma
Masaüstü maskotu için açık görünürlük/konum kurtarma eylemi, 32 pt native kapatma hedefi ve kapatma sonrası hover koruması eklendi. Mevcut renkler, VS Code yönlendirmesi ve hook takibi korunur. Fiziksel masaüstü/Spaces/FPS kabulü sürer.

### v0.4 — güvenilir taşıma ve güncelleme altyapısı
Basma anında duraklayan hover/alert zamanlayıcısı, noktalı başlık tutamağı, imlece bağlı taşıma ve bırakma sonrası hover doğrulaması eklendi. Sparkle 2.9.6, tek kaynak sürüm/build bilgisi, stable/beta seçenekleri, resmi yayın iş akışı ve ayarlara dokunmayan atomik köprü yenilemesi kaynakta hazır. Developer ID Application sertifikası, GitHub release ortamı/Secrets, açık dağıtım deposu, Pages ve iki imzalı beta arasındaki gerçek güncelleme kabulü dış kurulum bekler. Yerel paket bu işler bitene kadar güncelleme kontrolü başlatmaz.

### v0.4.1 — pinli ada için erişilebilir taşıma
Oturum ve bildirim panelinin menü altında kalan 64×32 pt Taşı alanı, tek tıkla ayırma, gerçek gövde tutma noktası ve aktif inputa ait Escape iptali eklendi. Kompakt boyut değişmedi. Altı native host testi geçti; fiziksel mouse/trackpad ve Spaces kabulü CUA erişim engeli nedeniyle bekliyor.
