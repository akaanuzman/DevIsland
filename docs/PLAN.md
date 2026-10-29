> Bu belge v0.1 çekirdeğinin tarihsel planıdır. v0.2 tema, ada geçişi ve Clawd uygulaması için [V02_PLAN.md](V02_PLAN.md) esas alınır.

# Dev Island — uygulama planı ve kararlar

## Ürün

Terminali sürekli kontrol etme ihtiyacını ortadan kaldırmak: Claude bir soru, izin veya plan onayı beklediğinde ve yanıtını tamamladığında kullanıcıyı haberdar etmek. İlk hedef kişisel kullanımda doğrulanıp başka geliştiricilere dağıtılabilen macOS betasıdır.

İlk sürüm Swift/SwiftUI, AppKit NSPanel, UserNotifications, AVFoundation, SwiftData, UserDefaults ve SMAppService kullanır. Apple Silicon ve macOS 14+ hedeflenir. Hesap, backend, ekran okuma, Accessibility veya tam disk erişimi gerekmez. Oturum yanıtı/izin kararı uygulamadan verilmez; kullanıcı kaynak terminale döner.

## Arayüz ve davranış

- Boşken ada gizlenir; menü çubuğu erişilebilir kalır.
- Kompakt ada turuncu Claude göstergesi ile bekleyen/çalışan sayısını gösterir.
- Bildirim 8 saniye görünür, hover sırasında süre durur. Tıklama veya hover oturum listesini açar; yalnızca açık kullanıcı eylemi klavye odağı alır.
- Soru/plan/izin beklemeleri kapatılan bildirimden bağımsızdır. Oturuma dönmek veya ertelemek bunları çözmez.
- Kullanıcı etiketi, kısa oturum ID’si, proje, kaynak uygulama, olay zamanı, bekleme süresi, arka plan ve zamanlanmış iş sayısı gösterilir.
- Karttan uygulamaya dönme, 5 dakika erteleme ve susturma yapılır. Tanılama/demo ve bağlantısı kesilmiş kayıtlar listeden kaldırılabilir.
- Öncelik: soru → plan → izin → hata → yanıt tamamlandı → çalışıyor → hazır → bağlantısı kesildi.
- Çentik geometrisi NSScreen safe area ve yardımcı üst bölgelerden hesaplanır. Çentiksiz ekranda üst orta kapsül kullanılır. Varsayılan ekran built-in, yoksa ana ekrandır; manuel seçim bulunur.
- Tam ekran üzerinde gösterme kapatılabilir. Reduce Motion sistemden izlenir. Klavye kısayolu değiştirilebilir, Escape listeyi kapatır.
- Arayüz dili sistemden seçilir; Türkçe ve İngilizce elle değiştirilebilir.

## Bildirim politikası

| Olay | Ada | Sistem bildirimi | Ses |
| --- | --- | --- | --- |
| Soru | Açık | Açık | Açık |
| Plan onayı | Açık | Açık | Açık |
| İzin | Açık | Açık | Açık |
| Yanıt tamamlandı | Açık | Açık | Kapalı |
| Hata | Açık | Açık | Açık |

Her olayın kanalları ayrı değişir. Sistem sesi macOS/Focus kontrolündedir; özel sesler AVAudioPlayer ile ayarlanır ve native bildirim sessiz kalır. Özel ses/ada Focus’un otomatik kontrolünde değildir; bu durum ayarlarda açıkça anlatılır. Genel sessiz mod, gece yarısını aşabilen sessiz saatler ve oturum bazında susturma/erteleme desteklenir. Opsiyonel 2 dakika hatırlatması aynı bekleme için bir kere çalışır ve varsayılan kapalıdır.

## Terminal yönlendirmesi

Kaynak bundle ID süreç atalarından belirlenir; TTY ve Claude PID/başlangıç zamanı kaydedilir. Bilinen kaynak her zaman hatırlanmış tercihten önce gelir. Kaynak bilinmiyorsa tek açık desteklenen uygulamaya dönülür; çok aday varsa seçim ve hatırlama sunulur. Kaynak kapanmışsa başka terminale taşıma taklidi yapılmaz.

| Kaynak | v0.1 desteği |
| --- | --- |
| Apple Terminal | TTY eşleşmesi; Automation izni varsa ilgili sekme |
| VS Code | Uygulamayı öne getir |
| Cursor | Uygulamayı öne getir |
| Warp | Uygulamayı öne getir; mevcut pane/sekme URI ile hedeflenmez |

## Veri akışı ve modüller

```text
Claude hook stdin
  → signed dev-island-bridge
  → metadata-only bounded disk spool + live Unix datagram
  → ClaudeAdapter / SessionLedger
  → SwiftData metadata snapshot
  → AttentionEngine
  → IslandController / native notification / audio
```

- `ClaudeAdapter`: ham JSON’dan sadece gerekli alanları seçer; gelecekteki başka sağlayıcılar aynı AgentEvent modelini kullanabilir.
- `AgentEvent`: sürüm, UUID, sağlayıcı, oturum ID, zaman, olay türü, cwd, tool-call/agent ID ve kaynak uygulama/TTY/süreç kimliği.
- `SessionLedger`: beklemeleri tool-call ve agent ile eşler; aynı projedeki oturumlar ID ile ayrılır. Yeni prompt eski turdaki beklemeyi temizler; ilgisiz araç bitişi başka beklemeyi çözmez.
- `EventQueue`: kullanıcıya özel dizin, atomik dosya, en çok 1000 olay; diskte preview yoktur. Socket canlı önizlemeyi belleğe taşır. Uygulama açılışındaki replay sessizdir; SwiftData save başarılı olmadan queue ack edilmez.
- `SessionRepository`: SwiftData içinde preview’siz ledger saklar; varsayılan 7 günlük geçmiş, en çok 20.000 olay. Aktif beklemeler yaşa göre silinmez.
- `AttentionEngine`: geçiş, kanal tercihi, replay, yeniden doğrulama, sessiz saatler, susturma ve ertelemeyi dikkate alır.
- `TerminalRouter`: kaynak uygulama önceliği ve fallback seçimleri; kullanıcı kararını/komutunu terminale yazmaz.

## Claude olayları

`SessionStart/SessionEnd`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse/PostToolUseFailure`, `PermissionRequest`, `Stop/StopFailure`, `SubagentStart/SubagentStop` ve seçilmiş `Notification` türleri gözlenir.

`AskUserQuestion` soru, `ExitPlanMode` plan onayı durumudur. PermissionRequest hemen bildirilir; gecikmiş permission notification aynı beklemede birleştirilir. `Stop` “Yanıt tamamlandı” anlamındadır, tüm projenin başarısı değildir. Kısa bir settle süresi tamamlanma uyarısını devam eden araç olaylarında iptal eder; sonraki çalışma sinyali durumunu düzeltir. Alt ajan Stop’u ana oturumu tamamlamaz. `idle_prompt` tek başına tamamlanma çıkarmak için kullanılmaz.

## Kurulum ve hata davranışı

Hook eklenmeden önce tam JSON gösterilir. Mevcut settings nesnesi korunur, timestamp/UUID’li backup alınır, atomik yazılır. Kurulum tekrarlandığında kayıt çoğalmaz. Kaldırma yalnızca Dev Island sahibi komutları siler; sonradan eklenmiş kullanıcı ayarlarını korur. Bozuk JSON veya symlink ayarlar değiştirilmez. Bilinen global/managed hook kısıtlamaları raporlanır; projeye özel kısıtlar gerçek olay testi ile doğrulanır.

Köprü sessiz exit 0 üretir, karar döndürmez, girdi 2 MiB ile sınırlandırılır ve yaklaşık 0,8 saniyede kesin çıkış zamanlayıcısı bulunur. Uygulama yokken Claude engellenmez. Kapanış olayı gelmeyen süreç PID + başlangıç zamanı ile kontrol edilir; erişim reddi ölüm sayılmaz. Uyanışta queue sessiz işlenir ve süreçler doğrulanır. Sadece zaman geçmesi hata sayılmaz.

## Kabul ve yayın

- Normal canlı olay → ada hedefi 1 saniyenin altında.
- 10 eşzamanlı oturumda ayrım; aynı beklemede tek uyarı.
- Yeniden başlatmada beklemeyi koruma ve doğrulama.
- Boşta CPU hedefi %1 altı; Instruments ile nihai doğrulama.
- Her terminalde gerçek Claude, izin reddi, çentik/harici ekran, Spaces/tam ekran, uyku/uyanma ve temiz ikinci Mac testi.
- Developer ID, hardened runtime, notarization ve stapled DMG olmadan kamuya dağıtılabilir beta denmez.

Mevcut doğrulama durumu `VALIDATION.md` dosyasındadır; kaynak/test tamamlanması, gerçek cihaz ve yayın kabulüyle karıştırılmaz.

## Kaynaklar

- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [Apple NSScreen güvenli bölgeleri](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytopleftarea-uglc)
- [Warp URI sınırları](https://docs.warp.dev/terminal/more-features/uri-scheme)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)
- [Developer ID dağıtımı](https://developer.apple.com/developer-id/)
