# Dev Island v0.3 — uygulanan kapsam

Ana kaynak: /Users/kaanuzman/Desktop/dev/DevIsland. Hedef: Apple Silicon, macOS 14+. Hook olay sözleşmesi ve yerel veri modeli korunur.

## Tasarım

- Yerel SF tipografisi, native sidebar List, GroupBox ve macOS kontrolleri.
- Genel bakışta küçük bekleyen/çalışan özeti ve ayırıcılarla oturum listesi. Büyük istatistikler, slogan ve maskot tanıtım alanı kaldırıldı.
- Varsayılan vurgu #D97757. Renk seçici ham kullanıcı rengini saklar; yazı ve dolgu üstü renkler sRGB kontrastına göre türetilir.
- di monogramı font kullanmadan özel vektör yollarından çizilir. Aynı BrandGeometry UI, template menü ikonu ve ICNS üreticisi tarafından kullanılır. Uygulama ikonunun turuncusu sabittir.
- macos-app-design skill’i GitHub kaynağından kuruldu ve yerel macOS yoğunluğu/kontrol/yüzey rehberi olarak kullanıldı. Skill uygulama bağımlılığı değildir.

## Ada ve paneller

NSHostingView.sizingOptions boş bırakılır; boyutu tek geçiş koordinatörü yönetir. Kompakt gövdeye açıkça 0 pt yüksekliği verilir; yalnızca seçili içerik ağacı bulunur. Kapanışta önceki gövde hâlâ bağlı olsa bile pencere başlık yüksekliğinde kalır.

PanelSizing, gerçek SwiftUI içerik ağacını hedef genişlikte NSHostingController.sizeThatFits ile ölçer. Açılır adada başlık buna eklenir. Oturum sayısına bağlı tahmini satır yüksekliği yoktur. ViewThatFits, satırlar sığıyorsa doğal listeyi; aşarsa ScrollView’i seçer. Alt araç çubuğundan sonra 12 pt padding bulunur. Maskot paneli aynı ölçümü kullanır.

320/240 ms kesilebilir geçiş, 120/400 ms hover gecikmesi, sabitlenmiş liste, 8 saniyelik bildirim ve hover duraklatması korunur. 1 pt ölçüm yuvarlama farkı geçişi yeniden başlatmaz. Reduce Motion kısa solmaya geçer.

## Tema ve maskotlar

ThemeCoordinator, NSApplication ve tüm AppKit pencerelerine/sheet’lere seçili görünümü uygular. Sistem modunda override kaldırılır; native görünüm ve SwiftUI ortamı sistem değişimlerini izler. AppTheme, SwiftUI renk şemasını ve açıkça çözümlenen metin paletini bütün alt görünümlere iletir. Reduce Transparency camı opaklaştırır.

Clawd, Kedi ve Robot ortak ClawdView Canvas çizicisini ve mevcut durum motorunu kullanır. Her karakterin silüeti, detayları ve şeffaf hit bölgeleri ayrıdır. Sekiz poz: hazır, çalışma, soru, plan, izin, kutlama, hata ve bağlantı kesilmesi. Gövdeye bağlı göz, gölge, vurgu ve dış çizgi türetilir. Yeni karakterler bağımsız bildirim veya ses üretmez.

Varsayılan renk modu uygulama rengini izler. Karakter başına özel renk ve izleme modu saklanır. Karakter değiştirmek diğer karakterin rengini silmez. Sürükleme, boyut, normalize ekran konumu, görünürlük ve tek seferlik kutlama korunur. Gizli/uyuyan/Reduce Motion durumunda animasyon saati durur.

## Geçiş ve kabul

- v0.1/v0.2 JSON tercihleri alan bazında çözülür. Eski varsayılan #168E96 turuncuya geçer; diğer özel renkler, ses ve terminal ayarları korunur.
- appearanceVersion=3 sonrasında kullanıcının özellikle seçtiği #168E96 yeniden değiştirilmez.
- İlk seçili karakter Clawd; yeni karakterlerde varsayılan renk izleme.
- Oturum beklemeleri, okunma ve hook sözleşmesi korunur.
- Kabul testleri ve canlı cihazda bekleyen maddeler VALIDATION.md içindedir.

Referanslar: [macos-app-design](https://github.com/heyimjames/ios-design-skills/tree/main/plugins/heyimjames/skills/macos-app-design), [NSHostingView sizingOptions](https://developer.apple.com/documentation/swiftui/nshostingview/sizingoptions).
