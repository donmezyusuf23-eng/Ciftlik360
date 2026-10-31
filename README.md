# 🚜 Çiftlik360 - Mobil Çiftlik Yönetim Sistemi

Modern, sade ve tamamen **çevrimdışı (offline-first)** çalışan Flutter tabanlı büyükbaş hayvancılık ve çiftlik yönetim uygulaması.

---

## ✨ Öne Çıkan Özellikler

- 🐮 **Hayvan Yönetimi:**
  - Küpe numarası, ırk, cinsiyet ve yaş takibi.
  - Hayvanın tam yaş hesabı (yıl ve ay cinsinden otomatik hesaplama).
  - Cinsiyet filtreleri (Tümü, Dişi ♀, Erkek ♂).

- 🤰 **Akıllı Gebelik & Tohumlama Takibi:**
  - Tek dokunuşla gebelik başlatma (*Gebe Kaldı / Tohumlandı* butonu).
  - 283 günlük otomatik doğum geri sayımı ve yaklaşan doğum bildirim kartı.
  - Doğum sonlandırma (*Doğurdu* veya *Boş Döndü* seçenekleri).

- 🥛 **Süt Takip Modülü:**
  - ☀️ Sabah ve 🌙 Akşam sağımları için özel kartlar.
  - Günlük toplam süt sayacı (her gün gece 00:00'da otomatik sıfırlanır, geçmişi saklar).
  - Geçmiş sağım kayıtları listesi ve litre detayları.

- 💰 **Kasa & Finans Yönetimi:**
  - Gelir / Gider kayıtları.
  - **Geçmiş Ay Gezintisi:** `< EKİM 2026 >` çubuğuyla istenen geçmiş aya ait bilanço ve kâr/zarar incelemesi.
  - "Tüm Zamanlar" genel çiftlik maliyet özeti.

- 🔒 **%100 Çevrimdışı Güvenlik:**
  - Hiçbir sunucuya veya internet bağlantısına ihtiyaç duymaz.
  - SQLite tabanlı yerel veritabanı ile veriler doğrudan cihaz hafızasında saklanır.
  - Dahili tek tuşla metin tabanlı bulut/mesaj yedekleme ve geri yükleme sistemi.

- 🇹🇷 **Tam Türkçe Arayüz ve Takvim:**
  - Yerelleştirilmiş Türkçe takvim ve çiftçiye özel büyük, okunaklı butonlar.

---

## 📱 Ekran Görüntüleri & Kurulum

Proje kök dizinindeki hazır `Ciftlik360.apk` dosyasını Android telefonunuza yükleyerek doğrudan kullanabilirsiniz.

### Geliştirici Kurulumu (Flutter):
```bash
cd ciftlik360_app
flutter pub get
flutter run
```

APK Derlemek için:
```bash
flutter build apk --release
```

---

## 👥 Geliştiriciler & Katkıda Bulunanlar

- [donmezyusuf23-eng](https://github.com/donmezyusuf23-eng) (Yusuf Dönmez)
- [cihan470](https://github.com/cihan470) (Cihan Pektaş)

