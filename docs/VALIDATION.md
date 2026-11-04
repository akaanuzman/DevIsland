# Dev Island 0.4.1 — doğrulama

- Swift XCTest: **132 toplam; 131 başarılı, 1 fiziksel ekran testi atlandı, 0 hata**.
- Altı yeni pinli Taşı testi native host üzerinde başarılı; tam paket sonrasında tekrar çalıştırıldı.
- VS Code connector: **11 başarılı test**; önceki kullanıcı değişiklikleri korundu.
- Yayın/gerçek Sparkle EdDSA testleri: **5 başarılı test**.
- Release arm64, paketli bridge/naming (10 eşzamanlı oturum), SwiftData round-trip, oturum adı ve bekleme durumunun korunması, özel önizleme metninin diske yazılmaması başarılı.
- codesign --verify --deep --strict ve ZIP bütünlüğü başarılı; imza ad-hoc, Developer ID/notarization yok.
- Pinli ada açık/koyu PNG’lerinde yeni Taşı alanı görsel olarak kontrol edildi. Kompakt yüksekliğe ek boşluk eklenmedi. Native düğme snapshot’ta aynı boyutlu etiketle temsil edilir.
- Canlı CUA uygulama açılışı -10005 timeoutReached nedeniyle doğrulanamadı. WindowServer fiziksel NSScreen sunmadığından ilgili XCTest atlandı. Gerçek mouse/trackpad, menü çubuğu, Spaces, fiziksel ekranlar ve odak davranışı canlı kabul bekliyor. Önceki LaunchServices -10827 kontrolü bu tur yeniden çalıştırılmadı.
- Uzaktan güncelleme yerel pakette kapalı; Developer ID Application, GitHub Secrets/Pages ve iki imzalı beta arasındaki gerçek güncelleme kabulü bekliyor.

[Kullanım ve değişiklikler](V041_PINNED_DRAG.md) · [Yayın kurulumu](UPDATES.md)
