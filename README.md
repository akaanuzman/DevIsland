# Dev Island

Claude Code oturumlarını izleyen, yerel çalışan macOS menü çubuğu uygulaması. Soru, plan ve izin bekleme durumlarını çentiğin yanında açılan bir ada, sistem bildirimi ve isteğe bağlı seslerle gösterir.

**Durum:** v0.3.0 yerel alfa. Dağıtılabilir beta kabulü için Developer ID/notarization, ikinci Mac ve gerçek terminal senaryolarının tamamlanması gerekir. Clawd, Kedi ve Robot maskotları bu sürüme dahildir; mobil push sonraki fazdadır.

## v0.3: kompakt ada, yerel tasarım ve üç maskot

Ana kaynak proje /Users/kaanuzman/Desktop/dev/DevIsland içindedir. Sohbetin outputs/DevIsland-v0.3 klasörü yalnızca yayın paketleri, önizlemeler ve doküman teslimidir.

**Görünüm** bölümünde Sistem/Açık/Koyu tema ve Liquid Glass/Buzlu cam/Opak yüzey ayrı seçilir. macOS 26 gerçek Liquid Glass kullanır; macOS 14/15 buzlu cam karşılığını gösterir. Cam stili, zemin yoğunluğu ve vurgu rengi ayarlanabilir. Reduce Transparency opak yüzeye, Reduce Motion hareketsiz maskot pozlarına ve kısa geçişlere dönüşür.

Varsayılan vurgu Claude turuncusu **#D97757**; renk seçiciden değişir. Özel çizilmiş **di** monogramı ikon ve menü çubuğunda kullanılır. Tema bütün SwiftUI/AppKit pencerelerine birlikte uygulanır; özel vurgu yazıları okunabilir tona dönüştürülür.

Varsayılan görünüm **Ada + maskot**tur. Görünüm’den **Clawd / Kedi / Robot** seçilir. Maskot varsayılan olarak uygulama rengini izler; her karakter için ayrı özel renk hatırlanır. Maskot sağ altta başlar, sürüklenebilir ve konumunu hatırlar. Tıklayınca oturum paneli açılır; sağ tıkla gizle, boyutlandır veya konumu sıfırla. Gizlenen maskot menü çubuğundan geri açılır. Tek başına ada veya tek başına maskot da kullanılabilir. Maskot yeni ses/bildirim üretmez; bildirim tercihleri ortak motordan gelir.

Kompakt ada yalnızca başlık yüksekliğindedir; gizli liste yer kaplamaz. Ada ve maskot paneli gerçek içeriği ölçerek büyür, yalnızca gerektiğinde kayar. Genel bakış, native sidebar ve sade oturum satırları kullanır.

Ada açılışı 320 ms, kapanışı 240 ms; hover beklemesi 120/400 ms’dir. Araç olayları hedef boyutu değiştirmedikçe ve 1 pt ölçüm yuvarlaması oluştuğunda animasyonu yeniden başlatmaz. Yeni bir geçiş yarıdaki görünür boyuttan devam eder. Eski ayarlar yeni tercih alanları eklenince sıfırlanmaz.

## Çalıştırma

Apple Silicon Mac, macOS 14+ ve Xcode/Swift 6 araçları gerekir. Haricî paket veya hesap gerekmez.

```bash
bash scripts/build-app.sh
open "dist/Dev Island.app"
```

Paketlenmiş uygulama `dist/Dev Island.app`, arşiv `dist/Dev-Island-0.3.0-arm64.zip` altında oluşur. Yerel derleme ad-hoc imzalıdır; başka Mac’lere dağıtım için `scripts/notarize.sh` kullanılır. Finder’da Applications’a taşındıktan sonra hook kurulumu yapılması önerilir. Köprü sabit bir kullanıcı veri dizinine kopyalandığı için uygulama güncellemesi hook komutunu değiştirmez.

İlk açılışta **Hook’ları incele ve bağlan** ile eklenecek kayıtları gör. Kurulum mevcut Claude ayarlarını yedekleyerek korur. Mevcut Claude oturumlarını yeniden başlat, bir prompt gönder ve oturumun listede göründüğünü doğrula. Bildirim izni **Bildirimler ve ses** bölümünden verilir. Girişte başlatma varsayılan kapalıdır.

**Köprü testi** gerçek paket köprüsünü çalıştırır; Claude hesabına istek atmaz ve Claude ayarlarını değiştirmez. Test oturumu menüsünden örnek kaydı kaldırabilirsin. Testin geçmesi, tüm terminal entegrasyonlarının canlı doğrulandığı anlamına gelmez.

## Kullanım

- Menü çubuğundaki Dev Island simgesinden veya varsayılan `⇧⌘D` kısayolundan oturumları aç.
- Soru/onay sayacı, bildirimi kapatsan da kalır. Yalnızca ilgili Claude devam olayı bu beklemeyi çözer.
- Kart menüsünden 5 dakika ertele, sustur veya etiket ekle.
- Kaynak uygulama biliniyorsa ona dönülür. Bilinmiyorsa tek açık aday seçilir veya kullanıcıdan seçim istenir; tercihi hatırlamak mümkündür.
- Apple Terminal’de TTY eşleşmesi ve Automation izniyle sekme seçilir. VS Code, Cursor ve Warp’ta ilk sürüm uygulamayı öne getirir; doğru bölünmüş paneli seçmeyi garanti etmez.
- `Stop` yalnızca yanıt sonudur: projedeki işlerin başarıyla tamamlandığına dair doğrulama değildir.

## Ses ve Focus

Dengeli profil soru, plan, izin ve hatada sesli; yanıt tamamlanmasında sessizdir. Varsayılan sistem sesi Focus ve macOS bildirim ayarlarını kullanır. Bu modda ses için bir sistem bildirimi de gerekir. Özel seslerin seviyesi uygulamadan ayarlanabilir; özel ses ve ada Focus’a otomatik bağlanmaz. Sessiz mod ve sessiz saatler bütün yeni uyarıları durdurur; bekleyen oturumları silmez.

## Gizlilik ve dosyalar

Uygulama ağ bağlantısı veya telemetri kullanmaz. Raw hook JSON, prompt, komut, plan ve transcript saklanmaz. Aktarım kuyruğu ve SwiftData snapshot yalnızca izin verilen metaveriyi tutar. Soru metni yalnızca canlı yerel socket üzerinden belleğe gelir; diske yazılmaz. Sistem bildirimleri proje/soru içermeyen genel durum metnidir.

Yerel veri: `~/Library/Application Support/DevIsland/`; izinler dizinde `0700`, kuyruk dosyalarında `0600`. Varsayılan geçmiş süresi 7 gündür. Aktif ve çözülmemiş oturumlar geçmiş temizlenince korunur. Tercihler UserDefaults’tadır. `CLAUDE_CONFIG_DIR` veya ayarlardaki dizin alanı özel Claude yapılandırmalarını destekler.

Bağlantıyı kaldırmak için **Claude bağlantısı → Bağlantıyı kaldır** kullan. Mevcut kullanıcı ayarları ve diğer hook’lar korunur. Eski Claude oturumlarının önbelleğe aldığı komutların hata vermemesi için küçük, etkisiz köprü dosyası yerinde kalır. Claude oturumlarını kapattıktan sonra veri klasörünü silebilirsin.

## Geliştirme ve doğrulama

```bash
bash scripts/swift.sh test
bash scripts/build-app.sh
python3 scripts/smoke-bridge.py
"dist/Dev Island.app/Contents/MacOS/DevIsland" --verify-storage
bash scripts/package-dmg.sh
```

`scripts/swift.sh`, SwiftPM ve Clang önbelleklerini proje içine alır. SwiftPM manifest sandbox’ının kapatılması yalnızca derleme sürecine aittir; uygulama zaten kullanıcı tarafından kurulabilen, sandbox dışı bir menü çubuğu aracıdır. Root/daemon gerekmez.

UI demosu için gerçek kullanıcı verilerinden ayrı bir klasör kullan:

```bash
open -n "dist/Dev Island.app" --args --demo --data-dir /tmp/dev-island-demo --show-settings
```

Bu mod örnek oturumları gösterir, bildirim izni istemez veya hook kurmaz. Aynı bundle’ın ikinci kopyası çalıştırılmaz; önce açık Dev Island’dan çık.

Ekrana uygulama açmadan SwiftUI yerleşimini render etmek için:

```bash
.build/arm64-apple-macosx/release/DevIsland --demo --data-dir /tmp/dev-island-render --render-preview previews
```

Bu komut altı ayar sayfasını açık/koyu temada gerçek NSHostingView/native kontrollerle ekran dışında çizer. Ada ve maskot paneli için 12 malzeme/tema örneği, iki kompakt ada, özel renkli kedi/robot örnekleri, üç karakterin sekiz pozu ve 24 GIF üretir. Ada örneklerinde camın desktop örneklemesi yerine statik temsil, ScrollView ve Menu için render edilebilir karşılıklar kullanılır. Gerçek pencere, odak, izin veya macOS bildirim teslim testinin yerine geçmez. Paket başlatma sorunlarında `DEV_ISLAND_TRACE=1` yalnızca açılış aşamalarını stderr’e yazar; oturum içeriği yazmaz.

## Yayınlama

```bash
export DEV_ISLAND_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export DEV_ISLAND_NOTARY_PROFILE="your-notarytool-profile"
bash scripts/notarize.sh
```

Sertifika ve notarytool profili bu repoya eklenmez. Yayın script’i nested köprüyü ve uygulamayı hardened runtime ile imzalar, Apple’a gönderir, bileti staple eder, DMG oluşturur ve DMG’yi doğrular.

v0.3 kapsamı: [V03_PLAN](docs/V03_PLAN.md). Önceki v0.2 tema/animasyon/maskot kararları: [V02_PLAN](docs/V02_PLAN.md). Ürün/mimari kararları: [PLAN](docs/PLAN.md). Gelecek fazlar: [ROADMAP](docs/ROADMAP.md). Doğrulama ve kalan kabul işleri: [VALIDATION](docs/VALIDATION.md).
