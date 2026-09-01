/* ============================================================
   GÖREVTAKİP — TEST VERİSİ
   ------------------------------------------------------------
   İçerik:  1 kullanıcı, 4 kategori, 20 görev

   ⭐ TARİHLER GÖRECELİDİR.
      Sabit tarih yazsaydık, birkaç ay sonra tüm görevler
      "gecikmiş" görünürdü. Bunun yerine GETDATE() üzerinden
      hesaplıyoruz — script ne zaman çalıştırılırsa çalıştırılsın
      gecikmiş / bugün / yaklaşan senaryoları doğru görünür.

   KULLANIM:
     1. Önce tablolar oluşturulmuş olmalı (01-veritabani.md)
     2. SSMS'te aç, Ctrl+A, F5
     3. En alttaki doğrulama sorguları sonucu gösterir
   ============================================================ */

USE GorevDB;
GO


/* ------------------------------------------------------------
   TEMİZLİK — sıra önemli: önce çocuk tablo
   ------------------------------------------------------------ */
IF OBJECT_ID('gorev_etiket', 'U') IS NOT NULL
    DELETE FROM gorev_etiket;      -- opsiyonel modül tablosu

DELETE FROM gorev;
DELETE FROM kategori;
DELETE FROM kullanici;
GO

DBCC CHECKIDENT ('gorev',     RESEED, 0);
DBCC CHECKIDENT ('kategori',  RESEED, 0);
DBCC CHECKIDENT ('kullanici', RESEED, 0);
GO


/* ============================================================
   1) KULLANICI

   Kullanıcı adı : admin
   Şifre         : gorev123

   ⚠️ Aşağıdaki hash BOŞ BIRAKILMIŞTIR.
      Modül 2'de kendi kodunuzla üreteceksiniz:
          KullaniciRepository.SifreyiHashle("gorev123")
      Çıkan 64 karakterlik değeri buraya yapıştırın.

      Bu kasıtlıdır — hash'i hazır vermek yerine öğrencinin
      kendi üretmesi, kavramı somutlaştırır.
   ============================================================ */

-- INSERT INTO kullanici (kullanici_adi, sifre_hash, ad_soyad)
-- VALUES ('admin', 'BURAYA_URETTIGINIZ_HASH', N'Sistem Yöneticisi');
-- GO


/* ============================================================
   2) KATEGORİLER
   ============================================================ */
INSERT INTO kategori (kategori_ad, renk, aciklama) VALUES
    (N'İş',       'primary',   N'İşle ilgili görevler ve toplantılar'),
    (N'Okul',     'success',   N'Ders, ödev ve sınav hazırlıkları'),
    (N'Ev',       'warning',   NULL),                 -- ⭐ açıklaması NULL
    (N'Kişisel',  'info',      N'Kişisel gelişim ve sağlık');
GO


/* ============================================================
   3) GÖREVLER

   Dağılım (dashboard'da göreceğiniz sayılar):
     • Toplam        : 20
     • Tamamlanan    : 5
     • Devam ediyor  : 4
     • Beklemede     : 11
     • Gecikmiş      : 4
     • Bugün biten   : 2
     • Tarihsiz      : 4
   ============================================================ */

-- ───────── İŞ kategorisi ─────────
INSERT INTO gorev (kategori_id, baslik, aciklama, oncelik, durum, bitis_tarihi, tamamlanma_tarihi)
VALUES
    -- ⚠️ GECİKMİŞ: tarihi geçmiş, tamamlanmamış
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'İş'),
     N'Aylık satış raporunu hazırla',
     N'Eylül ayı rakamlarını tabloya dök, grafiklerle destekle.',
     3, N'Beklemede', DATEADD(day, -5, CAST(GETDATE() AS DATE)), NULL),

    -- ⚠️ GECİKMİŞ
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'İş'),
     N'Müşteri sunumunu güncelle',
     NULL,                                             -- açıklaması yok
     2, N'Devam ediyor', DATEADD(day, -2, CAST(GETDATE() AS DATE)), NULL),

    -- 📅 BUGÜN
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'İş'),
     N'Ekip toplantısı notlarını paylaş',
     N'Toplantıda konuşulan maddeleri özetleyip e-posta at.',
     2, N'Beklemede', CAST(GETDATE() AS DATE), NULL),

    -- ✅ TAMAMLANDI
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'İş'),
     N'Bütçe tablosunu kontrol et',
     N'Q3 harcamalarını gözden geçir.',
     2, N'Tamamlandi', DATEADD(day, -8, CAST(GETDATE() AS DATE)),
        DATEADD(day, -9, GETDATE())),

    -- Yaklaşan
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'İş'),
     N'Yeni proje teklifini yaz',
     N'Kapsam, süre ve maliyet tahmini içermeli.',
     3, N'Devam ediyor', DATEADD(day, 3, CAST(GETDATE() AS DATE)), NULL),

    -- Tarihsiz
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'İş'),
     N'LinkedIn profilini güncelle',
     NULL,
     1, N'Beklemede', NULL, NULL);
GO


-- ───────── OKUL kategorisi ─────────
INSERT INTO gorev (kategori_id, baslik, aciklama, oncelik, durum, bitis_tarihi, tamamlanma_tarihi)
VALUES
    -- ⚠️ GECİKMİŞ
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Okul'),
     N'Veritabanı ödevini teslim et',
     N'ER diyagramı ve normalizasyon adımları dâhil.',
     3, N'Beklemede', DATEADD(day, -1, CAST(GETDATE() AS DATE)), NULL),

    -- 📅 BUGÜN
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Okul'),
     N'Web programlama laboratuvarına hazırlan',
     N'ASP.NET Core MVC modüllerini tekrar et.',
     3, N'Devam ediyor', CAST(GETDATE() AS DATE), NULL),

    -- Yaklaşan
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Okul'),
     N'Vize sınavına çalış',
     N'İlk 6 hafta konuları.',
     3, N'Beklemede', DATEADD(day, 7, CAST(GETDATE() AS DATE)), NULL),

    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Okul'),
     N'Grup projesi için toplantı ayarla',
     NULL,
     2, N'Beklemede', DATEADD(day, 5, CAST(GETDATE() AS DATE)), NULL),

    -- ✅ TAMAMLANDI
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Okul'),
     N'Ders kayıtlarını yenile',
     N'Seçmeli dersleri de eklemeyi unutma.',
     3, N'Tamamlandi', DATEADD(day, -12, CAST(GETDATE() AS DATE)),
        DATEADD(day, -13, GETDATE())),

    -- ✅ TAMAMLANDI
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Okul'),
     N'Kütüphaneden kitapları iade et',
     NULL,
     1, N'Tamamlandi', DATEADD(day, -4, CAST(GETDATE() AS DATE)),
        DATEADD(day, -4, GETDATE()));
GO


-- ───────── EV kategorisi ─────────
INSERT INTO gorev (kategori_id, baslik, aciklama, oncelik, durum, bitis_tarihi, tamamlanma_tarihi)
VALUES
    -- ⚠️ GECİKMİŞ
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Ev'),
     N'Elektrik faturasını öde',
     N'Son ödeme tarihi geçti, gecikme faizi olabilir.',
     3, N'Beklemede', DATEADD(day, -3, CAST(GETDATE() AS DATE)), NULL),

    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Ev'),
     N'Market alışverişi yap',
     N'Süt, ekmek, yumurta, deterjan.',
     2, N'Beklemede', DATEADD(day, 1, CAST(GETDATE() AS DATE)), NULL),

    -- ✅ TAMAMLANDI
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Ev'),
     N'Çamaşır makinesinin servisini ara',
     NULL,
     2, N'Tamamlandi', DATEADD(day, -6, CAST(GETDATE() AS DATE)),
        DATEADD(day, -6, GETDATE())),

    -- Tarihsiz
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Ev'),
     N'Kitaplığı düzenle',
     NULL,
     1, N'Beklemede', NULL, NULL);
GO


-- ───────── KİŞİSEL kategorisi ─────────
INSERT INTO gorev (kategori_id, baslik, aciklama, oncelik, durum, bitis_tarihi, tamamlanma_tarihi)
VALUES
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Kişisel'),
     N'Diş hekimi randevusu al',
     N'6 aylık kontrol zamanı geldi.',
     2, N'Beklemede', DATEADD(day, 10, CAST(GETDATE() AS DATE)), NULL),

    -- ✅ TAMAMLANDI
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Kişisel'),
     N'Spor salonu üyeliğini yenile',
     NULL,
     1, N'Tamamlandi', DATEADD(day, -15, CAST(GETDATE() AS DATE)),
        DATEADD(day, -16, GETDATE())),

    -- Tarihsiz
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Kişisel'),
     N'C# kitabını bitir',
     N'Kalan 4 bölüm.',
     1, N'Devam ediyor', NULL, NULL),

    -- Tarihsiz
    ((SELECT kategori_id FROM kategori WHERE kategori_ad = N'Kişisel'),
     N'Fotoğraf arşivini yedekle',
     NULL,
     1, N'Beklemede', NULL, NULL);
GO


/* ============================================================
   DOĞRULAMA 1 — Genel sayılar
   Beklenen: toplam 20 / tamamlanan 5 / devam eden 4 / bekleyen 11
   ============================================================ */
SELECT
    COUNT(*)                                                AS toplam,
    SUM(CASE WHEN durum = N'Tamamlandi'   THEN 1 ELSE 0 END) AS tamamlanan,
    SUM(CASE WHEN durum = N'Devam ediyor' THEN 1 ELSE 0 END) AS devam_eden,
    SUM(CASE WHEN durum = N'Beklemede'    THEN 1 ELSE 0 END) AS bekleyen
FROM gorev
WHERE aktif_mi = 1;
GO


/* ============================================================
   DOĞRULAMA 2 — Gecikmiş ve bugün bitenler
   Beklenen: gecikmis = 4, bugun_biten = 2
   ============================================================ */
SELECT
    SUM(CASE WHEN bitis_tarihi IS NOT NULL
              AND bitis_tarihi < CAST(GETDATE() AS DATE)
              AND durum <> N'Tamamlandi'
             THEN 1 ELSE 0 END) AS gecikmis,

    SUM(CASE WHEN bitis_tarihi = CAST(GETDATE() AS DATE)
              AND durum <> N'Tamamlandi'
             THEN 1 ELSE 0 END) AS bugun_biten,

    SUM(CASE WHEN bitis_tarihi IS NULL THEN 1 ELSE 0 END) AS tarihsiz
FROM gorev
WHERE aktif_mi = 1;
GO


/* ============================================================
   DOĞRULAMA 3 — Kategori dağılımı
   ============================================================ */
SELECT k.kategori_ad,
       k.renk,
       COUNT(g.gorev_id) AS toplam,
       SUM(CASE WHEN g.durum = N'Tamamlandi' THEN 1 ELSE 0 END) AS tamamlanan
FROM kategori k
LEFT JOIN gorev g ON g.kategori_id = k.kategori_id AND g.aktif_mi = 1
WHERE k.aktif_mi = 1
GROUP BY k.kategori_ad, k.renk
ORDER BY toplam DESC;
GO


/* ============================================================
   DERSTE GÖSTERİLECEK — NULL'un tuzağı

   Bu iki sorguyu ÜST ÜSTE çalıştır ve farkı sor:

     SELECT COUNT(*) FROM gorev WHERE bitis_tarihi < GETDATE();
     SELECT COUNT(*) FROM gorev WHERE bitis_tarihi IS NULL;

   Birinci sorgu, tarihi NULL olan 4 görevi SAYMAZ.
   Çünkü SQL'de "NULL < herhangi bir şey" sonucu ne doğru
   ne yanlıştır — yine NULL'dur ve satır elenir.

   Sınıfa sor: "Tarihi olmayan görevler gecikmiş midir?"
   Cevap: Hayır. Bitiş tarihi yoksa gecikemez.
          Bu yüzden filtrelerimizde IS NOT NULL kontrolü var.
   ============================================================ */


/* ============================================================
   İSTEĞE BAĞLI — Soft delete testi

   UPDATE gorev SET aktif_mi = 0
   WHERE baslik = N'Kitaplığı düzenle';

   Uygulamada görev listeden kaybolur ama şu sorgu onu bulur:
   SELECT * FROM gorev WHERE aktif_mi = 0;

   Geri getirmek için:
   UPDATE gorev SET aktif_mi = 1
   WHERE baslik = N'Kitaplığı düzenle';
   ============================================================ */
