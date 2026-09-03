# Modül 4 — Görev CRUD

**Süre:** 2 ders saati
**Kim yazıyor:** Beraber — kodun tamamı rehberde, sen tahtada yazarken öğrenci ekranda takip eder

---

## 🎯 Bu derste ne yapacağız

Ana tablo. Kalıp tanıdık — **üç yeni ayrıntı** var:

1. Formda **boş bırakılabilen tarih** (`DateTime?`)
2. Veritabanında olmayan, **kodda hesaplanan** bilgi ("gecikmiş mi?")
3. SQL'de **koşullu sıralama** (`CASE WHEN`)

> **Ders formatı:** Kodun tamamı bu dosyada. Kategori modülündeki gibi satır satır beraber yazın. Bilinen kısımları (using satırları, `using` blokları, `TempData`) hızlı geçin, yukarıdaki üç yeni konuda durun.

---

## 🗣️ Derse başlangıç — 10 dakika

Tahtaya yaz ve dersin sonuna kadar silme:

```
GÖREV CRUD
  □ Models/Gorev.cs
  □ Data/GorevRepository.cs      → 5 metot + yardımcı
  □ Program.cs                   → AddScoped
  □ Controllers/GorevController.cs → 7 metot + KategoriListesiniHazirla
  □ Views/Gorev/                 → Index, Create, Edit, Delete, Details
```

**Sor:** *"Kategori CRUD'da açılır liste yoktu. Görevde olacak. Neden?"*
→ Görev bir kategoriye bağlı (yabancı anahtar). Kullanıcı isim seçer, veritabanına id gider.

**Kural:** *"Hata alınca önce hata mesajını okuyun, sonra Kategori modülüne bakın. Aynı hatayı orada da yaşadık."*

---

## ⌨️ Adım 1: Model

`Models/Gorev.cs`:

```csharp
using System.ComponentModel.DataAnnotations;

namespace GorevTakip.Models;

public class Gorev
{
    public long GorevId { get; set; }

    [Required(ErrorMessage = "Kategori seçmelisiniz.")]
    [Display(Name = "Kategori")]
    public long KategoriId { get; set; }          // yabancı anahtar

    [Required(ErrorMessage = "Başlık zorunludur.")]
    [StringLength(200, ErrorMessage = "En fazla 200 karakter.")]
    [Display(Name = "Başlık")]
    public string Baslik { get; set; } = "";

    // İsteğe bağlı uzun metin
    [Display(Name = "Açıklama")]
    public string? Aciklama { get; set; }

    // 1 = Düşük, 2 = Orta, 3 = Yüksek
    [Required]
    [Range(1, 3, ErrorMessage = "Öncelik 1-3 arasında olmalı.")]
    [Display(Name = "Öncelik")]
    public int Oncelik { get; set; } = 2;

    [Required(ErrorMessage = "Durum seçmelisiniz.")]
    [Display(Name = "Durum")]
    public string Durum { get; set; } = "Beklemede";

    // ⭐ YENİ: formda BOŞ BIRAKILABİLEN tarih
    //    Sondaki ? olmasaydı, boş gönderilince "geçersiz tarih" hatası alırdık.
    [DataType(DataType.Date)]
    [Display(Name = "Bitiş tarihi")]
    public DateTime? BitisTarihi { get; set; }

    // Görev tamamlanınca dolar
    public DateTime? TamamlanmaTarihi { get; set; }

    public DateTime CreatedDate { get; set; }
    public DateTime? UpdatedDate { get; set; }
    public bool AktifMi { get; set; } = true;

    // ── Veritabanında OLMAYAN alanlar ────────────────────────
    // JOIN ile gelir. INSERT/UPDATE'te KULLANILMAZ!
    [Display(Name = "Kategori")]
    public string KategoriAd { get; set; } = "";
    public string KategoriRenk { get; set; } = "secondary";

    // ── HESAPLANAN ÖZELLİKLER ────────────────────────────────
    // Veritabanında yok, her okunduğunda hesaplanır.

    /// <summary>
    /// Görev tamamlandı mı?
    /// </summary>
    public bool TamamlandiMi => Durum == "Tamamlandi";

    /// <summary>
    /// ⭐ Görev gecikti mi?
    /// Üç koşulun HEPSİ gerekli:
    ///   1. Bitiş tarihi var mı?          (yoksa gecikemez)
    ///   2. O tarih geçmiş mi?
    ///   3. Görev hâlâ tamamlanmamış mı?  (tamamlandıysa gecikme sayılmaz)
    /// </summary>
    public bool GecikmisMi =>
        BitisTarihi.HasValue
        && BitisTarihi.Value.Date < DateTime.Today
        && !TamamlandiMi;

    /// <summary>
    /// Bitişe kaç gün kaldı? Tarih yoksa null.
    /// Negatif değer = gecikmiş.
    /// </summary>
    public int? KalanGun =>
        BitisTarihi.HasValue
            ? (BitisTarihi.Value.Date - DateTime.Today).Days
            : null;

    /// <summary>
    /// Öncelik sayısının okunabilir karşılığı.
    /// switch ifadesi: her değere bir sonuç eşler, "_" ise varsayılan.
    /// </summary>
    public string OncelikAdi => Oncelik switch
    {
        1 => "Düşük",
        2 => "Orta",
        3 => "Yüksek",
        _ => "Bilinmiyor"
    };

    /// <summary>
    /// Önceliğin Bootstrap renk sınıfı.
    /// </summary>
    public string OncelikRenk => Oncelik switch
    {
        1 => "secondary",
        2 => "warning",
        3 => "danger",
        _ => "light"
    };
}
```

### 📖 Hesaplanan özellik nedir?

```csharp
public bool TamamlandiMi => Durum == "Tamamlandi";
```

`=>` işareti "bu özellik saklanmaz, **her sorulduğunda hesaplanır**" demek. Veritabanında `tamamlandi_mi` diye bir sütun **yok** ve olmamalı.

**Sınıfa sor:** *"Neden bu bilgiyi veritabanında saklamıyoruz?"*
→ Çünkü `durum` alanından türetilebilir. Aynı bilgiyi iki yerde saklarsan, biri değişip diğeri değişmediğinde **tutarsızlık** olur. Buna "tek doğruluk kaynağı" ilkesi denir.

Aynı mantık `GecikmisMi` için de geçerli — üstelik o zamanla değişir. Bugün gecikmemiş görev, yarın gecikmiş olabilir. Sakladığın anda yanlış olur.

---

## ⌨️ Adım 2: Repository

`Data/GorevRepository.cs`:

```csharp
using Microsoft.Data.SqlClient;
using GorevTakip.Models;

namespace GorevTakip.Data;

public class GorevRepository
{
    private readonly string _baglantiMetni;

    public GorevRepository(IConfiguration configuration)
    {
        _baglantiMetni = configuration.GetConnectionString("GorevDb")!;
    }

    // ════════════════════════════════════════════════════════
    //  YARDIMCI: satırı nesneye çevir
    //
    //  ⚠️ Bu tabloda DÖRT tane NULL olabilen sütun var:
    //     aciklama, bitis_tarihi, tamamlanma_tarihi, updated_date
    //     Dördü de IsDBNull kontrolü ister.
    // ════════════════════════════════════════════════════════
    private Gorev SatiriNesneyeCevir(SqlDataReader okuyucu)
    {
        Gorev g = new Gorev();

        g.GorevId     = okuyucu.GetInt64(okuyucu.GetOrdinal("gorev_id"));
        g.KategoriId  = okuyucu.GetInt64(okuyucu.GetOrdinal("kategori_id"));
        g.Baslik      = okuyucu.GetString(okuyucu.GetOrdinal("baslik"));
        g.Oncelik     = okuyucu.GetInt32(okuyucu.GetOrdinal("oncelik"));
        g.Durum       = okuyucu.GetString(okuyucu.GetOrdinal("durum"));
        g.CreatedDate = okuyucu.GetDateTime(okuyucu.GetOrdinal("created_date"));

        // BIT sütunu → GetBoolean
        g.AktifMi     = okuyucu.GetBoolean(okuyucu.GetOrdinal("aktif_mi"));

        // ── NULL olabilen dört sütun ─────────────────────────
        int aciklamaSutun = okuyucu.GetOrdinal("aciklama");
        g.Aciklama = okuyucu.IsDBNull(aciklamaSutun)
            ? null
            : okuyucu.GetString(aciklamaSutun);

        int bitisSutun = okuyucu.GetOrdinal("bitis_tarihi");
        g.BitisTarihi = okuyucu.IsDBNull(bitisSutun)
            ? null
            : okuyucu.GetDateTime(bitisSutun);

        int tamamlanmaSutun = okuyucu.GetOrdinal("tamamlanma_tarihi");
        g.TamamlanmaTarihi = okuyucu.IsDBNull(tamamlanmaSutun)
            ? null
            : okuyucu.GetDateTime(tamamlanmaSutun);

        int guncellemeSutun = okuyucu.GetOrdinal("updated_date");
        g.UpdatedDate = okuyucu.IsDBNull(guncellemeSutun)
            ? null
            : okuyucu.GetDateTime(guncellemeSutun);

        return g;
    }

    // ════════════════════════════════════════════════════════
    //  1) READ — tüm aktif görevler (kategori bilgisiyle)
    // ════════════════════════════════════════════════════════
    public List<Gorev> TumunuGetir()
    {
        List<Gorev> liste = new List<Gorev>();

        string sql = @"SELECT g.gorev_id, g.kategori_id, g.baslik, g.aciklama,
                              g.oncelik, g.durum, g.bitis_tarihi, g.tamamlanma_tarihi,
                              g.created_date, g.updated_date, g.aktif_mi,
                              k.kategori_ad, k.renk
                       FROM gorev g
                       INNER JOIN kategori k ON g.kategori_id = k.kategori_id
                       WHERE g.aktif_mi = 1
                       ORDER BY
                           -- ⭐ KOŞULLU SIRALAMA (aşağıda açıklanıyor)
                           CASE WHEN g.durum = 'Tamamlandi' THEN 1 ELSE 0 END,
                           g.oncelik DESC,
                           CASE WHEN g.bitis_tarihi IS NULL THEN 1 ELSE 0 END,
                           g.bitis_tarihi";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                while (okuyucu.Read())
                {
                    Gorev g = SatiriNesneyeCevir(okuyucu);

                    // JOIN'den gelen ekstra sütunlar
                    g.KategoriAd   = okuyucu.GetString(okuyucu.GetOrdinal("kategori_ad"));
                    g.KategoriRenk = okuyucu.GetString(okuyucu.GetOrdinal("renk"));

                    liste.Add(g);
                }
            }
        }

        return liste;
    }

    // ════════════════════════════════════════════════════════
    //  2) READ — tek görev
    // ════════════════════════════════════════════════════════
    public Gorev? IdIleGetir(long id)
    {
        Gorev? sonuc = null;

        string sql = @"SELECT g.gorev_id, g.kategori_id, g.baslik, g.aciklama,
                              g.oncelik, g.durum, g.bitis_tarihi, g.tamamlanma_tarihi,
                              g.created_date, g.updated_date, g.aktif_mi,
                              k.kategori_ad, k.renk
                       FROM gorev g
                       INNER JOIN kategori k ON g.kategori_id = k.kategori_id
                       WHERE g.gorev_id = @id";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@id", id);
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                // while değil if — tek satır bekliyoruz
                if (okuyucu.Read())
                {
                    sonuc = SatiriNesneyeCevir(okuyucu);
                    sonuc.KategoriAd   = okuyucu.GetString(okuyucu.GetOrdinal("kategori_ad"));
                    sonuc.KategoriRenk = okuyucu.GetString(okuyucu.GetOrdinal("renk"));
                }
            }
        }

        return sonuc;   // bulunamazsa null — controller kontrol etmeli
    }

    // ════════════════════════════════════════════════════════
    //  3) CREATE
    // ════════════════════════════════════════════════════════
    public void Ekle(Gorev gorev)
    {
        // gorev_id yazılmaz (IDENTITY)
        // kategori_ad / renk hiç yazılmaz (bu tabloda yoklar)
        string sql = @"INSERT INTO gorev
                          (kategori_id, baslik, aciklama, oncelik, durum,
                           bitis_tarihi, tamamlanma_tarihi,
                           created_date, updated_date, aktif_mi)
                       VALUES
                          (@kategoriId, @baslik, @aciklama, @oncelik, @durum,
                           @bitisTarihi, @tamamlanmaTarihi,
                           @createdDate, NULL, 1)";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@kategoriId", gorev.KategoriId);
            komut.Parameters.AddWithValue("@baslik",     gorev.Baslik);
            komut.Parameters.AddWithValue("@oncelik",    gorev.Oncelik);
            komut.Parameters.AddWithValue("@durum",      gorev.Durum);

            // ⭐ NULL olabilen alanlar — DBNull.Value köprüsü
            komut.Parameters.AddWithValue("@aciklama",
                (object?)gorev.Aciklama ?? DBNull.Value);

            komut.Parameters.AddWithValue("@bitisTarihi",
                (object?)gorev.BitisTarihi ?? DBNull.Value);

            // Görev "Tamamlandi" olarak eklendiyse tamamlanma tarihi de yazılmalı
            if (gorev.Durum == "Tamamlandi")
                komut.Parameters.AddWithValue("@tamamlanmaTarihi", DateTime.Now);
            else
                komut.Parameters.AddWithValue("@tamamlanmaTarihi", DBNull.Value);

            komut.Parameters.AddWithValue("@createdDate", DateTime.Now);

            baglanti.Open();
            komut.ExecuteNonQuery();
        }
    }

    // ════════════════════════════════════════════════════════
    //  4) UPDATE
    // ════════════════════════════════════════════════════════
    public void Guncelle(Gorev gorev)
    {
        // ⚠️ WHERE'i unutursan TÜM görevler aynı kayda dönüşür
        string sql = @"UPDATE gorev
                       SET kategori_id       = @kategoriId,
                           baslik            = @baslik,
                           aciklama          = @aciklama,
                           oncelik           = @oncelik,
                           durum             = @durum,
                           bitis_tarihi      = @bitisTarihi,
                           tamamlanma_tarihi = @tamamlanmaTarihi,
                           updated_date      = @updatedDate
                       WHERE gorev_id        = @id";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@kategoriId", gorev.KategoriId);
            komut.Parameters.AddWithValue("@baslik",     gorev.Baslik);
            komut.Parameters.AddWithValue("@oncelik",    gorev.Oncelik);
            komut.Parameters.AddWithValue("@durum",      gorev.Durum);

            komut.Parameters.AddWithValue("@aciklama",
                (object?)gorev.Aciklama ?? DBNull.Value);

            komut.Parameters.AddWithValue("@bitisTarihi",
                (object?)gorev.BitisTarihi ?? DBNull.Value);

            // ⭐ Durum ile tamamlanma tarihini BİRLİKTE yönetiyoruz.
            //    Kullanıcı formdan "Tamamlandi" seçtiyse tarih yazılır;
            //    geri aldıysa tarih silinir. İkisi hep tutarlı kalır.
            if (gorev.Durum == "Tamamlandi")
            {
                // Zaten tamamlanmışsa eski tarihi koru, yeni tamamlandıysa şimdi yaz
                komut.Parameters.AddWithValue("@tamamlanmaTarihi",
                    (object?)gorev.TamamlanmaTarihi ?? DateTime.Now);
            }
            else
            {
                komut.Parameters.AddWithValue("@tamamlanmaTarihi", DBNull.Value);
            }

            komut.Parameters.AddWithValue("@updatedDate", DateTime.Now);
            komut.Parameters.AddWithValue("@id", gorev.GorevId);

            baglanti.Open();
            komut.ExecuteNonQuery();
        }

        // created_date'e dokunmuyoruz — kayıt tarihi değişmemeli
    }

    // ════════════════════════════════════════════════════════
    //  5) DELETE — soft delete
    // ════════════════════════════════════════════════════════
    public void PasifYap(long id)
    {
        // Kayıt SİLİNMİYOR, pasif işaretleniyor.
        // TumunuGetir() içindeki WHERE aktif_mi = 1 onu listeden gizler.
        string sql = @"UPDATE gorev
                       SET aktif_mi = 0, updated_date = @updatedDate
                       WHERE gorev_id = @id";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@updatedDate", DateTime.Now);
            komut.Parameters.AddWithValue("@id", id);

            baglanti.Open();
            komut.ExecuteNonQuery();
        }
    }

    // ════════════════════════════════════════════════════════
    //  BONUS — pasif görevi geri getir
    // ════════════════════════════════════════════════════════
    public void AktifYap(long id)
    {
        string sql = @"UPDATE gorev
                       SET aktif_mi = 1, updated_date = @updatedDate
                       WHERE gorev_id = @id";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@updatedDate", DateTime.Now);
            komut.Parameters.AddWithValue("@id", id);

            baglanti.Open();
            komut.ExecuteNonQuery();
        }
    }
}
```

`Program.cs`'e ekle:

```csharp
builder.Services.AddScoped<GorevRepository>();
```

---

### 📖 `CASE WHEN` ile koşullu sıralama

`TumunuGetir()` içindeki `ORDER BY` bloğu dört satır. Tek tek açıkla:

```sql
ORDER BY
    CASE WHEN g.durum = 'Tamamlandi' THEN 1 ELSE 0 END,   -- 1) tamamlananlar alta
    g.oncelik DESC,                                        -- 2) yüksek öncelik üste
    CASE WHEN g.bitis_tarihi IS NULL THEN 1 ELSE 0 END,    -- 3) tarihsizler alta
    g.bitis_tarihi                                         -- 4) yakın tarih üste
```

**Sor:** *"Sadece `ORDER BY bitis_tarihi` yazsaydık, tarihi olmayan görevler nereye giderdi?"*

SQL Server'da `NULL` değerler sıralamada **en başa** gelir. Yani "son tarihi olmayan" görevler listenin tepesinde otururdu — istediğimizin tam tersi.

```sql
CASE WHEN g.bitis_tarihi IS NULL THEN 1 ELSE 0 END
```

Bu satır geçici bir sütun üretir: tarihi olan satırlara `0`, olmayanlara `1`. Önce ona göre sıralayınca tarihi olanlar üstte kalır.

Aynı numara ilk satırda da kullanılıyor — tamamlanmış görevlere `1` verip alta itiyoruz.

> **Deney:** İlk iki `CASE WHEN` satırını sil, sayfayı yenile. Liste tamamen karışır. Öğrenci sıralamanın ne kadar belirleyici olduğunu böyle görür.

---

## ⌨️ Adım 3: Controller

`Controllers/GorevController.cs`:

```csharp
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;   // SelectList için
using GorevTakip.Data;
using GorevTakip.Models;

namespace GorevTakip.Controllers;

// [Authorize] yazmaya gerek YOK — Program.cs'teki global filtre
// zaten tüm controller'ları koruyor.
public class GorevController : Controller
{
    // ⭐ İKİ repository: biri görev için, biri açılır liste için
    private readonly GorevRepository _gorevRepo;
    private readonly KategoriRepository _kategoriRepo;

    public GorevController(GorevRepository gorevRepo, KategoriRepository kategoriRepo)
    {
        _gorevRepo = gorevRepo;
        _kategoriRepo = kategoriRepo;
    }

    // ════════════════════════════════════════════════════════
    //  YARDIMCI: kategori açılır listesini hazırla
    //
    //  Create ve Edit sayfalarında defalarca lazım olduğu için
    //  ayrı metoda alındı.
    // ════════════════════════════════════════════════════════
    private void KategoriListesiniHazirla(long? secili = null)
    {
        var kategoriler = _kategoriRepo.TumunuGetir();

        // (kaynak liste, value alanı, görünen metin, seçili değer)
        ViewBag.Kategoriler = new SelectList(kategoriler, "KategoriId", "KategoriAd", secili);
    }

    // ════════════════════════════════════════════════════════
    //  1) LİSTELEME
    //  GET: /Gorev
    // ════════════════════════════════════════════════════════
    public IActionResult Index()
    {
        return View(_gorevRepo.TumunuGetir());
    }

    // ════════════════════════════════════════════════════════
    //  2) YENİ KAYIT FORMU
    //  GET: /Gorev/Create
    // ════════════════════════════════════════════════════════
    public IActionResult Create()
    {
        KategoriListesiniHazirla();
        return View();
    }

    // ════════════════════════════════════════════════════════
    //  3) YENİ KAYDI KAYDET
    //  POST: /Gorev/Create
    // ════════════════════════════════════════════════════════
    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult Create(Gorev gorev)
    {
        // Tarayıcı doğrulaması F12 ile kandırılabilir.
        // Bu yüzden sunucuda TEKRAR kontrol ediyoruz.
        if (!ModelState.IsValid)
        {
            // ⭐ EN ÇOK UNUTULAN SATIR
            // ViewBag sadece o istek boyunca yaşar. POST yeni bir istektir,
            // önceki ViewBag yok olmuştur. Doldurmazsak açılır liste boş
            // gelir ve sayfa NullReferenceException ile çöker.
            KategoriListesiniHazirla(gorev.KategoriId);
            return View(gorev);   // kullanıcının yazdıkları kaybolmasın
        }

        _gorevRepo.Ekle(gorev);
        TempData["Basarili"] = $"\"{gorev.Baslik}\" görevi eklendi.";

        // POST-Redirect-GET: yönlendirme yapmazsak F5'te çift kayıt olur
        return RedirectToAction("Index");
    }

    // ════════════════════════════════════════════════════════
    //  4) DÜZENLEME FORMU
    //  GET: /Gorev/Edit/5
    // ════════════════════════════════════════════════════════
    public IActionResult Edit(long id)
    {
        Gorev? gorev = _gorevRepo.IdIleGetir(id);

        // Kullanıcı adres çubuğuna /Gorev/Edit/99999 yazabilir.
        // null kontrolü ZORUNLU.
        if (gorev == null)
            return NotFound();

        KategoriListesiniHazirla(gorev.KategoriId);   // mevcut kategori seçili gelsin
        return View(gorev);
    }

    // ════════════════════════════════════════════════════════
    //  5) DÜZENLEMEYİ KAYDET
    //  POST: /Gorev/Edit/5
    // ════════════════════════════════════════════════════════
    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult Edit(Gorev gorev)
    {
        if (!ModelState.IsValid)
        {
            KategoriListesiniHazirla(gorev.KategoriId);
            return View(gorev);
        }

        _gorevRepo.Guncelle(gorev);
        TempData["Basarili"] = "Görev güncellendi.";
        return RedirectToAction("Index");
    }

    // ════════════════════════════════════════════════════════
    //  6) SİLME ONAY SAYFASI
    //  GET: /Gorev/Delete/5
    // ════════════════════════════════════════════════════════
    public IActionResult Delete(long id)
    {
        Gorev? gorev = _gorevRepo.IdIleGetir(id);

        if (gorev == null)
            return NotFound();

        return View(gorev);
    }

    // ════════════════════════════════════════════════════════
    //  7) SİLMEYİ ONAYLA
    //  POST: /Gorev/Delete/5
    //
    //  Metot adı DeleteConfirmed çünkü C#'ta aynı isim + aynı imza ile
    //  iki metot olamaz. ActionName ile adres yine /Delete kalıyor.
    // ════════════════════════════════════════════════════════
    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public IActionResult DeleteConfirmed(long id)
    {
        _gorevRepo.PasifYap(id);
        TempData["Basarili"] = "Görev silindi.";
        return RedirectToAction("Index");
    }

    // ════════════════════════════════════════════════════════
    //  8) DETAY SAYFASI
    //  GET: /Gorev/Details/5
    // ════════════════════════════════════════════════════════
    public IActionResult Details(long id)
    {
        Gorev? gorev = _gorevRepo.IdIleGetir(id);

        if (gorev == null)
            return NotFound();

        return View(gorev);
    }
}
```

### ⚠️ En kritik satır

```csharp
if (!ModelState.IsValid)
{
    KategoriListesiniHazirla(gorev.KategoriId);   // ← BU
    return View(gorev);
}
```

**Deney yaptır:** Bu satırı sil, formu başlıksız gönder. Sayfa `NullReferenceException` ile çöker çünkü `ViewBag.Kategoriler` artık yok. Sonra geri ekle.

> Öğrencinin en çok takılacağı hata budur ve hata mesajı sebebi doğrudan söylemez. Önceden yaşatmak, ödev haftasında saatler kazandırır.

---

## ⌨️ Adım 4: Create.cshtml

`Views/Gorev/Create.cshtml`:

```html
@model GorevTakip.Models.Gorev
@{
    ViewData["Title"] = "Yeni görev";
}

<div class="row">
    <div class="col-lg-8">
        <div class="card border-0 shadow-sm">
            <div class="card-body">
                <form asp-action="Create" method="post">

                    @* Alan bazlı OLMAYAN hatalar burada görünür *@
                    <div asp-validation-summary="ModelOnly" class="alert alert-danger"></div>

                    <div class="mb-3">
                        <label asp-for="Baslik" class="form-label"></label>
                        <input asp-for="Baslik" class="form-control" autofocus
                               placeholder="Ne yapılacak?" />
                        <span asp-validation-for="Baslik" class="text-danger small"></span>
                    </div>

                    <div class="mb-3">
                        <label asp-for="Aciklama" class="form-label"></label>
                        <textarea asp-for="Aciklama" class="form-control" rows="3"></textarea>
                        <span asp-validation-for="Aciklama" class="text-danger small"></span>
                        <div class="form-text">İsteğe bağlı.</div>
                    </div>

                    <div class="row">

                        <div class="col-md-4 mb-3">
                            <label asp-for="KategoriId" class="form-label"></label>
                            <select asp-for="KategoriId" asp-items="ViewBag.Kategoriler"
                                    class="form-select">
                                @* Boş seçenek olmazsa ilk kategori otomatik seçili görünür
                                   ve kullanıcı farkında olmadan yanlış kategori kaydeder *@
                                <option value="">-- Kategori seçin --</option>
                            </select>
                            <span asp-validation-for="KategoriId" class="text-danger small"></span>
                        </div>

                        <div class="col-md-4 mb-3">
                            <label asp-for="Oncelik" class="form-label"></label>
                            @* Arka planda sayı gönderiyoruz ama kullanıcı metin görüyor *@
                            <select asp-for="Oncelik" class="form-select">
                                <option value="1">Düşük</option>
                                <option value="2" selected>Orta</option>
                                <option value="3">Yüksek</option>
                            </select>
                            <span asp-validation-for="Oncelik" class="text-danger small"></span>
                        </div>

                        <div class="col-md-4 mb-3">
                            <label asp-for="Durum" class="form-label"></label>
                            <select asp-for="Durum" class="form-select">
                                <option value="Beklemede">Beklemede</option>
                                <option value="Devam ediyor">Devam ediyor</option>
                                <option value="Tamamlandi">Tamamlandı</option>
                            </select>
                            <span asp-validation-for="Durum" class="text-danger small"></span>
                        </div>

                    </div>

                    @* ⭐ BOŞ BIRAKILABİLEN TARİH *@
                    <div class="mb-3">
                        <label asp-for="BitisTarihi" class="form-label"></label>
                        <input asp-for="BitisTarihi" type="date" class="form-control"
                               style="max-width: 220px;" />
                        <span asp-validation-for="BitisTarihi" class="text-danger small"></span>
                        <div class="form-text">
                            İsteğe bağlı. Boş bırakırsanız görevin son tarihi olmaz.
                        </div>
                    </div>

                    <hr />

                    <button type="submit" class="btn btn-success">
                        <i class="bi bi-check-lg"></i> Görevi kaydet
                    </button>
                    <a asp-action="Index" class="btn btn-outline-secondary">Vazgeç</a>

                </form>
            </div>
        </div>
    </div>
</div>

@section Scripts {
    @* Bu satır olmazsa hata mesajları ancak sunucuya gidip dönünce görünür *@
    <partial name="_ValidationScriptsPartial" />
}
```

### 📖 `DateTime?` neden şart?

Bu deneyi **mutlaka** yaptır:

1. Model'de `DateTime? BitisTarihi` yerine `DateTime BitisTarihi` yaz (soru işaretini sil)
2. Formda tarihi boş bırak, kaydet
3. Sonuç: **"The value '' is invalid"** — kayıt olmaz

**Neden?** `DateTime` bir *değer tipi*; boş olamaz, mutlaka bir tarih tutmak zorundadır. Boş metin gelince ASP.NET Core onu tarihe çeviremez ve `ModelState` geçersiz olur.

`DateTime?` ise "boş olabilir" demektir. Boş gelirse `null` olur, sorun çıkmaz.

> Aynı mantık `int?`, `bool?`, `long?` için de geçerli. Öğrenci bunu bir kez anlarsa çok yerde işine yarar.

---

## ⌨️ Adım 5: Edit.cshtml

`Views/Gorev/Edit.cshtml` — Create'in aynısı, **dört gizli alan** farkıyla:

```html
@model GorevTakip.Models.Gorev
@{
    ViewData["Title"] = "Görevi düzenle";
}

<div class="row">
    <div class="col-lg-8">
        <div class="card border-0 shadow-sm">
            <div class="card-body">
                <form asp-action="Edit" method="post">

                    @* ═══ GİZLİ ALANLAR ═══
                       Formda görünmeyen ama sunucuya taşınması gereken veriler.
                       Bunlar olmazsa POST'ta boş/sıfır gelirler. *@

                    @* Hangi kaydı güncelliyoruz? WHERE için şart. *@
                    <input type="hidden" asp-for="GorevId" />

                    @* Kayıt tarihi değişmemeli *@
                    <input type="hidden" asp-for="CreatedDate" />

                    @* Aktiflik durumu korunmalı *@
                    <input type="hidden" asp-for="AktifMi" />

                    @* Zaten tamamlanmış bir görev düzenleniyorsa
                       eski tamamlanma tarihi korunsun *@
                    <input type="hidden" asp-for="TamamlanmaTarihi" />

                    <div asp-validation-summary="ModelOnly" class="alert alert-danger"></div>

                    <div class="mb-3">
                        <label asp-for="Baslik" class="form-label"></label>
                        <input asp-for="Baslik" class="form-control" />
                        <span asp-validation-for="Baslik" class="text-danger small"></span>
                    </div>

                    <div class="mb-3">
                        <label asp-for="Aciklama" class="form-label"></label>
                        <textarea asp-for="Aciklama" class="form-control" rows="3"></textarea>
                        <span asp-validation-for="Aciklama" class="text-danger small"></span>
                    </div>

                    <div class="row">

                        <div class="col-md-4 mb-3">
                            <label asp-for="KategoriId" class="form-label"></label>
                            @* Controller'da KategoriListesiniHazirla(gorev.KategoriId)
                               çağrıldığı için mevcut kategori seçili gelir *@
                            <select asp-for="KategoriId" asp-items="ViewBag.Kategoriler"
                                    class="form-select">
                                <option value="">-- Kategori seçin --</option>
                            </select>
                            <span asp-validation-for="KategoriId" class="text-danger small"></span>
                        </div>

                        <div class="col-md-4 mb-3">
                            <label asp-for="Oncelik" class="form-label"></label>
                            @* asp-for kullandığımız için model'deki değere uyan
                               seçenek OTOMATİK işaretlenir — elle selected yazma *@
                            <select asp-for="Oncelik" class="form-select">
                                <option value="1">Düşük</option>
                                <option value="2">Orta</option>
                                <option value="3">Yüksek</option>
                            </select>
                            <span asp-validation-for="Oncelik" class="text-danger small"></span>
                        </div>

                        <div class="col-md-4 mb-3">
                            <label asp-for="Durum" class="form-label"></label>
                            <select asp-for="Durum" class="form-select">
                                <option value="Beklemede">Beklemede</option>
                                <option value="Devam ediyor">Devam ediyor</option>
                                <option value="Tamamlandi">Tamamlandı</option>
                            </select>
                            <span asp-validation-for="Durum" class="text-danger small"></span>
                        </div>

                    </div>

                    <div class="mb-3">
                        <label asp-for="BitisTarihi" class="form-label"></label>
                        <input asp-for="BitisTarihi" type="date" class="form-control"
                               style="max-width: 220px;" />
                        <span asp-validation-for="BitisTarihi" class="text-danger small"></span>
                        <div class="form-text">Boş bırakılabilir.</div>
                    </div>

                    @* Kayıt geçmişi — bilgi amaçlı, düzenlenemez *@
                    <div class="text-muted small mb-3">
                        <i class="bi bi-clock-history"></i>
                        Oluşturuldu: @Model.CreatedDate.ToString("dd.MM.yyyy HH:mm")

                        @if (Model.UpdatedDate.HasValue)
                        {
                            @* .Value şart — UpdatedDate nullable *@
                            <span> &nbsp;|&nbsp; Güncellendi: @Model.UpdatedDate.Value.ToString("dd.MM.yyyy HH:mm")</span>
                        }

                        @if (Model.TamamlanmaTarihi.HasValue)
                        {
                            <span> &nbsp;|&nbsp; Tamamlandı: @Model.TamamlanmaTarihi.Value.ToString("dd.MM.yyyy HH:mm")</span>
                        }
                    </div>

                    <hr />

                    <button type="submit" class="btn btn-success">
                        <i class="bi bi-check-lg"></i> Değişiklikleri kaydet
                    </button>
                    <a asp-action="Index" class="btn btn-outline-secondary">Vazgeç</a>

                </form>
            </div>
        </div>
    </div>
</div>

@section Scripts {
    <partial name="_ValidationScriptsPartial" />
}
```

> **Deney:** `<input type="hidden" asp-for="GorevId" />` satırını sil ve düzenlemeyi kaydet. Hiçbir şey değişmez — SQL `WHERE gorev_id = 0` olarak çalışır, hiçbir satır eşleşmez, **hata da vermez.** Sessizce başarısız olan hatalar en tehlikelileridir; öğrenci bunu bir kez yaşamalı.

---

## ⌨️ Adım 6: Index.cshtml

`Views/Gorev/Index.cshtml` — hesaplanan alanlar burada işe yarıyor:

```html
@model List<GorevTakip.Models.Gorev>
@{
    ViewData["Title"] = "Görevler";
}

@if (TempData["Basarili"] != null)
{
    <div class="alert alert-success alert-dismissible fade show">
        <i class="bi bi-check-circle"></i> @TempData["Basarili"]
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
}

<div class="card border-0 shadow-sm">

    <div class="card-header bg-white d-flex justify-content-between align-items-center">
        <span class="fw-semibold">Görevler (@Model.Count)</span>
        <a asp-action="Create" class="btn btn-success btn-sm">
            <i class="bi bi-plus-lg"></i> Yeni görev
        </a>
    </div>

    <div class="card-body p-0">

        @if (Model.Count == 0)
        {
            <div class="text-center text-muted py-5">
                <i class="bi bi-clipboard-check fs-1 d-block mb-2"></i>
                <p class="mb-3">Henüz görev yok.</p>
                <a asp-action="Create" class="btn btn-sm btn-success">İlk görevi ekle</a>
            </div>
        }
        else
        {
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th>Görev</th>
                        <th>Kategori</th>
                        <th class="text-center">Öncelik</th>
                        <th class="text-center">Durum</th>
                        <th>Bitiş</th>
                        <th class="text-end">İşlemler</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach (var g in Model)
                    {
                        @* ⭐ Gecikmiş görevin satırını kırmızı tonla *@
                        <tr class="@(g.GecikmisMi ? "table-danger" : "")">

                            <td>
                                @* Tamamlanan görevin başlığı üstü çizili ve soluk *@
                                <a asp-action="Details" asp-route-id="@g.GorevId"
                                   class="text-decoration-none fw-semibold
                                          @(g.TamamlandiMi ? "text-muted text-decoration-line-through" : "")">
                                    @g.Baslik
                                </a>

                                @* Açıklama NULL olabilir — kontrol et *@
                                @if (!string.IsNullOrWhiteSpace(g.Aciklama))
                                {
                                    <div class="text-muted small text-truncate" style="max-width: 320px;">
                                        @g.Aciklama
                                    </div>
                                }
                            </td>

                            <td>
                                <span class="badge bg-@g.KategoriRenk">@g.KategoriAd</span>
                            </td>

                            <td class="text-center">
                                <span class="badge bg-@g.OncelikRenk">@g.OncelikAdi</span>
                            </td>

                            <td class="text-center">
                                @if (g.TamamlandiMi)
                                {
                                    <span class="badge bg-success">Tamamlandı</span>
                                }
                                else if (g.Durum == "Devam ediyor")
                                {
                                    <span class="badge bg-info">Devam ediyor</span>
                                }
                                else
                                {
                                    <span class="badge bg-secondary">Beklemede</span>
                                }
                            </td>

                            <td class="small">
                                @* ⭐ Üç farklı durum: tarih yok / gecikmiş / normal *@
                                @if (!g.BitisTarihi.HasValue)
                                {
                                    <span class="text-muted fst-italic">—</span>
                                }
                                else if (g.GecikmisMi)
                                {
                                    <span class="text-danger fw-semibold">
                                        <i class="bi bi-exclamation-circle"></i>
                                        @g.BitisTarihi.Value.ToString("dd.MM.yyyy")
                                        (@(-g.KalanGun) gün gecikti)
                                    </span>
                                }
                                else
                                {
                                    <span>@g.BitisTarihi.Value.ToString("dd.MM.yyyy")</span>

                                    @if (!g.TamamlandiMi && g.KalanGun <= 3)
                                    {
                                        <span class="text-warning">(@g.KalanGun gün kaldı)</span>
                                    }
                                }
                            </td>

                            <td class="text-end text-nowrap">
                                <a asp-action="Edit" asp-route-id="@g.GorevId"
                                   class="btn btn-sm btn-outline-primary">
                                    <i class="bi bi-pencil"></i>
                                </a>
                                <a asp-action="Delete" asp-route-id="@g.GorevId"
                                   class="btn btn-sm btn-outline-danger">
                                    <i class="bi bi-trash"></i>
                                </a>
                            </td>
                        </tr>
                    }
                </tbody>
            </table>
        }

    </div>
</div>
```

> **`@g.BitisTarihi.Value` — `.Value` neden gerekli?**
> `BitisTarihi` bir `DateTime?`. Üzerinde `.ToString("dd.MM.yyyy")` çağırmak için önce "içindeki değeri al" demeliyiz. `.HasValue` kontrolünden **sonra** kullanmak güvenlidir.

---

## ⌨️ Adım 7: Delete.cshtml

`Views/Gorev/Delete.cshtml`:

```html
@model GorevTakip.Models.Gorev
@{
    ViewData["Title"] = "Görevi sil";
}

<div class="row">
    <div class="col-lg-7">
        <div class="card border-danger shadow-sm">

            <div class="card-header bg-danger text-white">
                <i class="bi bi-exclamation-triangle"></i> Silme onayı
            </div>

            <div class="card-body">

                <p>Bu görevi silmek üzeresiniz:</p>

                <dl class="row mb-4">
                    <dt class="col-sm-4">Başlık</dt>
                    <dd class="col-sm-8 fw-semibold">@Model.Baslik</dd>

                    <dt class="col-sm-4">Kategori</dt>
                    <dd class="col-sm-8">
                        <span class="badge bg-@Model.KategoriRenk">@Model.KategoriAd</span>
                    </dd>

                    <dt class="col-sm-4">Öncelik</dt>
                    <dd class="col-sm-8">
                        <span class="badge bg-@Model.OncelikRenk">@Model.OncelikAdi</span>
                    </dd>

                    <dt class="col-sm-4">Durum</dt>
                    <dd class="col-sm-8">@Model.Durum</dd>

                    <dt class="col-sm-4">Bitiş tarihi</dt>
                    <dd class="col-sm-8">
                        @if (Model.BitisTarihi.HasValue)
                        {
                            @Model.BitisTarihi.Value.ToString("dd.MM.yyyy")
                        }
                        else
                        {
                            <span class="text-muted fst-italic">Belirtilmemiş</span>
                        }
                    </dd>

                    <dt class="col-sm-4">Oluşturulma</dt>
                    <dd class="col-sm-8">@Model.CreatedDate.ToString("dd.MM.yyyy")</dd>
                </dl>

                <div class="alert alert-info small">
                    <i class="bi bi-info-circle"></i>
                    Kayıt veritabanından tamamen silinmez, pasif duruma alınır.
                    Bu sayede yanlışlıkla yapılan silmeler geri alınabilir.
                </div>

                <form asp-action="Delete" method="post">

                    @* name="id" ŞART!
                       Controller'daki DeleteConfirmed(long id) parametresi
                       "id" adını bekliyor. asp-for tek başına "GorevId"
                       adında bir alan üretirdi ve eşleşmezdi. *@
                    <input type="hidden" asp-for="GorevId" name="id" />

                    <button type="submit" class="btn btn-danger">
                        <i class="bi bi-trash"></i> Evet, sil
                    </button>
                    <a asp-action="Index" class="btn btn-outline-secondary">Vazgeç</a>

                </form>

            </div>
        </div>
    </div>
</div>
```

---

## ⌨️ Adım 8: Details.cshtml

`Views/Gorev/Details.cshtml`:

```html
@model GorevTakip.Models.Gorev
@{
    ViewData["Title"] = "Görev detayı";
}

<div class="row">
    <div class="col-lg-8">

        <div class="card border-0 shadow-sm">

            @* ───────── ÜST BAŞLIK ───────── *@
            <div class="card-body border-bottom">

                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <h5 class="mb-2 @(Model.TamamlandiMi ? "text-muted text-decoration-line-through" : "")">
                            @Model.Baslik
                        </h5>

                        <span class="badge bg-@Model.KategoriRenk">@Model.KategoriAd</span>
                        <span class="badge bg-@Model.OncelikRenk">@Model.OncelikAdi öncelik</span>

                        @if (Model.TamamlandiMi)
                        {
                            <span class="badge bg-success">Tamamlandı</span>
                        }
                        else if (Model.Durum == "Devam ediyor")
                        {
                            <span class="badge bg-info">Devam ediyor</span>
                        }
                        else
                        {
                            <span class="badge bg-secondary">Beklemede</span>
                        }
                    </div>
                </div>

                @* ⭐ Gecikme uyarısı — hesaplanan özelliğin işe yaradığı yer *@
                @if (Model.GecikmisMi)
                {
                    <div class="alert alert-danger mt-3 mb-0 py-2 small">
                        <i class="bi bi-exclamation-triangle-fill"></i>
                        Bu görev <strong>@(-Model.KalanGun) gün</strong> gecikti.
                    </div>
                }
                else if (!Model.TamamlandiMi && Model.KalanGun.HasValue && Model.KalanGun <= 3)
                {
                    <div class="alert alert-warning mt-3 mb-0 py-2 small">
                        <i class="bi bi-clock"></i>
                        Bitiş tarihine <strong>@Model.KalanGun gün</strong> kaldı.
                    </div>
                }
            </div>

            @* ───────── AÇIKLAMA ───────── *@
            <div class="card-body border-bottom">
                <h6 class="text-muted mb-2">Açıklama</h6>

                @if (string.IsNullOrWhiteSpace(Model.Aciklama))
                {
                    <p class="text-muted fst-italic mb-0">Açıklama girilmemiş.</p>
                }
                else
                {
                    @* white-space: pre-wrap → satır sonlarını koru *@
                    <p class="mb-0" style="white-space: pre-wrap;">@Model.Aciklama</p>
                }
            </div>

            @* ───────── TARİHLER ───────── *@
            <div class="card-body">
                <h6 class="text-muted mb-3">Tarihler</h6>

                <dl class="row mb-0">
                    <dt class="col-sm-4 fw-normal text-muted">Bitiş tarihi</dt>
                    <dd class="col-sm-8">
                        @if (Model.BitisTarihi.HasValue)
                        {
                            <span class="@(Model.GecikmisMi ? "text-danger fw-semibold" : "")">
                                @Model.BitisTarihi.Value.ToString("dd MMMM yyyy")
                            </span>
                        }
                        else
                        {
                            <span class="text-muted fst-italic">Belirtilmemiş</span>
                        }
                    </dd>

                    <dt class="col-sm-4 fw-normal text-muted">Oluşturulma</dt>
                    <dd class="col-sm-8">@Model.CreatedDate.ToString("dd.MM.yyyy HH:mm")</dd>

                    <dt class="col-sm-4 fw-normal text-muted">Son güncelleme</dt>
                    <dd class="col-sm-8">
                        @if (Model.UpdatedDate.HasValue)
                        {
                            @Model.UpdatedDate.Value.ToString("dd.MM.yyyy HH:mm")
                        }
                        else
                        {
                            <span class="text-muted">Henüz güncellenmemiş</span>
                        }
                    </dd>

                    <dt class="col-sm-4 fw-normal text-muted">Tamamlanma</dt>
                    <dd class="col-sm-8">
                        @if (Model.TamamlanmaTarihi.HasValue)
                        {
                            @Model.TamamlanmaTarihi.Value.ToString("dd.MM.yyyy HH:mm")
                        }
                        else
                        {
                            <span class="text-muted">—</span>
                        }
                    </dd>
                </dl>
            </div>

            @* ───────── İŞLEMLER ───────── *@
            <div class="card-footer bg-white">
                <a asp-action="Edit" asp-route-id="@Model.GorevId"
                   class="btn btn-primary btn-sm">
                    <i class="bi bi-pencil"></i> Düzenle
                </a>
                <a asp-action="Delete" asp-route-id="@Model.GorevId"
                   class="btn btn-outline-danger btn-sm">
                    <i class="bi bi-trash"></i> Sil
                </a>
                <a asp-action="Index" class="btn btn-outline-secondary btn-sm">
                    <i class="bi bi-arrow-left"></i> Listeye dön
                </a>
            </div>

        </div>

    </div>
</div>
```

---

## ▶️ Test senaryosu

| # | Test | Beklenen |
|---|---|---|
| 1 | Boş form gönder | Başlık ve kategori hatası |
| 2 | Tarihi boş bırak, kaydet | **Kaydolur** |
| 3 | SSMS'te bak | `bitis_tarihi` NULL |
| 4 | Listede o görev | Bitiş sütununda `—` |
| 5 | Dünkü tarihle görev ekle | Satır kırmızı, "1 gün gecikti" |
| 6 | O görevi "Tamamlandı" yap | Kırmızı gitti, başlık üstü çizili |
| 7 | SSMS'te bak | `tamamlanma_tarihi` doldu |
| 8 | 2 gün sonrası tarihli görev | "2 gün kaldı" sarı uyarı |
| 9 | Öncelik "Yüksek" | Kırmızı rozet, listede üstte |
| 10 | Hatalı gönderimden sonra | Açılır liste **dolu** |
| 11 | Sıralama | Tamamlananlar altta, tarihsizler en sonda |
| 12 | Detay sayfası | Gecikme uyarısı, açıklama, tarihler |
| 13 | Sil → onayla | Listeden gitti |
| 14 | SSMS'te bak | Kayıt duruyor, `aktif_mi = 0` |

---

## ⚠️ Sık yapılan hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| `The value '' is invalid` (tarih) | `DateTime` yerine `DateTime?` olmalı | Model'e `?` ekle |
| `Parameterized query expects '@bitisTarihi'` | NULL tarih doğrudan gönderilmiş | `?? DBNull.Value` |
| `Nullable object must have a value` | `.Value` çağrılıyor ama null | Önce `.HasValue` kontrol et |
| Açılır liste boş → çökme | POST'ta `KategoriListesiniHazirla` yok | Ekle |
| Tarihsiz görevler listenin başında | `ORDER BY` içinde NULL kontrolü yok | `CASE WHEN ... IS NULL` ekle |
| `Invalid column name 'renk'` | JOIN'de kategori tablosu yok | JOIN'i ekle |
| Gecikmiş görevler kırmızı olmuyor | Tarih karşılaştırmasında saat var | `.Date` kullan |
| Tamamlanan görev hâlâ "gecikmiş" | `!TamamlandiMi` koşulu eksik | `GecikmisMi` içindeki üç koşulu kontrol et |
| Düzenleme kaydediyor ama değişmiyor | Gizli `GorevId` yok | Ekle |
| Düzenleyince tamamlanma tarihi siliniyor | Gizli `TamamlanmaTarihi` yok | Ekle |
| `Unable to resolve service for GorevRepository` | `Program.cs`'e eklenmemiş | `AddScoped<GorevRepository>()` |
| Silme direkt siliyor, onay sormuyor | GET/POST ayrımı karışmış | GET onay sayfası, POST silme |

---

## ✏️ Öğrenci alıştırması

**A.** Görev CRUD'unu kendi projende baştan yaz. Bakarak yaz, kopyalama.

**B.** Bugün bitmesi gereken görevleri **turuncu** göster ("Bugün!" etiketi).
İpucu: model'e yeni bir hesaplanan özellik ekle:
```csharp
public bool BugunMu => BitisTarihi.HasValue
                    && BitisTarihi.Value.Date == DateTime.Today
                    && !TamamlandiMi;
```

**C.** Pasif görevler sayfası yaz. `aktif_mi = 0` olanları listelesin, her satırda "Geri getir" butonu olsun. `AktifYap` metodu repository'de hazır.

**D.** Görev eklerken bitiş tarihi **geçmişte** olamasın. Özel doğrulama yaz.
İpucu: `IValidatableObject` arayüzü veya özel bir `ValidationAttribute`.

**E.** Listede açıklaması olan görevlerin yanına küçük bir not ikonu koy, üzerine gelince açıklama görünsün.
İpucu: Bootstrap tooltip veya `title` niteliği.

**F. Düşünme soruları:**
1. `GecikmisMi` bilgisini veritabanında sütun olarak saklasaydık ne sorun çıkardı?
2. `ORDER BY`'daki `CASE WHEN` satırlarını silsek liste nasıl görünürdü? Dene.
3. Öncelik `INT`, durum `NVARCHAR`. Bu tutarsızlık mı, yoksa gerekçesi var mı?
4. `Guncelle` metodunda durum "Tamamlandi" değilse `tamamlanma_tarihi`'ni NULL yapıyoruz. Bu doğru mu, yoksa eski tarihi saklamalı mıydık?

---

👉 Sonraki: [`06-gorev-durum-ve-filtre.md`](06-gorev-durum-ve-filtre.md)
