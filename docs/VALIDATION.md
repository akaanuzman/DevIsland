# Dev Island v0.3.4 — doğrulama

88 XCTest: 87 başarılı, fiziksel NSScreen gerektiren 1 test atlandı, 0 hata. Önceki 81 test korunur; oturum sunumu için 7 test eklenir. Yeni çoklu oturum durum/isim/gizlilik, gerçek tamamlanma saati ve tekrar teslim, render, başlık geometri testleri geçti. Mevcut sürükleme, pin, native hitTest, hover, kesilebilir geçiş, tema, tercihler, 3 karakter ve Reduce Motion testleri de geçti.

Apple Silicon release derlemesi, paket köprüsü, ad-hoc codesign --verify --deep --strict ve ZIP bütünlüğü doğrulandı. Gerçek Unix socket smoke testi: 10 eşzamanlı oturum, uygulama kapalıyken fail-open, sessiz exit 0, sınırlı/malformed girdi, 0600 dosyalar ve disk kuyruğunda prompt/soru saklanmaması geçti. Sonuçlar BRIDGE.json içindedir. SwiftData round-trip, çözülmemiş beklemenin saklanması ve önizleme metninin kalıcılaşmaması geçti (STORAGE.txt).

84 PNG ve 30 GIF üretildi. Açık/koyu kompakt ada, çentik kanatları, açılmış liste ve karakterli bildirim kartları görsel olarak kontrol edildi. 6 oturum listesi GIF’inde 16 kareden 10’u farklıdır. Bunlar deterministik render örnekleridir; fiziksel canlı animasyon testi olarak sayılmaz.

## Bekleyen fiziksel kabul

Paketli uygulama `open -n` ile denenirken LaunchServices -10827 (kLSNoExecutableErr) verdi. Paket içindeki executable mevcut, çalıştırılabilir ve arm64 Mach-O olarak doğrulandı; Paketin storage CLI modu çalıştı. Paketin render CLI modu exit 134 ile durdu; aynı kaynakların SwiftPM release executable dosyası bütün önizlemeleri başarıyla üretti. Paket içinden çizim yapılmış kabul edilmez. CUA envanterinde çalışan Dev Island bulunmadı. NSScreen fiziksel ekran sağlamadığı için ilgili test açıkça skip eder.

Bu nedenle çentiğin fiziksel hizası, başka uygulama/masaüstü odaktayken gerçek hover/tıklama, sürükleme, Spaces/tam ekran, çoklu ekran ve Instruments CPU/FPS kabulü kullanıcı Mac’inde yapılmalıdır. Developer ID/notarization ve ikinci Mac kurulumu tamamlanmış sayılmaz.

İlk bridge denemesi sandbox yerel socket kısıtına takıldı; erişim sonrası gerçek socket testi geçti. Paket render denemesi erişim sonrası da exit 134 verdi. SwiftPM release executable ile bütün renderlar başarılıdır; paketli canlı kabul bekler. Hook kurulumu, kullanıcı Claude ayarları ve üretim veri dizini değiştirilmedi.

Detay: V034_SESSION_MASCOTS.md. Eski üst giriş düzeltmesi: V033_FIX.md. Ham test ve derleme çıktıları teslim klasöründedir.
