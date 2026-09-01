# GörevTakip — Web Programlama Ders Rehberi

ASP.NET Core MVC, ADO.NET ve Bootstrap 5 ile adım adım görev takip uygulaması.
Web programlamaya yeni başlayan öğrenciler için hazırlanmış, modül modül ilerleyen eğitmen rehberi.

---

## Ne öğretiyor?

Kullanıcı girişi olan, dashboard'lu, tam CRUD işlemleri yapan bir web uygulamasını sıfırdan inşa etmeyi.

```
kategori  (İş, Okul, Ev, Kişisel)
    │
    └── gorev  ("Raporu bitir", öncelik: Yüksek, bitiş: 15.10.2026)
```

**Kullanılan teknolojiler**

| Katman | Tercih | Neden |
|---|---|---|
| Web çatısı | ASP.NET Core MVC | Model/View/Controller ayrımı görsel olarak net |
| Veri erişimi | ADO.NET (saf SQL) | Öğrenci yazdığı SQL'i gözüyle görsün, sihir olmasın |
| Veritabanı | SQL Server Express | Ücretsiz, SSMS ile incelenebilir |
| Arayüz | Bootstrap 5 (CDN) | CSS'e vakit harcamadan düzgün görünüm |

---

## Modüller

Dosyalar sırayla okunacak şekilde birbirine bağlıdır.

| # | Modül | Süre | İçerik |
|---|---|---|---|
| — | [Proje planı](00-PROJE-PLANI.md) | — | Kullanım kılavuzu, takvim, mimari |
| 0 | [Veritabanı](01-veritabani.md) | 1 saat | Şema, `BIT` vs `NVARCHAR` tartışması |
| 1 | [Proje iskeleti ve layout](02-proje-ve-layout.md) | 1 saat | Proje oluşturma, ortak sayfa iskeleti |
| 2 | [Giriş sistemi](03-login.md) | 1-2 saat | Şifre hash'leme, çerez tabanlı oturum |
| 3 | [Kategori CRUD](04-kategori-crud.md) | 1-2 saat | İlk CRUD, `bool` ve `DBNull.Value` |
| 4 | [Görev CRUD](05-gorev-crud.md) | 2 saat | Nullable tarih, hesaplanan alanlar |
| 5 | [Durum ve filtreleme](06-gorev-durum-ve-filtre.md) | 1-2 saat | Hızlı eylemler, arama, filtre |
| 6 | [Dashboard](07-dashboard.md) | 1 saat | `SUM(CASE WHEN...)` ile istatistik |
| 7 | [Etiketler *(opsiyonel)*](08-opsiyonel-etiketler.md) | 1-2 saat | Çoktan çoğa ilişki, ara tablo |

**Ek:** [`EK-test-verisi.sql`](EK-test-verisi.sql) — 4 kategori, 20 görev

Toplam **8-10 ders saati**.

---

## Modül şablonu

Her modül aynı düzende:

| Bölüm | İşlevi |
|---|---|
| 🎯 Bu derste ne yapacağız | Derse başlarken tahtaya yazılacak hedef |
| 📖 Kavram | Kod yazmadan önceki teori |
| ⌨️ Adım adım kod | Satır satır açıklamalı, canlı yazılacak kod |
| ▶️ Çalıştır ve gör | Ekranda görünmesi gereken sonuç |
| ⚠️ Sık yapılan hatalar | Derste karşılaşılacak sorunlar ve çözümleri |
| ✏️ Öğrenci alıştırması | Ders sonu ödevi |

**Öğretim modeli:** Önce eğitmen yazar → sonra beraber → sonra öğrenci tek başına. Modül 4'ten itibaren klavye öğrencide.

---

## Başlarken

**Gerekenler**

- .NET SDK 10.0 *(veya 8.0 — tüm kodlar ikisinde de çalışır)*
- SQL Server Express + SSMS
- Visual Studio 2022 veya VS Code + C# Dev Kit

**Kurulum**

```bash
# Projeyi oluştur
dotnet new mvc -n GorevTakip
cd GorevTakip
dotnet add package Microsoft.Data.SqlClient

# Çalıştır
dotnet run
```

Ardından [Modül 0](01-veritabani.md) ile veritabanını kurun.

---

## İşlenen güvenlik konuları

Rehber boyunca dört güvenlik dersi, kod yazılırken doğal bağlamında veriliyor:

1. **SQL injection** ve parametreli sorgu — *Modül 2 ve 3*
2. **Şifre hash'leme**, düz metin saklamama — *Modül 2*
3. **Kullanıcı sayımı** (user enumeration) ve belirsiz hata mesajı — *Modül 2*
4. **Açık yönlendirme** (open redirect) ve `Url.IsLocalUrl` — *Modül 2 ve 5*

Ayrıca GET/POST ayrımının neden bir güvenlik konusu olduğu, veriyi değiştiren işlemlerin neden link olamayacağı örneklerle işleniyor.

---

## Ön koşul

Bu rehber bir **pekiştirme projesidir**. Öğrencinin daha önce en az bir CRUD uygulaması yazmış olduğu varsayılır; bilinen konular hızla geçilip yeni kavramlara odaklanılır.

İlk kez CRUD yazacak bir grup için modüllerin daha yavaş ilerletilmesi, özellikle Modül 3'ün iki ders saatine yayılması önerilir.

---

## Lisans

Eğitim amaçlı serbestçe kullanılabilir, çoğaltılabilir ve uyarlanabilir.

> ⚠️ Rehberdeki şifre hash'leme örneği (SHA256) **öğretim amaçlıdır**, gerçek projeler için yeterli değildir. Gerekçesi ve doğrusu Modül 2'de açıklanmıştır.
