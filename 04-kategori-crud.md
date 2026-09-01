# Modül 3 — Kategori CRUD

**Süre:** 1-2 ders saati
**Kim yazıyor:** Beraber — sen tahtada, öğrenci aynı anda ekranda

---

## 🎯 Bu derste ne yapacağız

İlk CRUD. Kalıp tanıdık, **iki yeni ayrıntı** var:

1. `bool` alanı okumak/yazmak (`BIT` sütunu)
2. `NULL` olabilen **metin** alanı (`aciklama`)

---

## 🗣️ Derse başlangıç — 5 dakika

Tahtaya sadece başlıkları yaz, gerisini **öğrencilere söylet**:

```
KATEGORİ CRUD
  □ Models/Kategori.cs
  □ Data/KategoriRepository.cs   → kaç metot?
  □ Program.cs                   → ne eklenecek?
  □ Controllers/KategoriController.cs → kaç metot?
  □ Views/Kategori/              → hangi dosyalar?
```

Cevaplar gelene kadar bekle. Gelmiyorsa `00-PROJE-PLANI.md`'deki hatırlatma kartına baktır. **Sen söyleme.**

---

## ⌨️ Adım 1: Model

`Models/Kategori.cs`:

```csharp
using System.ComponentModel.DataAnnotations;

namespace GorevTakip.Models;

public class Kategori
{
    public long KategoriId { get; set; }

    [Required(ErrorMessage = "Kategori adı zorunludur.")]
    [StringLength(100, ErrorMessage = "En fazla 100 karakter olabilir.")]
    [Display(Name = "Kategori adı")]
    public string KategoriAd { get; set; } = "";

    [Required(ErrorMessage = "Renk seçmelisiniz.")]
    [Display(Name = "Renk")]
    public string Renk { get; set; } = "primary";

    // ⭐ YENİ: NULL olabilen METİN alanı
    //    Sondaki ? → "bu değer null olabilir"
    //    [Required] YOK → boş bırakılabilir
    [StringLength(500, ErrorMessage = "En fazla 500 karakter olabilir.")]
    [Display(Name = "Açıklama")]
    public string? Aciklama { get; set; }

    public DateTime CreatedDate { get; set; }
    public DateTime? UpdatedDate { get; set; }

    // ⭐ YENİ: bool  (okul projesinde string IsActive = "1" idi)
    public bool AktifMi { get; set; } = true;

    // Veritabanında YOK — JOIN/COUNT ile gelir.
    // INSERT ve UPDATE sorgularında KULLANILMAZ!
    [Display(Name = "Görev sayısı")]
    public int GorevSayisi { get; set; }
}
```

### 📖 `string` ile `string?` farkı

```csharp
public string KategoriAd { get; set; } = "";    // boş olamaz, "" ile başlar
public string? Aciklama { get; set; }           // null olabilir
```

Bu fark sadece bir uyarı değil — repository'de **farklı okuma kodu** gerektirecek. Birazdan göreceğiz.

---

## ⌨️ Adım 2: Repository

`Data/KategoriRepository.cs`:

```csharp
using Microsoft.Data.SqlClient;
using GorevTakip.Models;

namespace GorevTakip.Data;

public class KategoriRepository
{
    private readonly string _baglantiMetni;

    public KategoriRepository(IConfiguration configuration)
    {
        _baglantiMetni = configuration.GetConnectionString("GorevDb")!;
    }

    // ════════════════════════════════════════════════════════
    //  YARDIMCI: satırı nesneye çevir
    // ════════════════════════════════════════════════════════
    private Kategori SatiriNesneyeCevir(SqlDataReader okuyucu)
    {
        Kategori k = new Kategori();

        k.KategoriId  = okuyucu.GetInt64(okuyucu.GetOrdinal("kategori_id"));
        k.KategoriAd  = okuyucu.GetString(okuyucu.GetOrdinal("kategori_ad"));
        k.Renk        = okuyucu.GetString(okuyucu.GetOrdinal("renk"));
        k.CreatedDate = okuyucu.GetDateTime(okuyucu.GetOrdinal("created_date"));

        // ⭐ BIT sütunu → GetBoolean
        k.AktifMi     = okuyucu.GetBoolean(okuyucu.GetOrdinal("aktif_mi"));

        // ⭐ NULL olabilen METİN — kontrolsüz okursak uygulama çöker
        int aciklamaSutun = okuyucu.GetOrdinal("aciklama");
        k.Aciklama = okuyucu.IsDBNull(aciklamaSutun)
            ? null
            : okuyucu.GetString(aciklamaSutun);

        // NULL olabilen TARİH — aynı mantık
        int guncellemeSutun = okuyucu.GetOrdinal("updated_date");
        k.UpdatedDate = okuyucu.IsDBNull(guncellemeSutun)
            ? null
            : okuyucu.GetDateTime(guncellemeSutun);

        return k;
    }

    // ════════════════════════════════════════════════════════
    //  1) READ — tüm aktif kategoriler + görev sayıları
    // ════════════════════════════════════════════════════════
    public List<Kategori> TumunuGetir()
    {
        List<Kategori> liste = new List<Kategori>();

        // Alt sorgu: her kategori için o kategorideki görevleri say
        string sql = @"SELECT k.kategori_id, k.kategori_ad, k.renk, k.aciklama,
                              k.created_date, k.updated_date, k.aktif_mi,
                              (SELECT COUNT(*) FROM gorev g
                               WHERE g.kategori_id = k.kategori_id
                                 AND g.aktif_mi = 1) AS gorev_sayisi
                       FROM kategori k
                       WHERE k.aktif_mi = 1
                       ORDER BY k.kategori_ad";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                while (okuyucu.Read())
                {
                    Kategori k = SatiriNesneyeCevir(okuyucu);
                    k.GorevSayisi = okuyucu.GetInt32(okuyucu.GetOrdinal("gorev_sayisi"));
                    liste.Add(k);
                }
            }
        }

        return liste;
    }

    // ════════════════════════════════════════════════════════
    //  2) READ — tek kategori
    // ════════════════════════════════════════════════════════
    public Kategori? IdIleGetir(long id)
    {
        Kategori? sonuc = null;

        string sql = @"SELECT kategori_id, kategori_ad, renk, aciklama,
                              created_date, updated_date, aktif_mi
                       FROM kategori
                       WHERE kategori_id = @id";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@id", id);
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                if (okuyucu.Read())
                    sonuc = SatiriNesneyeCevir(okuyucu);
            }
        }

        return sonuc;
    }

    // ════════════════════════════════════════════════════════
    //  3) CREATE
    // ════════════════════════════════════════════════════════
    public void Ekle(Kategori kategori)
    {
        string sql = @"INSERT INTO kategori
                          (kategori_ad, renk, aciklama, created_date, updated_date, aktif_mi)
                       VALUES
                          (@ad, @renk, @aciklama, @createdDate, NULL, 1)";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@ad",   kategori.KategoriAd);
            komut.Parameters.AddWithValue("@renk", kategori.Renk);

            // ⭐ NULL DEĞER GÖNDERME — çok önemli!
            //    AddWithValue(..., null) yazarsan çalışmaz.
            //    C#'ın null'ı ile SQL'in NULL'ı farklı şeylerdir;
            //    aradaki köprü DBNull.Value'dur.
            komut.Parameters.AddWithValue("@aciklama",
                (object?)kategori.Aciklama ?? DBNull.Value);

            komut.Parameters.AddWithValue("@createdDate", DateTime.Now);

            baglanti.Open();
            komut.ExecuteNonQuery();
        }
    }

    // ════════════════════════════════════════════════════════
    //  4) UPDATE
    // ════════════════════════════════════════════════════════
    public void Guncelle(Kategori kategori)
    {
        // ⚠️ WHERE'i unutursan TÜM kategoriler aynı isme dönüşür
        string sql = @"UPDATE kategori
                       SET kategori_ad  = @ad,
                           renk         = @renk,
                           aciklama     = @aciklama,
                           updated_date = @updatedDate
                       WHERE kategori_id = @id";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@ad",   kategori.KategoriAd);
            komut.Parameters.AddWithValue("@renk", kategori.Renk);
            komut.Parameters.AddWithValue("@aciklama",
                (object?)kategori.Aciklama ?? DBNull.Value);
            komut.Parameters.AddWithValue("@updatedDate", DateTime.Now);
            komut.Parameters.AddWithValue("@id", kategori.KategoriId);

            baglanti.Open();
            komut.ExecuteNonQuery();
        }
    }

    // ════════════════════════════════════════════════════════
    //  5) DELETE — soft delete
    // ════════════════════════════════════════════════════════
    public void PasifYap(long id)
    {
        string sql = @"UPDATE kategori
                       SET aktif_mi = 0, updated_date = @updatedDate
                       WHERE kategori_id = @id";

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
    //  Bu kategoride kaç aktif görev var?
    //  (Silme kontrolü için — Modül 5'te kullanacağız)
    // ════════════════════════════════════════════════════════
    public int AktifGorevSayisi(long kategoriId)
    {
        string sql = @"SELECT COUNT(*) FROM gorev
                       WHERE kategori_id = @id AND aktif_mi = 1";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@id", kategoriId);
            baglanti.Open();
            return Convert.ToInt32(komut.ExecuteScalar());
        }
    }
}
```

### ⚠️ En kritik yeni bilgi: `DBNull.Value`

Bu, öğrencinin ilk kez karşılaşacağı ve mutlaka takılacağı konu. Tahtaya yaz:

```csharp
// ❌ ÇALIŞMAZ
komut.Parameters.AddWithValue("@aciklama", null);

// ✅ DOĞRU
komut.Parameters.AddWithValue("@aciklama", (object?)kategori.Aciklama ?? DBNull.Value);
```

**Neden?** C#'ın `null`'ı "değer yok" demek. SQL'in `NULL`'ı ise veritabanına ait özel bir değer. ADO.NET `null` gördüğünde "parametre verilmemiş" sanır ve hata verir. `DBNull.Value` ise "bu parametre SQL NULL olsun" demenin yoludur.

`??` işareti: *"soldaki null ise sağdakini kullan"*.

---

## ⌨️ Adım 3: Program.cs

```csharp
builder.Services.AddScoped<KategoriRepository>();
```

---

## ⌨️ Adım 4: Controller

`Controllers/KategoriController.cs`:

```csharp
using Microsoft.AspNetCore.Mvc;
using GorevTakip.Data;
using GorevTakip.Models;

namespace GorevTakip.Controllers;

// [Authorize] yazmaya gerek YOK — Program.cs'teki global filtre
// zaten tüm controller'ları koruyor.
public class KategoriController : Controller
{
    private readonly KategoriRepository _repo;

    public KategoriController(KategoriRepository repo)
    {
        _repo = repo;
    }

    // GET: /Kategori
    public IActionResult Index()
    {
        return View(_repo.TumunuGetir());
    }

    // GET: /Kategori/Create
    public IActionResult Create()
    {
        return View();
    }

    // POST: /Kategori/Create
    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult Create(Kategori kategori)
    {
        if (!ModelState.IsValid)
            return View(kategori);

        _repo.Ekle(kategori);
        TempData["Basarili"] = $"\"{kategori.KategoriAd}\" kategorisi eklendi.";

        // POST-Redirect-GET: F5'te çift kayıt olmasın
        return RedirectToAction("Index");
    }

    // GET: /Kategori/Edit/5
    public IActionResult Edit(long id)
    {
        var kategori = _repo.IdIleGetir(id);
        if (kategori == null) return NotFound();
        return View(kategori);
    }

    // POST: /Kategori/Edit/5
    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult Edit(Kategori kategori)
    {
        if (!ModelState.IsValid)
            return View(kategori);

        _repo.Guncelle(kategori);
        TempData["Basarili"] = "Kategori güncellendi.";
        return RedirectToAction("Index");
    }

    // GET: /Kategori/Delete/5
    public IActionResult Delete(long id)
    {
        var kategori = _repo.IdIleGetir(id);
        if (kategori == null) return NotFound();

        // Silinemeyecekse kullanıcıya ÖNCEDEN söyle
        ViewBag.GorevSayisi = _repo.AktifGorevSayisi(id);
        return View(kategori);
    }

    // POST: /Kategori/Delete/5
    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public IActionResult DeleteConfirmed(long id)
    {
        // ⭐ İlişkili kayıt kontrolü
        int gorevSayisi = _repo.AktifGorevSayisi(id);

        if (gorevSayisi > 0)
        {
            TempData["Uyari"] = $"Bu kategoride {gorevSayisi} görev var. " +
                                 "Önce görevleri silmeli veya başka kategoriye taşımalısınız.";
            return RedirectToAction("Index");
        }

        _repo.PasifYap(id);
        TempData["Basarili"] = "Kategori silindi.";
        return RedirectToAction("Index");
    }
}
```

> **Neden POST'ta bir daha kontrol ediyoruz?** GET'te de bakıyoruz ama arada kullanıcı yeni görev eklemiş olabilir. **Asıl karar her zaman veriyi değiştiren tarafta verilir.** Bu, güvenlik ve tutarlılık ilkesi — "tarayıcıya güvenme" kuralının başka bir yüzü.

---

## ⌨️ Adım 5: View'lar

### Index.cshtml

```html
@model List<GorevTakip.Models.Kategori>
@{
    ViewData["Title"] = "Kategoriler";
}

@if (TempData["Basarili"] != null)
{
    <div class="alert alert-success alert-dismissible fade show">
        <i class="bi bi-check-circle"></i> @TempData["Basarili"]
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
}

@if (TempData["Uyari"] != null)
{
    <div class="alert alert-warning alert-dismissible fade show">
        <i class="bi bi-exclamation-triangle"></i> @TempData["Uyari"]
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
}

<div class="card border-0 shadow-sm">
    <div class="card-header bg-white d-flex justify-content-between align-items-center">
        <span class="fw-semibold">Kategoriler (@Model.Count)</span>
        <a asp-action="Create" class="btn btn-success btn-sm">
            <i class="bi bi-plus-lg"></i> Yeni kategori
        </a>
    </div>

    <div class="card-body p-0">
        @if (Model.Count == 0)
        {
            <div class="text-center text-muted py-5">
                <i class="bi bi-tags fs-1 d-block mb-2"></i>
                <p class="mb-3">Henüz kategori yok.</p>
                <a asp-action="Create" class="btn btn-sm btn-success">İlk kategoriyi ekle</a>
            </div>
        }
        else
        {
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th>Kategori</th>
                        <th>Açıklama</th>
                        <th class="text-center">Görev</th>
                        <th class="text-end">İşlemler</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach (var k in Model)
                    {
                        <tr>
                            <td>
                                @* Renk alanı doğrudan Bootstrap sınıf adı olarak kullanılıyor *@
                                <span class="badge bg-@k.Renk">@k.KategoriAd</span>
                            </td>

                            <td class="small text-muted">
                                @* ⭐ NULL kontrolü — açıklama boş olabilir *@
                                @if (string.IsNullOrWhiteSpace(k.Aciklama))
                                {
                                    <span class="fst-italic">—</span>
                                }
                                else
                                {
                                    @k.Aciklama
                                }
                            </td>

                            <td class="text-center">
                                <span class="badge bg-light text-dark">@k.GorevSayisi</span>
                            </td>

                            <td class="text-end">
                                <a asp-action="Edit" asp-route-id="@k.KategoriId"
                                   class="btn btn-sm btn-outline-primary">
                                    <i class="bi bi-pencil"></i>
                                </a>
                                <a asp-action="Delete" asp-route-id="@k.KategoriId"
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

### Create.cshtml

```html
@model GorevTakip.Models.Kategori
@{
    ViewData["Title"] = "Yeni kategori";
}

<div class="row">
    <div class="col-md-7">
        <div class="card border-0 shadow-sm">
            <div class="card-body">
                <form asp-action="Create" method="post">

                    <div asp-validation-summary="ModelOnly" class="alert alert-danger"></div>

                    <div class="mb-3">
                        <label asp-for="KategoriAd" class="form-label"></label>
                        <input asp-for="KategoriAd" class="form-control" autofocus />
                        <span asp-validation-for="KategoriAd" class="text-danger small"></span>
                    </div>

                    <div class="mb-3">
                        <label asp-for="Renk" class="form-label"></label>
                        <select asp-for="Renk" class="form-select">
                            <option value="primary">Mavi</option>
                            <option value="success">Yeşil</option>
                            <option value="danger">Kırmızı</option>
                            <option value="warning">Sarı</option>
                            <option value="info">Turkuaz</option>
                            <option value="secondary">Gri</option>
                        </select>
                        <span asp-validation-for="Renk" class="text-danger small"></span>
                        <div class="form-text">Kategorinin listedeki rozet rengi.</div>
                    </div>

                    <div class="mb-3">
                        <label asp-for="Aciklama" class="form-label"></label>
                        <textarea asp-for="Aciklama" class="form-control" rows="3"></textarea>
                        <span asp-validation-for="Aciklama" class="text-danger small"></span>
                        @* ⭐ Zorunlu olmadığını kullanıcıya SÖYLE *@
                        <div class="form-text">İsteğe bağlı.</div>
                    </div>

                    <hr />
                    <button type="submit" class="btn btn-success">
                        <i class="bi bi-check-lg"></i> Kategoriyi kaydet
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

### Edit.cshtml

Create'in aynısı, **üç gizli alan** farkıyla:

```html
<form asp-action="Edit" method="post">

    @* Hangi kaydı güncelliyoruz? WHERE için şart. *@
    <input type="hidden" asp-for="KategoriId" />
    <input type="hidden" asp-for="CreatedDate" />
    <input type="hidden" asp-for="AktifMi" />

    @* ... Create ile aynı alanlar ... *@
</form>
```

> **Deney:** `KategoriId` gizli alanını sil ve düzenlemeyi kaydet. Hiçbir şey değişmez — SQL `WHERE kategori_id = 0` olarak çalışır, hiçbir satır eşleşmez, **hata da vermez.** Sessizce başarısız olan hatalar en tehlikelileridir; öğrenci bunu bir kez yaşamalı.

### Delete.cshtml

```html
@model GorevTakip.Models.Kategori
@{
    ViewData["Title"] = "Kategoriyi sil";
    int gorevSayisi = ViewBag.GorevSayisi ?? 0;
}

<div class="row">
    <div class="col-md-6">
        <div class="card border-danger shadow-sm">
            <div class="card-header bg-danger text-white">
                <i class="bi bi-exclamation-triangle"></i> Silme onayı
            </div>
            <div class="card-body">

                <p>
                    <span class="badge bg-@Model.Renk">@Model.KategoriAd</span>
                    kategorisini silmek üzeresiniz.
                </p>

                @if (gorevSayisi > 0)
                {
                    @* Silinemiyorsa butonu HİÇ GÖSTERME.
                       Basıp hata almak, butonun olmadığını görmekten kötüdür. *@
                    <div class="alert alert-warning">
                        <i class="bi bi-x-circle"></i>
                        Bu kategoride <strong>@gorevSayisi görev</strong> var.
                        Silmeden önce görevleri silmeli veya başka kategoriye taşımalısınız.
                    </div>

                    <a asp-controller="Gorev" asp-action="Index"
                       asp-route-kategoriId="@Model.KategoriId"
                       class="btn btn-primary">
                        Bu kategorinin görevlerini gör
                    </a>
                    <a asp-action="Index" class="btn btn-outline-secondary">Vazgeç</a>
                }
                else
                {
                    <div class="alert alert-info small">
                        Kayıt tamamen silinmez, pasif duruma alınır.
                    </div>

                    <form asp-action="Delete" method="post">
                        <input type="hidden" asp-for="KategoriId" name="id" />
                        <button type="submit" class="btn btn-danger">
                            <i class="bi bi-trash"></i> Evet, sil
                        </button>
                        <a asp-action="Index" class="btn btn-outline-secondary">Vazgeç</a>
                    </form>
                }

            </div>
        </div>
    </div>
</div>
```

> `name="id"` ŞART. `asp-for` tek başına `KategoriId` adında alan üretir, controller'daki `DeleteConfirmed(long id)` ile eşleşmez.

---

## ▶️ Test senaryosu

| Test | Beklenen |
|---|---|
| Kategori listesi | Renkli rozetler, görev sayıları |
| Açıklamasız kategori | Tabloda `—` görünür, **çökme yok** |
| Boş form gönder | "Kategori adı zorunludur" |
| Açıklamayı boş bırak, kaydet | Kaydolur (zorunlu değil) |
| SSMS'te kontrol | `aciklama` sütunu `NULL` |
| Görevi olan kategoriyi sil | Uyarı, sil butonu yok |
| Boş kategoriyi sil | Silinir |
| SSMS'te kontrol | Kayıt duruyor, `aktif_mi = 0` |

---

## ⚠️ Sık yapılan hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| `Parameterized query ... expects parameter '@aciklama'` | `AddWithValue(..., null)` yazılmış | `?? DBNull.Value` ekle |
| `Data is Null. This method cannot be called on Null values` | `IsDBNull` kontrolü yok | Kontrolü ekle |
| `Unable to cast object of type 'System.Boolean' to 'System.String'` | `GetString` ile BIT okunuyor | `GetBoolean` kullan |
| `Conversion failed ... nvarchar '1' to bit` | SQL'de `aktif_mi = '1'` yazılmış | Tırnağı kaldır: `= 1` |
| Düzenleme kaydediyor ama değişmiyor | Gizli `KategoriId` yok | Ekle |
| Rozet renksiz görünüyor | `renk` değeri geçersiz | `primary`, `success` gibi Bootstrap adları olmalı |

---

## ✏️ Öğrenci alıştırması

**A.** Kategori CRUD'unu tamamla, tüm testleri geçir.

**B.** Renk seçimini görsel yap: açılır liste yerine renkli kutucuklar (radio button) göster.

**C.** Pasif kategoriler sayfası yaz. Her satırda "Geri getir" butonu olsun.
İpucu: `PasifYap`'ın tersi bir `AktifYap(long id)` metodu.

**D. Düşünme soruları:**
1. `DBNull.Value` yerine boş metin `""` kaydetseydik ne fark ederdi? Hangisi daha doğru?
2. Kategoriyi silmek yerine görevleri "Genel" kategorisine taşımak daha mı iyi olurdu?
3. Bu projede `aktif_mi` `BIT`. Okul projesindeki `NVARCHAR` sürümüne göre kodda kaç yer değişti?

---

👉 Sonraki: [`05-gorev-crud.md`](05-gorev-crud.md)
