# v0.3.6 — VS Code penceresi ve terminaline kesin dönüş

## Sonuç

Uygulamaya dön eylemi VS Code için kaynak Claude sürecinin ait olduğu pencereyi ve o pencerenin içindeki terminal örneğini seçer. Proje/oturum/terminal adı eşleştirme anahtarı değildir. Aynı projedeki veya aynı adlı terminaller farklı kalır. Claude hook olayları, tercihler ve kalıcı veri şeması değişmedi; eski izlenen canlı oturumlar kullanılabilir.

| Önce | Sonra | Kullanıcıya etkisi |
| --- | --- | --- |
| `app.activate(options: [.activateAllWindows])` | Pencereye özel yerel bağlantı → `workbench.action.focusWindow` → `Terminal.show(false)` | Son kullanılan pencere yerine oturumu barındıran pencere ve terminal seçilir. |
| Yalnızca bundleID | Kaynak PID + doğum zamanı → canlı üst süreçler → Terminal.processId | Değişen cwd, aynı proje ve aynı terminal adları yönlendirmeyi karıştırmaz. |
| Kesin terminal desteği yok | Yerel VSIX + Ayarlar/Claude bağlantısı sayfasında kur/güncelle düğmesi | Başka Mac'te de bağlantı kurulabilir; bu Mac'e eklenti kurulup etkinleşti. |

## Veri akışı ve arayüzler

- Yeni `EditorRegistry`, `EditorRoutePolicy` ve `EditorRouteClient` (Core) endpoint seçimini ve bounded istek/yanıtı yönetir. `ProcessIdentity.ancestors(source:)`, orijinal Claude PID'sinin doğum zamanını doğrulamadan üst süreçleri döndürmez.
- Terminal API'nin shell processId değeri kaynak Claude'un mevcut üst süreç zincirinde bulunmalıdır. İsim veya klasör üzerinden tahmin yapılmaz. Doğru instance bulunmazsa yeni pencere/terminal açılmaz; hata gösterilir. Kapanmış, belirsiz, doğrulanamayan veya bağlantısız hedefler açıkça ayrılır.
- Her VS Code extension host/pencere kendi UUID'sini ve terminal nesnesi başına UUID'sini üretir. Mevcut terminaller etkinleşmede taranır; açılma/kapanma ve workspace değişikliklerinde yenilenir. PID bilgisi geçici olarak yoksa atlanır. 10 saniyelik heartbeat, 45 saniyelik kayıt ömrü vardır.
- `/tmp/dev-island-vscode-<uid>` 0700; her socket ve JSON dosyası 0600, aynı kullanıcı sahibi. Uygulama symlink/yanlış sahip/gevşek izin/büyük veya beklenmeyen kayıtları reddeder. Endpoint yolu kayıt UUID'sinden türetilen aynı dizinle sınırlıdır. En yeni kayıtlar önce okunur.
- Sürüm 1 RPC: focus eylemi, requestID, windowID, terminalID, processID ve pencereye özel 256-bit token. Yanıt aynı kimlikleri ve seçildi/odaklandı bilgisini doğrular. Native süre sınırı 1.5 saniye; istek 4 KiB ve yanıt 8 KiB. Eklenti yerel Unix stream socket kullanır; TCP dinlemez, komut çalıştırma veya terminale metin yazma RPC'si yoktur.
- Eklenti hedef terminalin hâlâ açık ve aynı processId'ye bağlı olduğunu istekte tekrar kontrol eder. Pencere odağı ve aktif terminal 600 ms içinde doğrulanmazsa başarı dönmez. Kullanıcı uygulamasındaki VS Code istekleri sırayla yürütülür; hızlı ardışık seçimler son seçilen oturumla sonuçlanır.
- Apple Terminal'in TTY/Automation yönlendirmesi ve Cursor/Warp'ın mevcut uygulamaya dönüşü korunur. Eklenti VS Code desktop/local macOS host'larında etkindir; uzak SSH/dev-container, tmux paneli ve Cursor için tam terminal dönüşü bu sürümün dışındadır.

## Kurulum

Bu Mac'te `dev-island-local.terminal-router` 0.1.0 VSIX ile kuruldu. Üç kullanıcı penceresinde etkinleşti; açık terminaller yeniden oluşturulmadı ve Claude'a prompt gönderilmedi. Yeni Dev Island.app kopyası eski uygulamadan Çık yapılarak açılmalıdır.

Başka Mac veya profil için Ayarlar → Claude bağlantısı → VS Code bağlantısını kur/güncelle. Aynı VSIX `Contents/Resources/DevIslandVSCode.vsix` içinde ve teslim klasöründe bulunur. Açık bir pencere kurulumdan sonra bağlanmazsa uygun zamanda Developer: Reload Window çalıştırılabilir; otomatik reload yapılmaz. Command Palette: Dev Island: Show Terminal Connection Status. Kaldırmak için VS Code Extensions içinden Dev Island Terminal Router'ı kaldır. Hook kaldırma eylemi yalnızca hook'ları kaldırmayı sürdürür.

Eklenti bağımlılıksız JavaScript'tir; paketleyici standart VSIX/OPC ZIP üretir. İzole dizinde ve gerçek kullanıcı kurulumunda VS Code CLI yüklemesi başarılıdır. Marketplace hesabı, Accessibility veya Screen Recording izni gerekmez. Kurulum CLI'si shell string birleştirmesi yerine ayrı argumentlerle çağrılır, UI thread'ini bekletmez ve 45 saniyede sonlandırılır.

## Kabul kanıtı

104 XCTest: 103 başarılı, yalnızca fiziksel ekran isteyen 1 eski test skip. 9 Node eklenti testi başarılı. Eski 99 test korunur. Yeni native testler aynı proje/adlarla kesin PID seçimi, stale/ambiguous/birth-time reuse, nonce/yanıt kimliği/odak doğrulaması, izinler ve gerçek C Unix socket istemcisi → Node servis akışını doğrular. Node testleri iki ayrı pencere modeli, aynı adlı terminaller, yanlış token/PID/UUID, kapanan terminal, eksik PID, desteklenmeyen odak komutu, doğrulanmayan focus, bozuk/büyük girdi ve pencereye özel temizliği kapsar.

**Gerçek kullanıcı VS Code API kontrolü:** native arm64 release istemcisi kaynak PID/doğum zamanından gerçek zinciri doğrulayıp eklentiye ulaştı. no_cigaratte, alvi-landing ve cookify_mobile olmak üzere 3 gerçek pencerede 5 gerçek Claude terminali başarıyla seçildi. Aynı no_cigaratte penceresindeki üç oturum ayrı terminal UUID'leriyle döndü. Eklenti her istekte window.state.focused ve window.activeTerminal ile başarıyı doğruladı. Workspace'ler Claude isim kayıtlarının cwd'siyle ayrıca karşılaştırıldı. LIVE-ROUTING.json ham sonucudur; token içermez. Paketli .app executable içinden aynı istemcinin bir gerçek terminale dönüşü de başarılıdır (PACKAGED-ROUTING.json). Terminale komut/metin gönderilmedi.

Bu, Dev Island'ın paketli adasındaki düğmeye fiziksel fareyle basıldığı iddiası değildir; düğmenin kullandığı aynı EditorRouteClient üretim release executable'ının açık diagnostic eylemiyle çağrıldı. Native UI aracı bağlantıda zaman aşımına uğradı; izole Code GUI test host'u sonuç üretmedi. Bu iki deneme başarılı test sayılmadı. Başarı kanıtı mevcut kullanıcı pencerelerinin gerçek extension host'larından geldi. Çentik/Spaces/CPU-FPS/ikinci Mac/Developer ID kabulü ayrıca bekler.

## API kaynakları

[VS Code Terminal API: processId, exitStatus, show](https://code.visualstudio.com/api/references/vscode-api#Terminal). `workbench.action.focusWindow` kurulu VS Code 1.143.1 içinde ve [Microsoft kaynak kodunda](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/electron-browser/actions/windowActions.ts) doğrulandı. Komut kullanılabilirliği eklentide capability-check ile kontrol edilir; yoksa hedef seçilmiş gibi davranılmaz.
