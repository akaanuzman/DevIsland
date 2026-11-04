# v0.3.7 — masaüstü maskotunu geri getirme ve kolay kapatma

## Kullanıcı sorunu ve değişiklik

Masaüstü maskotu için incelenen kullanıcı kaydında companionVisibility=both fakat mascotHidden=true bulundu. Renk, boyut ve kayıtlı konum geçerliydi. Kullanıcı masaüstü karakterini geri istedi; maskot görünürlüğü ayrı bir yerel tercih onarımıyla açılır, diğer tercihleri sıfırlayan migration eklenmez.

| Önce | Sonra | Kullanıcıya etkisi |
| --- | --- | --- |
| Gizli maskotta yalnızca konum sıfırlama eylemi | Görünüm'de “Maskotu göster ve konumunu sıfırla” + gizli durum açıklaması | Yalnızca ada seçilmiş veya maskot gizlenmiş olsa da tek eylemle geri gelir; boyut ve renk korunur. |
| 10 pt X simgesi, açıkça tanımlanmamış tıklama alanı | Native NSButton, 12 pt simge ve 32×32 pt gerçek hedef; hover çerçevesi, ilk tıklama, AX etiketi ve Escape | Başka uygulama odaktayken simgenin kenarlarına yapılan ilk tıklama da çalışır. |
| Açık panel kapanırken gelen hover olayları tekrar açılma oluşturabilir | Kullanıcı kapatmasında kapanış süresince hover kilidi; pointer kompakt alanda kalırsa çıkışa kadar engel | X/Escape/başlığa tekrar tıklama sonrası ada hemen geri açılmaz. |

Aynı kapatma bileşeni bildirim kartı, açılan oturum listesi ve masaüstü maskotunun panelinde kullanılır. Native hosting view ilk fare tıklamasını kabul eder. Cam ve kenar çizgileri etkileşime katılmaz. İçerik yüksekliği yeni 32 pt kontrolle gerçek görünümden ölçülür; kompakt ada yüksekliği ve sıfır gövde davranışı korunur.

## Davranış

- `Preferences.showDesktopMascot(resetPosition:)`: gizliyi kaldırır; yalnızca ada modundan ada+maskot moduna geçer; yalnızca istenirse maskot konumunu sıfırlar. Vurgu, karakter ve diğer karakter renkleri, boyut, ada konumu, bildirimler ve terminal tercihleri korunur.
- Menüdeki Maskotu göster de aynı görünürlük politikasını kullanır. Normal açılışta kullanıcının bilerek gizlediği maskot otomatik açılmaz. Bu kullanıcıya uygulanan düzeltme açık talebine özeldir.
- `IslandCloseControl` gerçek AppKit kontrolüdür; 32 pt hedefin dört köşesi ve gerçek host ağacındaki konumu test edilir. Native erişilebilirlik etiketi Türkçe/İngilizce; Escape, Tab/Space ve hover görünümü standart AppKit davranışını kullanır. Statik render, native kontrol için SwiftUI simge karşılığını çizer.
- `IslandController.dismiss()` X/Escape/başlıkla kapatmada çağrılır. Açılıp kapanma koordinatörü değiştirilmez. Kapanış süresi +60 ms boyunca yeniden boyutlanmadan doğan hover olayları atlanır. Sonrasında pointer kompakt panelin içindeyse gerçek çıkış beklenir; dışındaysa sonraki hover açılabilir.
- Açıkça yeniden açma, yeni dikkat bildirimi, sürükleme veya panelin gizlenmesi önceki kapatma görevini iptal eder. Eski görev yeni liste/bildirimi kapatamaz. Otomatik 8 saniyelik bildirim süresi ve hover duraklaması korunur. Yeni global mouse/keyboard dinleyicisi eklenmez.
- Native hitTest testi noktaları [Apple'ın tanımladığı superview koordinatlarına](https://developer.apple.com/documentation/appkit/nsview/hittest%28_%3A%29) dönüştürür. İlk testteki koordinat hatası düzeltilmiştir; standart AppKit hedef seçimi kullanılır.

## Doğrulama

114 XCTest: 113 başarılı, fiziksel NSScreen isteyen 1 eski test skip, 0 hata. Yeni 10 test: maskot görünürlüğü/konumu/ayar koruması, eski gizli tercihin korunması, kaydet/aç, üç karakterin masaüstü render'ı, 32 pt kontrolün ilk tıklaması ve native hit hedefi, maskot panelindeki aynı kontrol, kapanış sırasında hover, pointer içerde/dışarda davranışı ve eski görevin açık liste/yeni bildirimi bozamaması.

Mevcut çalışan kopyada yapılacak görünürlük onarımı yalnızca görünürlük alanlarını değiştirir; ham tercih yedeği work altında kalır, teslim paketine konmaz. MASCOT-PREFERENCE-RESTORE.json yalnızca değişen anahtarları ve diğer tercihlerin korunduğunu kaydeder.

Bu iş başlarken extensions/vscode altındaki 4 dosyada bulunan kullanıcı değişiklikleri korunur. Mevcut 0.1.1 eklenti kaynağının 11 Node testi geçer; bu düzeltme VS Code eklentisini değiştirmez veya yeniden kurmaz. Yeni app paketi mevcut kaynak ağacındaki VSIX'i taşır.

Paket imzası/ZIP, gerçek hook köprüsü, isim fallback/rename ve SwiftData kontrolü ayrıca çalıştırılır. Önizlemeler üretim SwiftUI render'larıdır. Kullanıcının masaüstünde yeni maskot penceresini fiziksel olarak görmek veya X'e fiziksel fareyle basmak bu ortamda tamamlanmış sayılmaz; native kontrol/hitTest ve durum akışı in-process doğrulanmıştır. Fiziksel ekran, Spaces/tam ekran, CPU/FPS ve Developer ID/notarization kabulü ayrı kalır.
