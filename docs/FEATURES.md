# ScreenShotForMac: Superapp Özellik Listesi

Mac'teki ve diğer platformlardaki ekran görüntüsü araçlarının özellikleri tek listede toplandı. Durum: Kasım 2026.

**İncelenen uygulamalar**

| Kısa ad | Uygulama | Güçlü olduğu alan |
|---|---|---|
| SH | Shottr | Hız, piksel ölçümü, OCR |
| CS | CleanShot X | Her şey bir arada, kayıt, cloud |
| SG | Snagit | Doküman ve eğitim içeriği, şablonlar |
| SX | ShareX (Win) | İş akışları, 80+ upload hedefi, araç çantası |
| GS | Greenshot | Basit editör, Office ve print export |
| FS | Flameshot | Açık kaynak, CLI, yapılandırma |
| SP | Snipaste | Pin, UI eleman algılama |
| XN | Xnapper | Otomatik güzelleştirme, hassas veri gizleme |
| MS | Monosnap | Cloud, video |
| LS | Lightshot | Tek tık paylaşım |
| PS / TS | PixelSnap / TextSniper | Ölçüm / OCR odaklı |
| KP | Kap | Açık kaynak ekran kaydı, eklenti sistemi |
| OS | macOS (Cmd+Shift+5) | Referans taban |

**Fazlar:** P0 = MVP · P1 = v1.0 public · P2 = v1.x · P3 = ileride / Pro

---

## 1. Ekran Görüntüsü Yakalama

| # | Özellik | Kaynak | Faz | macOS API / Not |
|---|---|---|---|---|
| 1.1 | Alan seçimi: crosshair, canlı boyut ve koordinat, büyüteç | Hepsi | P0 | Overlay `NSWindow` + ScreenCaptureKit |
| 1.2 | Pencere yakalama: hover ile vurgu, gölge aç/kapat, şeffaf veya düz arka plan | CS, SH, OS | P0 | `SCShareableContent` |
| 1.3 | Tam ekran: aktif ekran, tüm ekranlar | Hepsi | P0 | `SCScreenshotManager` |
| 1.4 | Arka plandaki veya kısmen kapalı pencereyi yakalama | SH, SX | P1 | `SCContentFilter(desktopIndependentWindow:)` |
| 1.5 | UI eleman algılama: buton, panel gibi alt öğelere otomatik snap | SP, SX | P2 | Accessibility API (`AXUIElement`) |
| 1.6 | Kaydırmalı yakalama: otomatik veya manuel kaydırma, birleştirme | SH, CS, SG, SX | P1 | Vision görüntü hizalama |
| 1.7 | Panoramik / yatay kaydırmalı yakalama | SG | P3 | — |
| 1.8 | Zamanlayıcı: 3, 5 ve 10 sn, geri sayım göstergesi | CS, OS, SX | P1 | — |
| 1.9 | Son alanı tekrar yakalama | CS, SX | P1 | — |
| 1.10 | Sabit boyut ve oran presetleri (1280×720, 16:9…) | CS, SX | P2 | — |
| 1.11 | Ekranı dondurma: animasyonlu içeriği yakalamadan önce sabitleme | CS, SH | P1 | Önce tam ekran snapshot, sonra seçim |
| 1.12 | Masaüstü ikonlarını gizle, temiz masaüstü | CS | P2 | Geçici overlay penceresi |
| 1.13 | Yakalama sırasında bildirimleri kapat | CS | P3 | Focus API sınırlı, rehberle çöz |
| 1.14 | İmleci dahil et / hariç tut | CS, OS, SX | P1 | `showsCursor` |
| 1.15 | Aralıklı otomatik yakalama (her N saniyede) | SX | P3 | — |
| 1.16 | Web sayfasının tamamını yakalama (URL ver) | SX | P3 | `WKWebView` snapshot |
| 1.17 | Çoklu monitör ve karışık DPI | Hepsi | P0 | `backingScaleFactor` |
| 1.18 | "All-in-one" modu: alan seç, sonra foto / kayıt / scroll / OCR seç | CS | P1 | Overlay üstünde toolbar |

## 2. Ekran Kaydı

| # | Özellik | Kaynak | Faz | macOS API / Not |
|---|---|---|---|---|
| 2.1 | Alan, pencere veya tam ekran video kaydı (MP4/MOV) | CS, SG, MS, KP, OS | P1 | `SCStream` + `AVAssetWriter` |
| 2.2 | GIF kaydı ve dışa aktarma (fps, boyut, kalite) | CS, SX, KP | P1 | ImageIO GIF |
| 2.3 | Sistem sesi ve mikrofon | CS, SG, KP | P1 | SCK audio (macOS 13+) |
| 2.4 | Webcam overlay (yuvarlak / köşe, taşınabilir) | CS, SG | P2 | AVFoundation |
| 2.5 | Tıklama ve tuş vuruşlarını gösterme | CS, KP | P2 | `CGEventTap` (Accessibility izni) |
| 2.6 | Kayıt sırasında duraklat / devam / iptal, süre göstergesi | CS, SG | P1 | — |
| 2.7 | Kayıt sırasında ekranda çizim | SG | P3 | — |
| 2.8 | Basit video editörü: trim, kırp, hız, ses kapat | CS, SG | P2 | `AVMutableComposition` |
| 2.9 | Ekran görüntülerinden video / slayt üretme | SG | P3 | — |
| 2.10 | Kayıt eklentileri (export hedefleri) | KP | P3 | Eklenti mimarisi |

## 3. Anlık Araçlar

| # | Özellik | Kaynak | Faz | macOS API / Not |
|---|---|---|---|---|
| 3.1 | Renk seçici: HEX, RGB, HSL, Swift/CSS formatı, geçmiş | SH, SX, SP | P0 | `CGImage` piksel okuma |
| 3.2 | Piksel cetveli: kenar algılayarak otomatik ölçüm | SH, PS | P1 | Luminance kenar tespiti |
| 3.3 | İki nokta ve alan ölçümü, ölçüleri kopyala | SH, PS, SX | P1 | — |
| 3.4 | Hizalama kontrolü (eleman hizası, kılavuz çizgiler) | PS | P3 | — |
| 3.5 | OCR: metni tanı ve kopyala, satır sonlarını koru veya birleştir | SH, CS, SG, TS | P0 | Vision `VNRecognizeTextRequest` |
| 3.6 | OCR çeviri (tanınan metni çevir) | — | P3 | Translation framework (macOS 15) |
| 3.7 | QR ve barkod okuma, QR üretme | SH, SX, TS | P1 | Vision + CoreImage `CIQRCodeGenerator` |
| 3.8 | Sadece ölç / renk al modu (kaydetmeden) | SH, PS | P1 | — |

## 4. Editör ve Annotation

| # | Özellik | Kaynak | Faz | Not |
|---|---|---|---|---|
| 4.1 | Ok: düz, eğri, çift başlı, stil presetleri | Hepsi | P0 | Vektör, sonradan düzenlenebilir |
| 4.2 | Çizgi, dikdörtgen, oval, yuvarlak köşe, dolgu ve kontur | Hepsi | P0 | — |
| 4.3 | Metin: font, boyut, arka plan balonu, kontur | Hepsi | P0 | — |
| 4.4 | Highlighter | Hepsi | P0 | Multiply blend |
| 4.5 | Kalem / serbest çizim, yumuşatma | Hepsi | P1 | — |
| 4.6 | Blur, pixelate, düz renkle kapatma | Hepsi | P0 | Core Image |
| 4.7 | Hassas veri otomatik gizleme (e-posta, kart no, token, telefon) | XN | P2 | OCR + regex |
| 4.8 | Akıllı silgi: arka plan rengiyle doldurma | SH, SG | P1 | Kenar örnekleme |
| 4.9 | Adım / numara balonları (1, 2, 3, A, B, C), otomatik artış | SH, CS, SG, GS | P1 | — |
| 4.10 | Büyüteç callout | SH, SG | P2 | — |
| 4.11 | Spotlight: alanı vurgula, gerisini karart | CS, SG | P2 | — |
| 4.12 | Konuşma balonu / callout şekilleri | SG, GS | P2 | — |
| 4.13 | Emoji ve stamp (damga) | SG, SX | P2 | — |
| 4.14 | Görsel ekleme (logo, başka bir screenshot) | SG, SX | P2 | — |
| 4.15 | Watermark | SX, MS | P2 | — |
| 4.16 | Kenar efektleri: yırtık kenar, çerçeve, gölge | GS, SX, SG | P2 | — |
| 4.17 | Simplify: UI'yi sade bloklara dönüştürme | SG | P3 | — |
| 4.18 | Smart Move: görüntüdeki öğeyi taşı, boşluğu doldur | SG | P3 | Vision segmentasyon + inpainting |
| 4.19 | El çizimi stili (hand-drawn) | SH | P2 | — |
| 4.20 | Crop, resize, döndür, çevir; annotation'lar birlikte döner | Hepsi, SH | P0 / P2 | — |
| 4.21 | Genişletilebilir tuval: çizimi görüntü dışına taşırma | SH, CS | P1 | — |
| 4.22 | Birden fazla görüntüyü birleştirme / bölme (combine, split) | SX, SG | P2 | — |
| 4.23 | Görüntü efektleri: parlaklık, kontrast, gri ton, keskinlik | SX, GS | P3 | Core Image |
| 4.24 | Seç, taşı, boyutlandır, hizala, katman sırası, kopyala-yapıştır | Hepsi | P0 | — |
| 4.25 | Undo / Redo | Hepsi | P0 | `UndoManager` |
| 4.26 | Zoom, pan, piksel ızgarası | SH, SX | P1 | — |
| 4.27 | Tek harfli araç kısayolları | SH, CS, GS | P0 | — |
| 4.28 | Stil presetleri ve favori renkler | CS, SG | P1 | — |
| 4.29 | Annotation'ı düzenlenebilir proje dosyası olarak kaydetme | CS, SG, GS | P2 | Kendi `.ssfm` paket formatı |

## 5. Görünüm ve Backdrop

| # | Özellik | Kaynak | Faz |
|---|---|---|---|
| 5.1 | Arka plan: gradient, düz renk, görsel, blur'lu wallpaper | SH, CS, XN | P1 |
| 5.2 | Padding, yuvarlak köşe, gölge, hizalama | SH, CS, XN | P1 |
| 5.3 | Otomatik denge (içeriği ortala, padding'i otomatik ayarla) | XN | P2 |
| 5.4 | Sosyal medya oran presetleri (X, LinkedIn, Instagram, App Store) | XN, CS | P2 |
| 5.5 | Cihaz / pencere mockup çerçevesi (genel macOS penceresi, tarayıcı çerçevesi) | XN, SG | P3 |
| 5.6 | Kayıtlı stil presetleri | XN, CS | P2 |

## 6. Pin ve Yüzen Pencereler

| # | Özellik | Kaynak | Faz | macOS API |
|---|---|---|---|---|
| 6.1 | Görüntüyü her zaman üstte sabitleme | SH, CS, SP | P1 | `NSPanel` floating |
| 6.2 | Opaklık, click-through, kilitleme | SP, CS | P2 | `ignoresMouseEvents` |
| 6.3 | Pin üstünde zoom, döndürme, anında annotation | SP | P2 | — |
| 6.4 | Panodaki metni / görseli pinleme | SP | P2 | — |
| 6.5 | Yakalama sonrası köşede önizleme (Quick Access): sürükle, kopyala, kaydet, aç, kapat | CS, OS | P0 | — |

## 7. Çıktı, Paylaşım ve Upload

| # | Özellik | Kaynak | Faz | Not |
|---|---|---|---|---|
| 7.1 | Panoya kopyala, otomatik kopyala | Hepsi | P0 | `NSPasteboard` |
| 7.2 | Kaydet: PNG, JPG, HEIC, WebP, PDF, kalite ayarı | Hepsi | P0 | ImageIO |
| 7.3 | Dosya adı şablonu (`{date}_{time}_{app}_{counter}`) | SH, SX, GS | P1 | — |
| 7.4 | Retina 2x'i 1x'e indirme | SH, CS | P1 | — |
| 7.5 | Sürükle-bırak export | SH, CS | P0 | `NSDraggingSource` |
| 7.6 | macOS Share menüsü, AirDrop | CS, OS | P1 | `NSSharingServicePicker` |
| 7.7 | Yazdır | GS, SG | P2 | `NSPrintOperation` |
| 7.8 | Uygulamaya gönder (Preview, Figma, Slack, Mail, harici editör) | GS, SX | P2 | `NSWorkspace.open` |
| 7.9 | Upload: S3 uyumlu (AWS, R2, MinIO), Imgur, FTP/SFTP, WebDAV, özel HTTP | SH, SX, GS, FS | P2 | SigV4, credential'lar Keychain'de |
| 7.10 | Kendi cloud servisi: link, şifreli link, süre sonu, görüntülenme sayısı | CS, MS, SG | P3 | Sunucu tarafı gerekir |
| 7.11 | Upload sonrası: link kopyala, kısalt, QR göster, tarayıcıda aç | SX | P2 | — |
| 7.12 | Dosya, klasör, pano veya URL'den upload; izlenen klasör | SX | P3 | — |
| 7.13 | Özel uploader tanımı (JSON config, ShareX `.sxcu` benzeri) | SX | P3 | — |

## 8. Otomasyon ve İş Akışları

| # | Özellik | Kaynak | Faz | Not |
|---|---|---|---|---|
| 8.1 | Yakalama sonrası aksiyon: editör aç / kopyala / kaydet / upload / önizleme | Hepsi | P0 | — |
| 8.2 | İş akışları: her hotkey'e ayrı aksiyon zinciri ve hedef | SX | P2 | Örnek: Hotkey X ile alan seç, blur uygula, S3'e at, linki kopyala |
| 8.3 | CLI (`ssfm capture --area --clipboard`) | FS | P2 | Komut satırı yardımcısı |
| 8.4 | URL scheme (`ssfm://capture?mode=area`) ve Raycast / Alfred | SH, CS | P1 | — |
| 8.5 | Shortcuts.app ve App Intents | CS | P2 | App Intents |
| 8.6 | AppleScript | — | P3 | — |

## 9. Geçmiş ve Arşiv

| # | Özellik | Kaynak | Faz |
|---|---|---|---|
| 9.1 | Yakalama geçmişi, menü bardan erişim | CS, SX, SP | P1 |
| 9.2 | Geçmişte arama (OCR metniyle arama dahil) | SG | P2 |
| 9.3 | Etiket, favori, klasör, kütüphane görünümü | SG | P3 |
| 9.4 | Saklama süresi, otomatik temizlik | CS | P2 |
| 9.5 | Silinen görüntüyü geri alma | CS | P2 |

## 10. Uygulama Kabuğu ve Ayarlar

| # | Özellik | Kaynak | Faz | macOS API |
|---|---|---|---|---|
| 10.1 | Menü bar uygulaması, Dock ikonu opsiyonel | Hepsi | P0 | `MenuBarExtra`, `LSUIElement` |
| 10.2 | Her mod için özelleştirilebilir global hotkey'ler | Hepsi | P0 | `KeyboardShortcuts` paketi |
| 10.3 | Sistem Cmd+Shift+3/4/5 yerine geçme rehberi | CS, SH | P1 | — |
| 10.4 | İzin onboarding'i: Screen Recording, Accessibility, Mikrofon | CS | P0 | `CGRequestScreenCaptureAccess` |
| 10.5 | Girişte başlat | Hepsi | P1 | `SMAppService` |
| 10.6 | Ayarlar: genel, kısayollar, kaydetme, editör, kayıt, upload, gelişmiş | Hepsi | P0 | SwiftUI `Settings` |
| 10.7 | Ayarları dışa / içe aktarma | SX, FS | P2 | JSON |
| 10.8 | Açık / koyu tema | Hepsi | P0 | — |
| 10.9 | Lokalizasyon (EN, TR, sonra topluluk çevirisi) | GS, FS | P1 | String Catalog |
| 10.10 | Otomatik güncelleme | CS | P1 | Sparkle 2 |
| 10.11 | Erişilebilirlik: VoiceOver, klavyeyle tam kullanım | — | P1 | — |
| 10.12 | Gizlilik: telemetri yok veya opt-in, tüm işleme cihazda | — | P0 | — |

---

## Diğerlerinde Olmayan Fikirler

Aşağıdakiler incelenen araçlarda yaygın değil:

1. **Tek araçta Shottr ölçümü, CleanShot kaydı ve ShareX iş akışları.** Mac'te bu üçünü birleştiren bir araç yok.
2. **ShareX ayarında, açık kaynak bir Mac aracı.** Mac'te ShareX'in boşluğu hâlâ dolu değil.
3. **Cihaz içi AI:** OCR metniyle geçmişte arama, hassas veriyi otomatik bulup gizleme, görüntüyü açıklayan alt metin üretme. Apple Vision ve Foundation Models kullanılırsa ağ bağlantısı gerekmez.
4. **Annotation diff:** iki screenshot'ı karşılaştırıp farkları vurgulama. QA ve tasarım review için faydalı.
5. **Markdown veya issue'ya tek tıkla aktarma:** upload et, `![](url)` kopyala ya da GitHub/Jira'ya ekle.

## Teknik Temel

- **Dil ve UI:** Swift 6. Ayarlar ve menü SwiftUI ile, overlay, editör tuvali ve pin AppKit ile.
- **Hedef:** macOS 14+.
- **Modüller:** Capture · Recording · Tools · Editor · Backdrop · Export · Upload · Workflow · History · Settings.
- **Dağıtım:** Developer ID, notarization ve Sparkle ile. App Store sandbox'ı Accessibility, CGEventTap ve scrolling capture'ı kısıtladığı için App Store sürümü ileriye kalsın.

## Public Yayın İçin Dikkat

- **Lisans:** ShareX, Greenshot ve Flameshot GPL lisanslı. Kodlarından parça alınırsa uygulamanın tamamı GPL olur. Özellik fikri almak serbest, kod ve asset kopyalamak değil.
- **Marka:** Diğer uygulamaların adını, ikonunu ve UI görünümünü kullanma. Özgün isim, ikon ve tasarım dili seç. Özellik isimlerini de kendin koy ("Scrolling Capture" gibi genel terimler sorun değil).
- **İzinler:** Screen Recording ve Accessibility izinlerinin neden gerektiğini onboarding'de açıkça yaz.
- **Gizlilik politikası:** Upload ve cloud özellikleri gelince zorunlu olur.

## Yol Haritası

| Faz | Kapsam |
|---|---|
| **P0 (MVP)** | Alan / pencere / tam ekran, büyüteç, renk seçici, OCR, temel editör (ok, şekil, metin, highlight, blur, crop, undo), kopyala / kaydet / sürükle, Quick Access önizleme, menü bar, hotkey'ler, ayarlar, izinler |
| **P1 (v1.0 public)** | Scrolling capture, video ve GIF kaydı, ses, cetvel, QR, adım sayacı, pin, backdrop, dosya adı şablonu, geçmiş, URL scheme, Sparkle, EN/TR |
| **P2 (v1.x)** | İş akışları, CLI, S3 / Imgur upload, webcam, tuş vuruşu gösterme, video trim, hassas veri gizleme, combine/split, Shortcuts |
| **P3 (Pro / ileride)** | Kendi cloud servisi, Simplify, Smart Move, mockup, kütüphane, panoramik yakalama, aralıklı yakalama |

---

## Durum (Status)

Kaynak: `Sources/` ve `App/Sources/` kodu, 26 Kasım 2026. Kodda karşılığı olanlara göre işaretlendi; ayrıntılı davranış test edilmedi.

**Gösterim:** **Var** = kodda çalışır durumda · **Kısmen** = bir kısmı var · **Yapılıyor** = modül veya iskelet var, geliştirme sürüyor · **Yok** = henüz başlanmadı

| Bölüm | Var | Kısmen | Yapılıyor | Yok |
|---|---|---|---|---|
| 1. Yakalama | 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 1.9, 1.11, 1.17, 1.18 | 1.14 (kayıtta var, ekran görüntüsünde ayar yok) | — | 1.7, 1.10, 1.12, 1.13, 1.15, 1.16 |
| 2. Ekran Kaydı | 2.1, 2.2, 2.3, 2.6 | 2.5 (tıklama vurgusu var, tuş gösterimi yok) | 2.8 (`ShotVideoEditor`) | 2.4, 2.7, 2.9, 2.10 |
| 3. Anlık Araçlar | 3.1, 3.2, 3.3, 3.5, 3.8 | 3.7 (okuma var, QR üretme yok) | — | 3.4, 3.6 |
| 4. Editör | 4.2, 4.3, 4.4, 4.5, 4.6, 4.8, 4.9, 4.10, 4.11, 4.14, 4.20, 4.24, 4.25, 4.26, 4.27 | 4.1 (çift başlı var, eğri ok yok), 4.28 (kalınlık presetleri var, favori renk yok) | 4.22 (`ShotCombine`) | 4.7, 4.12, 4.13, 4.15, 4.16, 4.17, 4.18, 4.19, 4.21, 4.23, 4.29 |
| 5. Backdrop | 5.1, 5.2, 5.6 | — | — | 5.3, 5.4, 5.5 |
| 6. Pin | 6.1, 6.5 | 6.2 (opaklık ve click-through var, kilit yok), 6.3 (zoom ve döndürme var, annotation yok), 6.4 (panodan görsel var, metin yok) | — | — |
| 7. Çıktı ve Upload | 7.1, 7.3, 7.4, 7.5 | 7.2 (PNG, JPG, HEIC; WebP ve PDF yok) | 7.9 (S3 uyumlu ve özel HTTP, `ShotUpload`), 7.11 (link kopyala / tarayıcıda aç) | 7.6, 7.7, 7.8, 7.10, 7.12, 7.13 |
| 8. Otomasyon | 8.1 | 8.4 (`capture`, `ocr`, `color`, `qr`, `settings`) | 8.2, 8.5 (`ShotWorkflow`), 8.3 (`ShotCLI`, iskelet) | 8.6 |
| 9. Geçmiş | 9.1, 9.2, 9.4 | — | — | 9.3, 9.5 |
| 10. Kabuk ve Ayarlar | 10.1, 10.2, 10.3, 10.4, 10.5, 10.8, 10.9, 10.12 | 10.6 (upload sekmesi yok), 10.11 (VoiceOver etiketleri kısmen) | — | 10.7, 10.10 (Sparkle, bkz. `docs/RELEASING.md`) |
