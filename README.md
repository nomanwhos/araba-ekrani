# Torpido

iPhone ekranını arabanın CarPlay ekranına yansıtan kişisel uygulama. Sadece yolcuyken ya da araç park halindeyken kullanılır.

## Nasıl çalışır

```
iPhone ekranı ──► Yayın eklentisi (ReplayKit) ──► 127.0.0.1:48621 ──► Torpido uygulaması ──► CarPlay penceresi
                  ekranı yakalar, küçültür,        telefonun içinde       kareleri çözer        (navigation izni ile
                  JPEG'e çevirir (30 kare/sn)       kalır                                        çizilebilen pencere)
```

| Klasör | İçerik |
|---|---|
| `App/` | iPhone uygulaması: Perde ve Ayarlar sekmeleri, CarPlay ekranı, kareleri alan sunucu |
| `BroadcastExtension/` | Ekranı yakalayıp uygulamaya gönderen yayın eklentisi |
| `Shared/` | İkisinin ortak kullandığı kare formatı (`MirrorLink`, `FrameDecoder`) |
| `Tests/` | Kare formatının birim testleri |
| `project.yml` | Xcode projesinin tanımı (XcodeGen ile üretilir) |
| `.github/workflows/ios.yml` | Bulutta Mac üzerinde derleme, test ve ekran görüntüsü |
| `scripts/make_icon.py` | Uygulama ikonunu çizen betik (`App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` bunun çıktısı) |

## Durum

- [x] Kod yazıldı: yayın eklentisi, CarPlay ekranı, telefon arayüzü, testler
- [x] Bulutta derleme ve testler geçti
- [x] Apple Developer hesabı (Team ID 6UDRFAGF26)
- [ ] CarPlay navigation izni Apple'dan alındı
- [x] Telefona kuruldu (TestFlight 0.1.0 build 41, 2026-10-23)
- [ ] Arabada denendi (CarPlay izni bekleniyor)

## Apple tarafında yapılacaklar (sahibi yapar)

1. **Apple Developer Program'a katıl:** developer.apple.com/programs. Yıllık 99$.
2. **CarPlay izni iste:** developer.apple.com/carplay adresinden "Request CarPlay entitlement". Uygulamanın ne yaptığını dürüstçe yaz. Onay garanti değil.
3. **Onay gelince:** `project.yml` içinde `BUNDLE_ID_PREFIX` ve `DEVELOPMENT_TEAM` değerlerini kendi hesabınla değiştir. Telefona kurmak için imzalı derleme adımı o zaman eklenecek.

## Bilinen sınırlar

- Araba ekranına dokunmak telefonu kontrol etmez (iOS buna izin vermiyor).
- Görüntüde kısa bir gecikme olur. Ses, telefondaki uygulamadan arabaya normal yoldan gelir.
- Apple ReplayKit'in yayın API'sini ileride ScreenCaptureKit'e taşıyabilir. Derlemeden önce güncel belgeleri kontrol et.
