# Dev Island v0.3 — doğrulama kaydı

Tarih: 30 Ekim 2026, Europe/Istanbul. Ana kaynak: /Users/kaanuzman/Desktop/dev/DevIsland.

## Otomatik kontroller

**55 XCTest, 0 hata.** Önceki 40 test korunur; yeni kapsam:

- Eski varsayılan turuncuya taşınır, diğer özel renkler ve bildirim/terminal ayarları korunur. v3’te özellikle seçilen eski teal sonraki açılışta değiştirilmez.
- Clawd/Kedi/Robot seçimi, karakter başına renk ve uygulama rengini izleme JSON round-trip ile doğrulanır. Bilinmeyen karakter eski ayarları silmez.
- Açık/koyu içerik yüzeylerinde birincil, ikincil ve türetilmiş vurgu metni en az 4,5:1 kontrast verir. Siyah, beyaz, sarı, yeşil ve özel renkler test edilir. Ham dolgu üzerinde karşıt açık/koyu yazı seçilir. Bu, gerçek masaüstü camının her olası arka planında ölçüm yapıldığı anlamına gelmez.
- Üç silüetin kulak/anten/gövde/prop bölgeleri, saydam köşeleri ve sıfır boyutlu hit maskesi test edilir. Önceki kutlama, mute/snooze ve restore testleri geçer. Üç karakterin sekiz pozunda, salt okunur macOS Reduce Motion girdisi çiziciye kontrollü verilerek iki farklı örnek zamanın piksel çıktısı karşılaştırılır: 24 karşılaştırmada hareket yoktur. Sistem ayarı değiştirilmez.
- **Gerçek NSHostingView ve NSPanel:** 10 oturumun görünmeyen gövdesi hâlâ bağlıyken 330×36 pt kompakt pencere, layout ve run-loop sonrasında 36 pt kalır. Host sizingOptions boş; pencerenin örtük minimum yüksekliği 0’dır. İçerik host ölçümü ayrıca 36/38 pt başlıklarda denenir.
- Gerçek SwiftUI içerik ölçümü: 0 oturum 142 pt; 1 oturum 145 pt; 3 oturum 255 pt; 10 oturum 640 pt doğal gövde yüksekliği. 10 oturumda 520 pt viewport sınırı uygulanır. Bunlar İngilizce/460 pt test düzeninin ölçüleridir; diğer diller/ekranlarda yeniden ölçülür. Maskot paneli de kendi içeriğinden ölçülür.
- Uzun proje adı, etiket değişimi, aynı hedef, kesilmiş geçişte tersine dönme, geçersiz hover zamanlayıcıları ve 1 pt ölçüm yuvarlamasında yeniden animasyon başlatmama test edilir.
- ThemeCoordinator gerçek NSWindow ve bağlı NSPanel üzerinde koyu → açık → sistem → koyu geçirir. İki pencerede görünüm birlikte değişir; sistemde override kaldırılır. Native labelColor koyuda açık, açıkta koyu çözümlenir.

## Paket ve yerel veri

- arm64 release uygulama ve nested köprü derlenir; minimum macOS 14. Yeni 1024 px di ikonu ve küçük ICNS boyutları ortak vektörden üretilir.
- Yerel ad-hoc imza codesign deep/strict kontrolünden geçer. Bu Developer ID/notarization değildir.
- Gerçek paket köprüsüyle 10 eşzamanlı süreç, Unix socket, uygulama kapalıyken disk kuyruğu, metadata gizliliği, 0600 izinler, bozuk/büyük girdi ve sessiz exit 0 kontrolü geçer.
- Son köprü smoke kaydı: offline 175,46 ms; canlı süreç başına ortalama 30,70 ms; eşzamanlı grubun aktarımı 48,16 ms. Bunlar görünür adaya kadar uçtan uca ölçüm değildir. Ham kayıt bridge-smoke.json içindedir.
- SwiftData ikinci repository ile round-trip geçer: soru beklemesi ve korelasyon korunur, soru önizlemesi diske yazılmaz. Sandbox’ta CoreData store-change notification kayıt uyarısı görülebilir; veri testi başarılıdır.

## Görsel çıktılar

- Altı ayar sayfasının açık/koyu önizlemeleri **NSHostingView.cacheDisplay** ile gerçek native sidebar, GroupBox, picker, toggle ve metin alanlarından üretilir. Etkin olmayan, ekran dışında bir pencere çizimidir; tam uygulamanın canlı kullanımı değildir.
- Ada ve maskot paneli: açık/koyu × Liquid Glass/buzlu/opak için 12 ImageRenderer çıktısı. Kompakt ada ayrıca 180×36 pt olarak çizilir; PNG’ler 2× ölçektedir.
- Kedi ve Robot için özel renkli ayar/ada örnekleri; üç karakterin sekiz pozu ve beş gövde rengi örneği.
- Üç karakter × sekiz durum için 24 GIF. Tanıtım GIF’leri döngülüdür; uygulamadaki tamamlanma kutlaması bir kez oynar. Reduce Motion uygulamada pozları sabitler.
- ImageRenderer panel örneklerinde ScrollView/menu snapshot karşılığı ve camın statik temsili bulunur. Gerçek desktop arka planı veya pencere geçişi FPS’i bu resimlerden doğrulanmaz.

## Paketlenmiş uygulamanın canlı kabulü

Bu turda .app açılışı LaunchServices **kLSNoExecutableErr (-10827)** döndürdü. Executable dosyası mevcut; arm64 derleme ve imza doğrulanır. AppKit host/pencere ve native çizim kontrolleri geçse de LaunchServices üzerinden tam uygulama çalıştırma kabulü bu ortamda engelli kalır.

Dolayısıyla şu maddeler **bekliyor**:

- Paketlenmiş uygulamada gerçek hover/aç-kapa akıcılığı, çentik hizası, klavye odağı ve maskot sürükleme/tıklama geçişi.
- Gerçek OS tema değişikliği, menüler/sheet’ler ve Liquid Glass’ın canlı masaüstü arka planı; macOS 14/15 fallback runtime kontrolü.
- Ekran çıkarma, çoklu ekran, tam ekran/Spaces, uyku/uyanma ve fiziksel VoiceOver kullanımı.
- Instruments ile kare süreleri, boşta CPU/enerji ve %1 CPU hedefi.
- Dört terminalde gerçek Claude uçtan uca senaryoları, izin reddi akışları ve temiz ikinci Mac.
- Developer ID, notarization, Gatekeeper ve imzalı DMG kabulü. Teslim ZIP’i yerel ad-hoc pakettir.

Normal macOS oturumunda uygulamayı açıp Görünüm’den tema, karakter ve renkleri değiştir; kompakt adanın altında yüzey kalmadığını, hover sırasında bildirim süresinin durduğunu ve sürükleme/tıklama geçişini doğrula. Mevcut Claude ayarlarına bu geliştirme turunda otomatik hook kurulumu yapılmadı.
