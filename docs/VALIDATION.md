# Dev Island v0.3.6 — doğrulama

- 104 XCTest: 103 başarılı, fiziksel NSScreen isteyen 1 test skip, 0 hata. Eski 99 test ve yeni 5 native routing testi.
- 9 Node eklenti testi: hepsi başarılı. Gerçek yerel socket'ler ve sahte VS Code nesneleriyle iki pencere/aynı isim, yanlış token/PID/UUID, kapanma/eksik PID, focus hatası, özel izinler ve bozuk/büyük girdi doğrulandı.
- Gerçek kullanıcı VS Code host'larıyla 3 pencere / 5 Claude terminali: hepsi başarılı. Native production EditorRouteClient PID/doğum zamanı ve üst süreçleri doğruladı; pencere/terminal UUID yanıtı, gerçek aktif terminal ve window.state.focused doğrulandı. Aynı pencerede 3 ayrı Claude terminali seçildi. Terminal komutu veya prompt gönderilmedi. Paketli .app executable içinden bir gerçek terminal dönüşü de geçti (PACKAGED-ROUTING.json). LIVE-ROUTING.json kanıttır; UI mock değildir.
- VSIX izole kurulum kontrolü ve gerçek kullanıcı CLI kurulumu başarılı. Mevcut üç VS Code penceresi eklentiyi yükledi; otomatik reload yapılmadı. Yeni native app kopyası kullanılmalıdır.
- Gerçek paket köprüsü, 10 oturum Unix socket/sessiz fail-open/isim aktarımı, isim fallback/rename ve SwiftData isim+bekleme saklama kontrolleri geçti. App/VSIX/ZIP bütünlüğü ve ad-hoc imza doğrulandı.
- Üretim SwiftUI görünümlerinden güncel ayarlar/ada/maskot önizlemeleri üretildi. Bunlar canlı cihaz animasyonu/FPS kanıtı değildir.

Native UI aracı zaman aşımına uğradı; izole Code GUI test host'u sonuç üretmedi. Buna karşın mevcut kullanıcı VS Code host'larında gerçek API üzerinden hedef seçimi doğrulandı. Adadaki düğmeye fiziksel fareyle basma, çentik/Spaces/tam ekran, Instruments CPU/FPS, ikinci Mac ve Developer ID/notarization kabulü ayrıca bekler. Kaynak/tercihler/Claude hook kuralları korunur. Kullanıcının VS Code eklenti ve kurulum kayıtları yalnızca onaylanan yerel VSIX kurulumuyla güncellendi; projelere veya terminallere metin yazılmadı.

Detay: V036_VSCODE_ROUTING.md. Ham sonuçlar: TESTS.txt, NODE-TESTS.txt, LIVE-ROUTING.json, VSIX-INSTALL.txt, BRIDGE.json, NAME-BRIDGE.json, STORAGE.txt.
