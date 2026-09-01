# Modül 0 — Veritabanı

**Süre:** 1 ders saati
**Kim yazıyor:** Beraber

---

## 🎯 Bu derste ne yapacağız

`GorevDB` veritabanını kuracağız ve **ilk projedeki tasarım hatalarını düzelteceğiz.**

---

## 📖 Kavram: Geçen projeyi eleştirelim

Bu modülün asıl değeri burada. Tahtaya okul projesinin `is_active` alanını yaz:

```sql
is_active NVARCHAR(255) NOT NULL     -- okul projesi
```

**Sınıfa sor:** *"Bu alanın içine ne yazıyorduk?"*
→ `'1'` veya `'0'`

**Devam et:** *"Peki 255 karakterlik bir alana neden 1 karakter yazıyoruz? Ve biri buraya 'evet' yazarsa ne olur?"*

Veritabanı buna izin verir. Kimse engellemez. Sonra `WHERE is_active = '1'` sorgusu o kaydı hiç bulmaz ve kimse sebebini anlayamaz.

**Doğrusu:**
```sql
aktif_mi BIT NOT NULL DEFAULT 1      -- GörevTakip
```

| | `NVARCHAR(255)` | `BIT` |
|---|---|---|
| Yer | 255 karaktere kadar | 1 bit |
| İzin verilen değer | Her şey | Sadece 0 / 1 |
| C# karşılığı | `string` | `bool` |
| SQL'de yazımı | `= '1'` (tırnaklı) | `= 1` (tırnaksız) |
| Okuma | `GetString(...)` | `GetBoolean(...)` |

> **Ders çıkarımı:** *"Doğru veri tipini seçmek, sonradan yazacağınız yüzlerce satır kontrol kodundan sizi kurtarır. Veritabanı sizin için kural koyabiliyorsa, koysun."*

---

## ⌨️ Adım 1: Veritabanını oluştur

```sql
CREATE DATABASE GorevDB;
GO

USE GorevDB;
GO
```

---

## ⌨️ Adım 2: Tablolar

### kullanici

```sql
CREATE TABLE kullanici (
    kullanici_id  BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    kullanici_adi NVARCHAR(100) NOT NULL,
    sifre_hash    NVARCHAR(255) NOT NULL,   -- şifrenin kendisi DEĞİL, özeti
    ad_soyad      NVARCHAR(255) NOT NULL,
    created_date  DATETIME      NOT NULL DEFAULT GETDATE(),
    aktif_mi      BIT           NOT NULL DEFAULT 1
);
GO

CREATE UNIQUE INDEX kullanici_adi_unique ON kullanici(kullanici_adi);
GO
```

### kategori

```sql
CREATE TABLE kategori (
    kategori_id  BIGINT        NOT NULL IDENTITY(1,1) PRIMARY KEY,
    kategori_ad  NVARCHAR(100) NOT NULL,

    -- Bootstrap renk adı: primary, success, danger, warning, info, secondary
    -- Kategoriyi listede renkli rozetle göstermek için
    renk         NVARCHAR(20)  NOT NULL DEFAULT 'primary',

    -- ⭐ YENİ: NULL olabilen METİN alanı
    --    Okul projesinde sadece tarih NULL olabiliyordu.
    aciklama     NVARCHAR(500) NULL,

    created_date DATETIME      NOT NULL DEFAULT GETDATE(),
    updated_date DATETIME      NULL,
    aktif_mi     BIT           NOT NULL DEFAULT 1
);
GO

CREATE UNIQUE INDEX kategori_ad_unique ON kategori(kategori_ad);
GO
```

### gorev

```sql
CREATE TABLE gorev (
    gorev_id     BIGINT         NOT NULL IDENTITY(1,1) PRIMARY KEY,

    kategori_id  BIGINT         NOT NULL,      -- yabancı anahtar

    baslik       NVARCHAR(200)  NOT NULL,
    aciklama     NVARCHAR(MAX)  NULL,          -- uzun metin, boş olabilir

    -- 1 = Düşük, 2 = Orta, 3 = Yüksek
    oncelik      INT            NOT NULL DEFAULT 2,

    -- 'Beklemede', 'Devam ediyor', 'Tamamlandi'
    durum        NVARCHAR(20)   NOT NULL DEFAULT 'Beklemede',

    -- ⭐ YENİ: Formda BOŞ BIRAKILABİLEN tarih
    --    "Bu görevin son tarihi yok" demek mümkün olmalı
    bitis_tarihi DATE           NULL,

    -- Görev tamamlandığında doldurulur, aksi hâlde NULL
    tamamlanma_tarihi DATETIME  NULL,

    created_date DATETIME       NOT NULL DEFAULT GETDATE(),
    updated_date DATETIME       NULL,
    aktif_mi     BIT            NOT NULL DEFAULT 1
);
GO

ALTER TABLE gorev
    ADD CONSTRAINT gorev_kategori_fk
    FOREIGN KEY (kategori_id) REFERENCES kategori(kategori_id);
GO
```

---

## 📖 Tasarım kararlarını tartış

Bu üç soruyu sınıfa sor — hepsinin öğretici bir cevabı var:

**1. `oncelik` neden `INT`, neden metin değil?**
Sıralamak için. `ORDER BY oncelik DESC` yazınca Yüksek → Orta → Düşük gelir. Metin olsaydı alfabetik sıralanırdı: "Düşük, Orta, Yüksek" — anlamsız.

**2. `durum` neden `INT` değil, metin?**
Burada sıralama gerekmiyor, okunabilirlik önemli. SSMS'te tabloya baktığında `'Tamamlandi'` görmek, `3` görmekten iyi.
*(Tartışmaya açık bir karar — öğrenci itiraz ederse iyi. "Sen olsan nasıl yapardın?" diye sor.)*

**3. `tamamlanma_tarihi` neden ayrı bir alan? `durum` zaten var.**
`durum` "şu an ne durumda"yı söyler, `tamamlanma_tarihi` "ne zaman bitti"yi. İkincisi olmadan "bu hafta kaç görev bitirdim?" sorusunu cevaplayamayız. Dashboard'da kullanacağız.

---

## ⌨️ Adım 3: Test verisi

`EK-test-verisi.sql` dosyasını çalıştır. İçinde 4 kategori ve 20 görev var — bazıları tamamlanmış, bazıları gecikmiş.

---

## ▶️ Çalıştır ve gör: SQL alıştırmaları

Beraber yazın:

```sql
-- 1. Tüm aktif kategoriler
SELECT * FROM kategori WHERE aktif_mi = 1;
--                                     ↑ tırnak YOK, BIT tipi

-- 2. Görevler ve kategorileri
SELECT g.baslik, k.kategori_ad, g.durum
FROM gorev g
INNER JOIN kategori k ON g.kategori_id = k.kategori_id
WHERE g.aktif_mi = 1;

-- 3. Tamamlanmamış, yüksek öncelikli görevler
SELECT baslik, bitis_tarihi FROM gorev
WHERE durum <> 'Tamamlandi' AND oncelik = 3 AND aktif_mi = 1;

-- 4. ⭐ GECİKMİŞ görevler
--    Bitiş tarihi geçmiş ama hâlâ tamamlanmamış
SELECT baslik, bitis_tarihi FROM gorev
WHERE bitis_tarihi < GETDATE()
  AND durum <> 'Tamamlandi'
  AND aktif_mi = 1;

-- 5. Kategorilere göre görev sayısı
SELECT k.kategori_ad, COUNT(g.gorev_id) AS gorev_sayisi
FROM kategori k
LEFT JOIN gorev g ON g.kategori_id = k.kategori_id AND g.aktif_mi = 1
WHERE k.aktif_mi = 1
GROUP BY k.kategori_ad;
```

> **4. sorguda dur ve sor:** *"Bitiş tarihi olmayan (NULL) görevler bu listede çıkar mı?"*
> Cevap: **Hayır.** SQL'de `NULL < GETDATE()` karşılaştırması ne doğru ne yanlıştır — sonuç yine NULL'dur ve satır elenir. Bu, NULL'un en sık kafa karıştıran davranışıdır. Test ettirerek göster.

---

## ⚠️ Sık yapılan hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| `Conversion failed when converting the nvarchar value '1' to data type bit` | BIT alana tırnaklı yazılmış | `aktif_mi = 1` (tırnaksız) |
| NULL tarihli görevler filtreden kayboluyor | NULL karşılaştırması | `bitis_tarihi IS NULL` ayrı kontrol edilmeli |
| `Cannot insert duplicate key` | Aynı kategori adı ikinci kez | Farklı ad gir |
| FK hatası | Olmayan `kategori_id` | Önce kategori ekle |

---

## ✏️ Öğrenci alıştırması

1. Veritabanını kur, test verisini yükle.
2. Şu soruların SQL'ini yaz:
   - Bitiş tarihi **olmayan** görevleri listele
   - Bu ay tamamlanan görevleri listele
   - En çok görevi olan kategoriyi bul
   - Hiç görevi olmayan kategori var mı?
3. **Düşünme sorusu:** Bu sisteme "alt görev" (bir görevin içindeki maddeler) eklemek isteseydik kaç tablo gerekirdi? Çiz.

---

👉 Sonraki: [`02-proje-ve-layout.md`](02-proje-ve-layout.md)
