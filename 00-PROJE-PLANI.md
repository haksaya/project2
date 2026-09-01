# GörevTakip — Pekiştirme Projesi

**ASP.NET Core MVC + ADO.NET + Bootstrap 5**
Okul Yönetim Sistemi'nden sonra ikinci proje.

---

## Bu rehber neden var?

Öğrenciler ilk projede CRUD kalıbını **öğrendi**. Bu projede o kalıbı **kullanacaklar**.

Fark önemli: İlk rehber her satırı açıklıyordu. Bu rehber, bilinen kısımları hızla geçip **yeni olan şeylere** odaklanıyor. Öğrenci "bunu zaten biliyorum" dedikçe kendi ilerlemesini fark edecek — bu, projenin en değerli çıktısı.

> **İlk derste sınıfa söyle:** *"Bu projeyi ilkinden çok daha hızlı bitireceğiz. Aynı işi yapacağız ama artık nasıl yapıldığını biliyorsunuz. Süre farkını ölçün — ne kadar ilerlediğinizi göreceksiniz."*

---

## Ne yapacağız?

Kişisel bir **görev takip uygulaması**. Kullanıcı giriş yapar, görevlerini kategorilere ayırır, önceliklendirir, tamamlar.

```
kategori  (İş, Okul, Ev, Kişisel)
    │
    └── gorev  ("Ödevi bitir", öncelik: Yüksek, bitiş: 15.10.2026)
```

Sadece **iki tablo**. İlk projede dört tabloyla kalıbı tekrar ettirmiştik; burada amaç tekrar değil, yeni kavramlar.

---

## Öncekinden farkı ne? (Yeni öğrenilecekler)

Bu tablo bu rehberin varlık sebebidir. Derste tahtaya yaz:

| Konu | Okul projesinde | GörevTakip'te | Neden yeni? |
|---|---|---|---|
| **Aktiflik alanı** | `NVARCHAR(255)` → `'1'` | `BIT` → `true` | İlk projede "bu yanlış tasarım" demiştik. Şimdi doğrusunu yapıyoruz. |
| **Login sırası** | En sonda, opsiyonel | **En başta, Modül 2** | Baştan korumalı sistem kurmak gerçek hayattaki sıra |
| **NULL metin alanı** | Yoktu | `aciklama NVARCHAR(MAX) NULL` | `IsDBNull` kontrolü artık metinde de gerekiyor |
| **NULL tarih (formda)** | Yoktu | `bitis_tarihi DATE NULL` | Formda boş bırakılabilen tarih — `DateTime?` bağlama |
| **Hızlı eylem** | Yoktu | Listeden tek tıkla "tamamla" | Ayrı form sayfası olmadan POST |
| **Hesaplanan durum** | Yoktu | "Gecikmiş görev" kırmızı | Veritabanında olmayan, kodda hesaplanan bilgi |
| **Sıralama mantığı** | Alfabetik | Öncelik + tarih (`CASE WHEN`) | SQL'de koşullu sıralama |
| **Çoktan çoğa ilişki** | Yoktu | Etiketler *(opsiyonel)* | Ara tablo (junction table) kavramı |

---

## Ders takvimi

Toplam **8-10 ders saati**. İlk proje 14-16 saatti — bu farkı öğrenciye göster.

| # | Modül | Süre | Kim yazıyor? | Dosya |
|---|---|---|---|---|
| 0 | Veritabanı | 1 saat | Beraber | `01-veritabani.md` |
| 1 | Proje iskeleti ve layout | 1 saat | Eğitmen | `02-proje-ve-layout.md` |
| 2 | **Giriş sistemi** | 1-2 saat | Eğitmen | `03-login.md` |
| 3 | **Kategori CRUD** | 1-2 saat | Beraber | `04-kategori-crud.md` |
| 4 | **Görev CRUD** | 2 saat | Öğrenci + rehberlik | `05-gorev-crud.md` |
| 5 | Durum işlemleri ve filtreleme | 1-2 saat | Beraber | `06-gorev-durum-ve-filtre.md` |
| 6 | Dashboard | 1 saat | Öğrenci | `07-dashboard.md` |
| 7 | *Opsiyonel:* Etiketler (N:N) | 1-2 saat | Beraber | `08-opsiyonel-etiketler.md` |

**Ek:** `EK-test-verisi.sql` — 4 kategori, 20 görev

---

## Proje yapısı

İlk projeyle birebir aynı — öğrenci burada hiç kaybolmamalı:

```
GorevTakip/
│
├── Program.cs
├── appsettings.json
│
├── Models/
│   ├── Kullanici.cs          (+ GirisViewModel)
│   ├── Kategori.cs
│   ├── Gorev.cs
│   └── DashboardViewModel.cs
│
├── Data/
│   ├── KullaniciRepository.cs
│   ├── KategoriRepository.cs
│   ├── GorevRepository.cs
│   └── DashboardRepository.cs
│
├── Controllers/
│   ├── HesapController.cs
│   ├── HomeController.cs
│   ├── KategoriController.cs
│   └── GorevController.cs
│
└── Views/
    ├── Shared/_Layout.cshtml
    ├── Hesap/Giris.cshtml
    ├── Home/Index.cshtml
    ├── Kategori/  (Index, Create, Edit, Delete)
    └── Gorev/     (Index, Create, Edit, Delete, Details)
```

**Adlandırma:** Proje `GorevTakip`, veritabanı `GorevDB`, bağlantı anahtarı `GorevDb`.

---

## CRUD kalıbı — hatırlatma kartı

Öğrenci bu tabloyu ilk projeden biliyor. Yine de ilk derste tahtaya yaz, sonra sil:

| # | Controller metodu | HTTP | Repository metodu |
|---|---|---|---|
| 1 | `Index()` | GET | `TumunuGetir()` |
| 2 | `Create()` | GET | — |
| 3 | `Create(model)` | POST | `Ekle(model)` |
| 4 | `Edit(id)` | GET | `IdIleGetir(id)` |
| 5 | `Edit(model)` | POST | `Guncelle(model)` |
| 6 | `Delete(id)` | GET | `IdIleGetir(id)` |
| 7 | `DeleteConfirmed(id)` | POST | `PasifYap(id)` |

**Değişmeyen kurallar:**
- SQL'e değer **birleştirilmez**, parametre verilir
- `POST` sonrası `RedirectToAction` (F5 çift kayıt yapmasın)
- `ModelState.IsValid` sunucuda **tekrar** kontrol edilir
- Silme = `aktif_mi = 0` (soft delete)
- `using` bloğu bağlantıyı kapatır

---

## Sonraki adım

👉 [`01-veritabani.md`](01-veritabani.md)
