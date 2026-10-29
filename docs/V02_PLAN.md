# Dev Island v0.2 — uygulanan tasarım ve mimari

Ana proje: `/Users/kaanuzman/Desktop/dev/DevIsland`. Bu sürüm 30 Ekim 2026 tarihinde ilk alfa üzerine geliştirildi.

## Tema ve yüzey

Sistem/açık/koyu tema ile Liquid Glass/buzlu cam/opak yüzey birbirinden bağımsız tercihlerdir. Varsayılan sistem teması, Liquid Glass, standart cam, deniz mavisi vurgu ve %35 zemin yoğunluğudur. macOS 26’da SwiftUI glassEffect kullanılır; önceki macOS sürümlerinde ultraThinMaterial karşılığı vardır. Reduce Transparency opak yüzey kullanır; kayıtlı seçim değiştirilmez. NSWindow appearance ve SwiftUI preferredColorScheme birlikte güncellenir.

Dev Island markası, yüzen kapsül ve D şeklindeki gelgit yayıdır. Menü çubuğu, uygulama ikonu ve ayarlar aynı geometriyi kullanır. Turuncu Clawd, Claude oturumlarını temsil eder. Oturum kartlarında semantic colors kullanılır; sabit koyu zeminler kaldırılmıştır.

## Ada geçişi

IslandTransition görünür boyutu, köşe yarıçapını ve içerik opaklığını tek monotonic saat üzerinden örnekler. Açılma 320 ms, kapanma 240 ms, Reduce Motion 100 ms sürer. Her yeni hedef, o andaki geometriyi başlangıç kabul eder. Aynı hedef yeniden animasyon başlatmaz.

AppKit pencere boyutu ve SwiftUI içerik aynı örnekle güncellenir. Sürekli çalışan resize animasyonu yoktur; 60 Hz zamanlayıcı yalnızca geçiş sırasında aktiftir. Kompakt/bildirim/liste içerikleri aynı host içinde kalır. Geniş içerikler arasında önce 80 ms solma, ardından 130 ms görünme uygulanır. Üst merkez ekranın üst ortasında sabittir.

Hover açılışı 120 ms, çıkış kapanışı 400 ms gecikmelidir. Her hover kararı bir nesil bileti taşır; eski callback yeni durumu kapatamaz. Tıklamayla açılmış liste sabitlenir. Bildirim 8 saniye görünür; hover süresince sayaç durur.

## Clawd ve masaüstü

ClawdView native Canvas piksel geometri kullanır. Boşta, çalışıyor, soru, plan, izin, kutlama, hata ve bağlantı kesilmesi görünümleri vardır. Aynı bileşen adada, ayarlarda ve masaüstünde kullanılır.

CompanionResolver soru/onay → hata → okunmamış tamamlanma → çalışan oturum önceliğini belirler. Kutlama yalnızca yeni, canlı ve susturulmamış tamamlanma için bir kez başlatılır; replay ve yeniden doğrulanmamış veriler kutlama üretmez. Kutlama 1,6 saniye sonra sakin poza döner. Okunma işaretleri UserDefaults tercihlerinde tutulur; oturuma bakmak bekleyen soruyu çözmez.

Masaüstü maskotu varsayılan 96 pt’tir; 64–160 pt arasında boyutlandırılabilir. Kendi kendine yürümez. Sürükleme ve tıklama 4 pt eşikle ayrılır. Ekran kimliği ve göreli konum saklanır, Dock/menu hariç visibleFrame içinde sınırlandırılır. Eksik ekranda ana ekrana taşınır. Tıklama bağlı etkinlik panelini açar; sağ tık gizleme, boyut ve konum eylemlerini sunar. Şeffaf dış alanlarda pencere mouse event’lerini geçirecek şekilde ayarlanır; bunun için yalnızca mouse hareket monitor’ları kullanılır.

Ada + maskot, yalnızca ada ve yalnızca maskot seçenekleri vardır. Gizlenen maskot menü çubuğundan yeniden açılır. Maskot, bildirim ve ses üretmez. Gizlenen yüzeylerde ve uyku/oturum kilidinde animasyon saatleri durur. Reduce Motion sabit pozları kullanır.

## Kalıcılık ve taşınma

Yeni Preferences decoder’ı her alanı kendi varsayılanıyla çözümler. Eski ses, terminal, kısayol, saklama ve kanal tercihleri korunur. Hook event v1 formatı ve kullanıcı veri dizini değişmez. Proje taşınırken SwiftPM/Clang önbellekleri taşınmamış, hedefte yeniden üretilmiştir. Eski kaynak çalışma klasöründeki kurtarma arşivine alınır; sohbet outputs klasörü yalnızca yayın paketleri, önizleme ve dokümanlar taşır.

## Doğrulama

40 birim/entegrasyon testi geçmiştir; son rapor için VALIDATION.md esas alınır. Gerçek Unix socket ve SwiftData testleri, statik önizleme ve canlı macOS testleri ayrı kaydedilir. ImageRenderer, camın gerçek desktop örneklemesini doğrulayamaz. Yayın imzası/notarization ve temiz ikinci Mac kabulü ayrı işlerdir.
