# v0.3.5 — gerçek Claude oturum adları

Sorun: v0.3.4 yalnızca Dev Island etiketi veya cwd klasör adını gösteriyordu. VS Code terminalinde görünen `improve-shop-experience` gibi Claude oturum adı köprüde taşınmıyordu. Aynı projede farklı oturumlar ayırt edilemiyor, araç bir alt klasörde çalışırsa `out` gibi yanıltıcı adlar görünüyordu.

| Önce | Sonra | Kullanıcıya etkisi |
| --- | --- | --- |
| `label.isEmpty ? project : label` | Dev Island etiketi > Claude oturum adı > proje adı | Aynı projedeki farklı konuşmalar terminaldeki adlarıyla ayrılır. |
| Hook adaptörü isim alanlarını atıyordu | `session_title` ve sınırlı yerel isim metaverisi `sessionName` olarak taşınır | Claude adı kartta, listede ve kompakt başlıkta birlikte güncellenir. |
| Daha önce açılmış oturumlarda isim yok | Başlangıçta ve 5 saniyede bir mevcut izlenen oturumların isimlerini arka planda tamamla | Yeni prompt göndermeden isimler gelir; yeniden adlandırma takip edilir. |
| Kompakt uzun ad yalnızca kısaltılır | Native başlık tooltip’i tam adı ve durumu gösterir; gizlilik tercihi uygulanır | Başlık genişlemeden tam isim görülebilir. |

## Veri ve öncelik

- `ClaudeSessionName`: en fazla 200 karakterlik temizlenmiş value ve custom/automatic origin. AgentEvent ve AgentSession içindeki yeni `sessionName` alanı opsiyoneldir; eski olaylar/SwiftData JSON kayıtları okunur. Olay sürümü 1 ve mevcut hook kayıtları korunur.
- Claude'un resmî hook girişi `session_title`, SessionStart ve UserPromptSubmit için özel adı verir; otomatik üretilen ad bu alanda olmayabilir. Kaynak: [Hooks reference — SessionStart input](https://code.claude.com/docs/en/hooks#sessionstart-input), [UserPromptSubmit input](https://code.claude.com/docs/en/hooks#userpromptsubmit-input).
- Otomatik adlar için yerel `sessions/<pid>.json` kayıtları sessionId ile eşleştirilir. `nameSource=derived` klasör varsayılanı isim sayılmaz. Aynı sessionId için kalan eski süreç kayıtlarında en yeni dosya seçilir. Claude Code 2.1.308 üzerinde kullanıcı ekranındaki adlarla doğrulandı. Bu dosya biçimi resmî API değildir; hata halinde son bilinen isim/proje adı korunur.
- Kayıtlı cwd kullanılarak transcript yalnızca isim metaverisi için sınırlandırılmış biçimde okunabilir: `<session-id>.jsonl`, configDirectory/projects altında gerçek normal dosya; sembolik bağlantı/dizin/başka oturum dosyaları reddedilir. Baş 32 KiB + son 256 KiB; en fazla 16 KiB satır. Yalnızca aynı sessionId için custom-title/customTitle veya agent-name/agentName alanları kabul edilir. Konuşma, kod, summary veya ilk prompt isim olarak kullanılmaz.
- Hook özel adı ve transcript özel adı otomatik ada üstün gelir. Sonraki isimsiz/otomatik olay kaydedilmiş özel adı silmez. Dev Island etiketi önceliğini korur; etiket boşaltılırsa Claude adı görünür.
- Arka plan isim okuması sırasında yeni hook/rename geldiyse eski snapshot onu geri alamaz. İsim güncellemesi çalışma/bekleme durumunu, attentionSince, lastEvent, sıralama zamanını veya bildirim sayısını değiştirmez.
- CLAUDE_CONFIG_DIR hook köprüsünde, uygulamanın bağlantı configPath tercihi uygulamada kullanılır. Kullanıcının Claude ayarlarına veya transcriptlerine yazılmaz. Kuyruk/geçmiş yalnızca isim metaverisini taşır; transcript yolu ve içerik saklanmaz.
- Eksik/bozuk/kısmi/uyumsuz yerel kayıtlar hata üretmeden fallback eder. Okuma aralığının dışında kalan eski metaveri ve serbestçe elle değiştirilmiş VS Code terminal tab başlıkları garanti edilmez. Yeni izlenmeyen oturumlar isim kayıtlarından sahte durumla oluşturulmaz; mevcut hook yaşam döngüsü gerekir.

## Kontrol

Yeni 11 test: hook adı önceliği; aynı projede farklı UUID; özel/otomatik adlar; bounded/kısmi transcript; yanlış oturum/symlink/dizin dışı dosya; eski Codable ve kaydet/aç; stale event; isim normalizasyonu; mevcut oturumda hooksuz isim yenileme; arka plan snapshot yarışı; gizlilik ve manuel etiket. Eski 88 test korunur.

Paket köprüsü ile 4 gerçek yerel Claude oturumunun adı doğru alındı. Kullanıcının Dev Island deposu salt okunur incelendi: `out` görünen UUID, alvi-app-store-launch-prep ile eşleşiyor. Üretim veri dizinine/Claude ayarlarına yazılmadı. Ayrıntı LIVE-NAMES.json; genel socket testi BRIDGE.json, izole ad/rename testi NAME-BRIDGE.json. SwiftData storage smoke yeni ismin saklandığını da denetler.

Fiziksel masaüstü ve paketli canlı açılış bu ortamın LaunchServices -10827 engeli nedeniyle bekler. Önizlemeler gerçek üretim görünümlerinden deterministik SwiftPM release renderlarıdır; çalışan kullanıcı uygulamasının ekran görüntüsü değildir.
