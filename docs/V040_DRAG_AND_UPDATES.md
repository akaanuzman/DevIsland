# v0.4 — taşıma ve güncelleme değişiklikleri

| Before | After | What this changes |
| --- | --- | --- |
| Mouse basıldıktan sonra hover 4 pt eşik aşılana kadar çalışıyordu | Mouse-down anında pressed aşaması ve zamanlayıcı duraklatma | Başlık tutulurken ada açılmaz/kapanmaz |
| Başlık taşınabilirliğini göstermiyordu | Kamera dışında 24×24 pt noktalı tutamak, open/closed hand imleci | Kullanıcı taşıma alanını bulur; kompakt yükseklik artmaz |
| Çentikten ayrılma ve her hareket layout üzerinden geçiyordu | Göreli tutma noktası ve doğrudan pencere render yolu | Tutulan nokta kaymaz; her mouse olayında içerik yeniden ölçülmez |
| Üste yapışırken eski frame hover sonucu kalabiliyordu | Bırakma sonrasında nihai frame ile yeniden kontrol | Sonraki hover ilk girişte çalışır |
| Sürümler scriptlerde ayrı ayrı yazılıydı | Resources/version.json + generated BuildInfo/Info.plist | Köprü, uygulama ve paket adı aynı sürümü kullanır |
| Elle ZIP değişimi | Sparkle 2.9.6 + stable/beta yayın iş akışı | Resmi ilk kurulumdan sonra uygulama içinden güncellenir |

Yeni iç arayüzler: IslandPresentation.headerPressed/headerReleased/cancelHeaderInput; IslandInteraction.pressed/interacting; UpdateController + UpdateBackend; HookInstaller.refreshInstalledHelper(from:). Hook sözleşmesi ve kayıt şeması değişmedi. Yeni güncelleme tercihleri mevcut preferences.v1 JSON'una eklenmeden ayrı UserDefaults anahtarlarında tutulur.

Basma süresince nonactivating panel geçici key responder olabilir; bu kullanıcı hareketi Escape'i almasını sağlar. Önceden key değilse bırakmada resignKey yapılır. Otomatik hover açılışı uygulamayı aktive etmez. Bu davranışın fiziksel klavye/Spaces kabulü ortam nedeniyle bekliyor.

Yayın kurulum ve uçtan uca kabul adımları UPDATES.md, geçerli test sonuçları VALIDATION.md içindedir.
