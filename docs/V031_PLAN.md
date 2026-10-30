# Dev Island v0.3.1 — üst kenar ve sürükleme

Bu sürüm, v0.3’teki tema/oturum/hook sözleşmesini korur. macos-app-design rehberindeki native kontroller, ölçülü boşluk ve erişilebilir eylemler sürdürülür.

| Önce | Sonra | Etki |
| --- | --- | --- |
| AppKit varsayılan pencere sınırlaması | Ada için coordinator tarafından hesaplanan fiziksel üst kenar | Menü çubuğu altında istemsiz boşluk oluşmaz |
| Sabit üst orta | Varsayılan üst orta + başlıktan sürükleme | Ada kullanıcının seçtiği yerde kalır |
| Her yerde aşağı açılan gövde | Ekranın alt yarısında yukarı açılma | Başlık sabit kalır, liste ekrana sığar |
| Kedide ters V ağız | Yukarı kalkık köşeler, düşük ağız merkezi ve göz parıltısı | Normal pozlar hafif gülümser |
| Yalnızca renk seçici | Vurgu ve seçili karakter için ayrı sıfırlama düğmeleri | İlgisiz tercihler korunur |

## Etkileşim ve saklama

- Başlığa tıklamak oturum listesini açar; 4 pt altındaki mouse hareketi tıklama sayılır. Eşik geçildikten sonra pointer başlangıca dönse de tıklama üretilmez. Escape ile iptal sonrası mouse-up tıklamaya dönüşmez.
- Sürükleme başında hover zamanlayıcıları geçersizleşir, bildirim süresi kalan değerde durur. Pencere geçişi görünen geometriden dondurulur ve bırakınca o boyuttan devam eder. Sürüklerken gelen uyarı ertelenir.
- Bırakılan konum ekran kimliği ve görünür ekran alanındaki göreli başlık koordinatlarıyla saklanır. Ekran küçülür/kalkarsa başlık görünür ekrana sınırlanır. Panel kenara yakınken asimetrik genişleyebilir; başlık yerinde kalır.
- Üst ortaya yakın bırakma mıknatısla varsayılan konuma döner. Sağ tık menüsü, Görünüm’deki düğme ve VoiceOver eylemi de üst ortaya sıfırlar. Ekran seçicisi değişince özel sürükleme konumu sıfırlanır.
- Varsayılan pencere frame.maxY = ekran.frame.maxY olacak şekilde yerleşir; üst köşeler düz ve gölge kapalıdır. Kamera alanı başlığın iki içeriği arasında korunur. Serbest konum görünür alan içinde ve kamera alanının altında kalır.

## Renk sıfırlama ve kedi

Vurgu sıfırlama yalnızca accentHex alanını D97757 yapar. Karakter sıfırlama yalnızca seçili karakterin özel kaydını kaldırır ve Uygulama rengini izle varsayılanına döner. Diğer karakterlerin renkleri, ses, tema, bildirim ve terminal tercihleri değişmez. Düğmeler Türkçe/İngilizce etiket, tooltip, erişilebilir ad ve native klavye davranışı kullanır.

Kedinin normal, çalışma, soru, plan ve izin pozları gülümser. Hata ve bağlantı kesilmesi sakin/uyarı ifadesini korur. Ada ve masaüstü aynı çizimi kullanır; yeni bildirim veya ses üretilmez.

Doğrulama sonuçları ve canlı cihazda bekleyen kabul maddeleri VALIDATION.md içindedir.
