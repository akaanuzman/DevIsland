# Dev Island

Claude Code oturumlarını izleyen, yerel çalışan macOS menü çubuğu uygulaması. Soru, plan ve izin bekleme durumlarını çentiğin yanında açılan bir ada, sistem bildirimi ve isteğe bağlı seslerle gösterir.

**Durum:** v0.3.6 yerel alfa. Dağıtılabilir beta kabulü için Developer ID/notarization, ikinci Mac ve gerçek terminal senaryolarının tamamlanması gerekir. Clawd, Kedi ve Robot maskotları bu sürüme dahildir; mobil push sonraki fazdadır.

## v0.3.6: doğru VS Code penceresi ve terminali

**Uygulamaya dön**, kaynak Claude sürecinin bağlı olduğu VS Code penceresini ve terminali seçer. Aynı projedeki aynı adlı terminaller PID/instance kimliğiyle ayrılır. Kapalı veya doğrulanamayan hedefte başka bir pencere seçilmez, yeni terminal açılmaz.

Bu Mac'te bağlantı eklentisi kuruldu ve üç VS Code penceresinde etkinleşti. Eski Dev Island'dan **Çık** yapıp yeni uygulamayı aç. Başka Mac/profil için Ayarlar → Claude bağlantısı → **VS Code bağlantısını kur / güncelle**. VSIX uygulamanın içinde gelir; gerekirse VS Code Extensions → Install from VSIX ile kurulabilir. Açık pencere bağlanmazsa uygun zamanda Developer: Reload Window kullanılabilir. Mevcut terminaller otomatik yeniden başlatılmaz.

Gerçek 3 pencere ve 5 Claude terminalinde üretim routing istemcisiyle doğrulandı. [Teknik kapsam ve test kanıtı](docs/V036_VSCODE_ROUTING.md). Remote/tmux ve Cursor'da tam terminal seçimi sonraki uyumluluk kapsamındadır.

## v0.3.5: terminaldeki gerçek Claude oturum adı

Ada artık klasör adı yerine `improve-shop-experience` gibi Claude oturum adını kullanır. Mevcut izlenen oturumların adları uygulama açıldığında ve 5 saniyede bir yerel isim metaverisinden tamamlanır. Aynı projedeki oturumlar kimlikleriyle eşleştirilir; `out` gibi değişen çalışma klasörleri isim eşlemesini bozmaz. Dev Island'da elle verilen etiket önceliklidir. Proje gizleme bütün isim alanlarında çalışır. Uzun kompakt adın tamamı başlık tooltip'inde görülebilir.

Claude ayarları ve transcriptlerine yazılmaz. Hook alanı ve yerel formatlar için ayrıntı: [V035](docs/V035_SESSION_NAMES.md). Eski sürümü **Çık** ile kapatıp yeni kopyayı aç; izlenen oturumların adları yeni bir prompt beklemeden yenilenir. Mevcut hook kurulumu geçerlidir; yeni köprü için Claude bağlantı kurulumunu uygulama ayarlarından tekrar çalıştırabilirsin.

## v0.3.4: oturum adı ve durum maskotları

Kompakt başlık öncelikli oturumun etiketini (yoksa proje adını) gösterir. Bildirim açıldığında başlıktaki ad ve maskot o bildirimin oturumuna geçer. Uzun adlar sabit alanda kısalır; kamera alanı boş ve kompakt yükseklik sabit kalır.

Bildirim kartında 44 pt, açılan oturum listesinde 32 pt maskot her oturumun kendi durumunu izler. Seçilen karakter ve renk paylaşılır. Kutlama yalnızca canlı tamamlanma olayında, bütün yüzeylerde aynı başlangıç saatiyle oynar; paneli yeniden açmak tekrarlatmaz. Proje gizleme adı “Claude Code” yapar. Kapalı yüzeylerde ve uyku sırasında animasyon saati durur; Reduce Motion sabit poz kullanır. Ayarlar listesindeki sade ikonlar korunur.

## v0.3.3: üst konum giriş düzeltmesi

Yalnızca üstteyken hover/tıklamanın çalışmaması için pencere seviyesi düzeltildi. Çentikli ekranda kameranın altında küçük bir etkileşim şeridi bulunur; sistem alanındaki mouse olayları için dar kapsamlı fallback eklenir. Serbest sürükleme davranışı korunur. Ayrıntılar [V033_FIX](docs/V033_FIX.md) içindedir.

**Güncelleme:** Önce menü çubuğundaki Dev Island → Çık eylemini kullan, sonra yeni uygulamayı aç. Eski arka plan süreci kapanmadan yeni kopyayı açmak sürümü değiştirmeyebilir.

## Üst sabitleme ve hover

Sürüklenen adanın sağındaki **pin** düğmesi, adayı üst ortaya sabitler. Düğme yalnızca serbest konumda görünür. Üstteyken üzerine gelince büyür; dışına çıkınca küçülür. Tıklayarak açılan liste, yeniden tıklayana veya Escape’e basana kadar açık kalır. Hover, başka uygulama odaktayken de izlenir.

## Üst kenar, sürükleme ve sıfırlama

Ada varsayılan olarak ekranın fiziksel üst ortasına yapışır. Başlığından sürükleyip bırak; konum yeniden açılışta korunur. Ekranın altına bırakıldığında oturum paneli yukarı açılır. Üst ortaya yakın bırakmak, başlığa sağ tıklamak veya Görünüm → Adayı üst ortaya sıfırla eylemi varsayılan konuma döndürür. Ekran değişirse ada görünür alanda kalır.

Görünüm’de vurgu ve karakter rengi için ayrı Varsayılana sıfırla düğmeleri bulunur. Vurgu turuncuya (#D97757), seçili karakter uygulama rengini izlemeye döner. Diğer karakter renkleri ve ayarlar korunur. Kedinin normal pozları artık hafif gülümser.

## v0.3: kompakt ada, yerel tasarım ve üç maskot

Ana kaynak proje /Users/kaanuzman/Desktop/dev/DevIsland içindedir. Sohbetin outputs/DevIsland-v0.3.6 klasörü yalnızca yayın paketleri, önizlemeler ve doküman teslimidir.

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

Paketlenmiş uygulama `dist/Dev Island.app`, arşiv `dist/Dev-Island-0.3.6-arm64.zip` altında oluşur. Yerel derleme ad-hoc imzalıdır; başka Mac’lere dağıtım için `scripts/notarize.sh` kullanılır. Finder’da Applications’a taşındıktan sonra hook kurulumu yapılması önerilir. Köprü sabit bir kullanıcı veri dizinine kopyalandığı için uygulama güncellemesi hook komutunu değiştirmez.

İlk açılışta **Hook’ları incele ve bağlan** ile eklenecek kayıtları gör. Kurulum mevcut Claude ayarlarını yedekleyerek korur. Mevcut Claude oturumlarını yeniden başlat, bir prompt gönder ve oturumun listede göründüğünü doğrula. Bildirim izni **Bildirimler ve ses** bölümünden verilir. Girişte başlatma varsayılan kapalıdır.

**Köprü testi** gerçek paket köprüsünü çalıştırır; Claude hesabına istek atmaz ve Claude ayarlarını değiştirmez. Test oturumu menüsünden örnek kaydı kaldırabilirsin. Testin geçmesi, tüm terminal entegrasyonlarının canlı doğrulandığı anlamına gelmez.

## Kullanım

- Menü çubuğundaki Dev Island simgesinden veya varsayılan `⇧⌘D` kısayolundan oturumları aç.
- Soru/onay sayacı, bildirimi kapatsan da kalır. Yalnızca ilgili Claude devam olayı bu beklemeyi çözer.
- Kart menüsünden 5 dakika ertele, sustur veya etiket ekle.
- Kaynak uygulama biliniyorsa ona dönülür. Bilinmiyorsa tek açık aday seçilir veya kullanıcıdan seçim istenir; tercihi hatırlamak mümkündür.
- Apple Terminal’de TTY eşleşmesi ve Automation izniyle sekme seçilir. VS Code yerel bağlantısı doğru pencere ve terminali seçer. Cursor ve Warp uygulamayı öne getirir; bu ikisinde doğru paneli seçme desteği sonraki fazdadır.
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

v0.3.4 sunumu: [V034](docs/V034_SESSION_MASCOTS.md). v0.3.3 düzeltmesi: [V033_FIX](docs/V033_FIX.md). Önceki kapsam: [V032_PLAN](docs/V032_PLAN.md). Önceki sürüm: [V031_PLAN](docs/V031_PLAN.md). Önceki v0.3 kapsamı: [V03_PLAN](docs/V03_PLAN.md). Önceki v0.2 tema/animasyon/maskot kararları: [V02_PLAN](docs/V02_PLAN.md). Ürün/mimari kararları: [PLAN](docs/PLAN.md). Gelecek fazlar: [ROADMAP](docs/ROADMAP.md). Doğrulama ve kalan kabul işleri: [VALIDATION](docs/VALIDATION.md).
