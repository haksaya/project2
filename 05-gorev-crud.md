# Modül 4 — Görev CRUD

**Süre:** 2 ders saati
**Kim yazıyor:** ⭐ **Öğrenci yazar, sen yönlendirirsin**

---

## 🎯 Bu derste ne yapacağız

Ana tablo. Kalıp tanıdık — **üç yeni ayrıntı** var:

1. Formda **boş bırakılabilen tarih** (`DateTime?`)
2. Veritabanında olmayan, **kodda hesaplanan** bilgi ("gecikmiş mi?")
3. SQL'de **koşullu sıralama** (`CASE WHEN`)

> **Ders formatı:** Sen kod yazmıyorsun. Tahtaya sadece yapılacaklar listesini yaz, dolaş, takılanlara **cevap verme, soru sor.** Yeni olan üç konuyu beraber çözün.

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

**Kural:** *"10 dakika kendiniz uğraşmadan bana gelmeyin. Önce hata mesajını okuyun, sonra Kategori modülüne bakın."*

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

⭐ **Bu adımı öğrenci yazsın.** Sen sadece iki noktayı hatırlat.

**Uyarı 1 — NULL tarih yazma:**
```csharp
komut.Parameters.AddWithValue("@bitisTarihi",
    (object?)gorev.BitisTarihi ?? DBNull.Value);
```
Kategori modülündeki `DBNull.Value` kuralı, burada tarihte de geçerli.

**Uyarı 2 — Sıralama:** JOIN'li listeleme sorgusunu tahtaya yaz, gerisini onlar yazsın:

```sql
SELECT g.gorev_id, g.kategori_id, g.baslik, g.aciklama,
       g.oncelik, g.durum, g.bitis_tarihi, g.tamamlanma_tarihi,
       g.created_date, g.updated_date, g.aktif_mi,
       k.kategori_ad, k.renk
FROM gorev g
INNER JOIN kategori k ON g.kategori_id = k.kategori_id
WHERE g.aktif_mi = 1
ORDER BY
    -- ⭐ KOŞULLU SIRALAMA
    -- Tamamlanmış görevler en alta insin
    CASE WHEN g.durum = 'Tamamlandi' THEN 1 ELSE 0 END,

    -- Yüksek öncelik üstte (3 → 1)
    g.oncelik DESC,

    -- Yakın tarih üstte; tarihi olmayanlar en sonda
    CASE WHEN g.bitis_tarihi IS NULL THEN 1 ELSE 0 END,
    g.bitis_tarihi
```

### 📖 `CASE WHEN` ile sıralama

**Sor:** *"Sadece `ORDER BY bitis_tarihi` yazsaydık, tarihi olmayan görevler nereye giderdi?"*

SQL Server'da `NULL` değerler sıralamada **en başa** gelir. Yani "tarihi olmayan" görevler listenin tepesinde olurdu — istediğimiz bu değil.

```sql
CASE WHEN g.bitis_tarihi IS NULL THEN 1 ELSE 0 END
```

Bu satır geçici bir sütun üretir: tarihi olan satırlara `0`, olmayanlara `1`. Önce ona göre sıralayınca tarihi olanlar üstte kalır.

> Aynı numara ilk satırda da kullanılıyor: tamamlanmış görevlere `1` verip alta itiyoruz.

### Repository'nin geri kalanı — kontrol listesi

Öğrenci şunları yazmalı:

| Metot | Not |
|---|---|
| `SatiriNesneyeCevir` | `aciklama`, `bitis_tarihi`, `tamamlanma_tarihi`, `updated_date` → dördü de NULL kontrolü ister |
| `TumunuGetir()` | Yukarıdaki JOIN'li sorgu |
| `IdIleGetir(id)` | JOIN'li, `if (okuyucu.Read())` |
| `Ekle(gorev)` | `tamamlanma_tarihi` başlangıçta NULL |
| `Guncelle(gorev)` | `WHERE`'i unutma! |
| `PasifYap(id)` | `aktif_mi = 0` |

`Program.cs`: `builder.Services.AddScoped<GorevRepository>();`

---

## ⌨️ Adım 3: Controller

⭐ Öğrenci yazsın. Kategori controller'ının aynısı + açılır liste.

```csharp
using Microsoft.AspNetCore.Mvc.Rendering;   // SelectList için

private void KategoriListesiniHazirla(long? secili = null)
{
    var kategoriler = _kategoriRepo.TumunuGetir();
    ViewBag.Kategoriler = new SelectList(kategoriler, "KategoriId", "KategoriAd", secili);
}
```

> ⚠️ **En çok unutulan satır** — bunu tahtaya yaz:
> ```csharp
> if (!ModelState.IsValid)
> {
>     KategoriListesiniHazirla(gorev.KategoriId);   // ← BU
>     return View(gorev);
> }
> ```
> `ViewBag` sadece o istek boyunca yaşar. POST yeni bir istektir. Doldurmazsan hatalı gönderimden sonra açılır liste **boş gelir** ve sayfa çöker.
>
> Bu satırı bilerek sildir, formu hatalı gönderttir, çöktüğünü göster, geri ekletir.

`GorevController` iki repository alacak: `GorevRepository` ve `KategoriRepository`.

---

## ⌨️ Adım 4: Form — beraber yazın

`Views/Gorev/Create.cshtml`. Yeni olan kısımlar:

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
                        <div class="form-text">İsteğe bağlı.</div>
                    </div>

                    <div class="row">

                        <div class="col-md-4 mb-3">
                            <label asp-for="KategoriId" class="form-label"></label>
                            <select asp-for="KategoriId" asp-items="ViewBag.Kategoriler"
                                    class="form-select">
                                <option value="">-- Kategori seçin --</option>
                            </select>
                            <span asp-validation-for="KategoriId" class="text-danger small"></span>
                        </div>

                        <div class="col-md-4 mb-3">
                            <label asp-for="Oncelik" class="form-label"></label>
                            @* Sayı gönderiyoruz ama kullanıcı metin görüyor *@
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

## ⌨️ Adım 5: Liste

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
                                        <span class="text-warning">
                                            (@g.KalanGun gün kaldı)
                                        </span>
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

## ▶️ Test senaryosu

| # | Test | Beklenen |
|---|---|---|
| 1 | Boş form gönder | Başlık ve kategori hatası |
| 2 | Tarihi boş bırak, kaydet | **Kaydolur** |
| 3 | SSMS'te bak | `bitis_tarihi` NULL |
| 4 | Listede o görev | Bitiş sütununda `—` |
| 5 | Dünkü tarihle görev ekle | Satır kırmızı, "1 gün gecikti" |
| 6 | O görevi "Tamamlandı" yap | Kırmızı gitti, başlık üstü çizili |
| 7 | 2 gün sonrası tarihli görev | "2 gün kaldı" sarı uyarı |
| 8 | Öncelik "Yüksek" | Kırmızı rozet, listede üstte |
| 9 | Hatalı gönderimden sonra | Açılır liste **dolu** |
| 10 | Sıralama | Tamamlananlar altta, yüksek öncelik üstte |

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

---

## ✏️ Öğrenci alıştırması

**A.** Görev CRUD'unu tamamla, 10 test senaryosunu geçir.

**B.** `Details` sayfası yaz. Görevin tüm bilgileri + "kaç gün kaldı" + kategori rozeti.

**C.** Bugün bitmesi gereken görevleri **turuncu** göster ("Bugün!" etiketi).
İpucu: model'e yeni bir hesaplanan özellik ekle:
```csharp
public bool BugunMu => BitisTarihi.HasValue
                    && BitisTarihi.Value.Date == DateTime.Today
                    && !TamamlandiMi;
```

**D.** Görev eklerken bitiş tarihi **geçmişte** olamasın. Özel doğrulama yaz.
İpucu: `IValidatableObject` arayüzü veya özel bir `ValidationAttribute`.

**E. Düşünme soruları:**
1. `GecikmisMi` bilgisini veritabanında sütun olarak saklasaydık ne sorun çıkardı?
2. `ORDER BY`'daki `CASE WHEN` satırlarını silsek liste nasıl görünürdü? Dene.
3. Öncelik `INT`, durum `NVARCHAR`. Bu tutarsızlık mı, yoksa gerekçesi var mı?

---

👉 Sonraki: [`06-gorev-durum-ve-filtre.md`](06-gorev-durum-ve-filtre.md)
