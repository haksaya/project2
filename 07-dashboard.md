# Modül 6 — Dashboard

**Süre:** 1 ders saati
**Kim yazıyor:** ⭐ Öğrenci (yeni kavram az, kalıp tanıdık)

---

## 🎯 Bu derste ne yapacağız

Ana panele gerçek istatistikler koyacağız: kaç görev var, kaçı gecikmiş, tamamlanma oranı ne, kategori dağılımı nasıl.

**Yeni kavram:** Tek sorguda birden çok sayım (`SUM(CASE WHEN ...)`).

---

## 📖 Kavram 1: ViewModel

Öğrenci bunu okul projesinden biliyor. Kısaca hatırlat:

| | Neyi temsil eder | Örnek |
|---|---|---|
| **Model** | Bir veritabanı **tablosunu** | `Gorev`, `Kategori` |
| **ViewModel** | Bir **ekranın ihtiyacını** | `DashboardViewModel` |

Dashboard'da 6 sayı + 2 liste göstereceğiz. Hepsini `ViewBag` ile taşımak mümkün ama yazım hatası derleme zamanında yakalanmaz. ViewModel yazınca Visual Studio yardım eder.

---

## 📖 Kavram 2: Tek sorguda birden çok sayım

**Sor:** *"Toplam görev, tamamlanan, bekleyen ve gecikmiş sayısını almak için kaç sorgu gerekir?"*

İlk cevap genelde "dört" olur. Ama tek sorguda yapılabilir:

```sql
SELECT
    COUNT(*)                                              AS toplam,
    SUM(CASE WHEN durum = 'Tamamlandi' THEN 1 ELSE 0 END) AS tamamlanan,
    SUM(CASE WHEN durum = 'Beklemede'  THEN 1 ELSE 0 END) AS bekleyen
FROM gorev
WHERE aktif_mi = 1;
```

**Nasıl çalışıyor?** `CASE WHEN` her satır için 1 veya 0 üretir, `SUM` onları toplar. Yani "koşula uyanları say" demenin başka bir yolu.

```
satır  durum          CASE sonucu
  1    Tamamlandi          1
  2    Beklemede           0
  3    Tamamlandi          1
  4    Devam ediyor        0
                    SUM = 2  ← tamamlanan sayısı
```

> **Neden önemli?** Dört ayrı sorgu = veritabanına dört gidiş dönüş. Tek sorgu = bir gidiş dönüş. Küçük veride fark edilmez, büyük veride belirleyici olur.

---

## ⌨️ Adım 1: ViewModel

`Models/DashboardViewModel.cs`:

```csharp
namespace GorevTakip.Models;

public class DashboardViewModel
{
    // ── Üst kartlar ──────────────────────────────────────────
    public int ToplamGorev { get; set; }
    public int TamamlananGorev { get; set; }
    public int BekleyenGorev { get; set; }
    public int DevamEdenGorev { get; set; }
    public int GecikmisGorev { get; set; }
    public int BugunBitenGorev { get; set; }      // bugün son tarihi olanlar

    // ── Listeler ─────────────────────────────────────────────
    // = new()  →  boş başlasın, null olmasın (view'da çökmesin)
    public List<KategoriDagilim> KategoriDagilimlari { get; set; } = new();
    public List<Gorev> YaklasanGorevler { get; set; } = new();

    // ── Hesaplanan ───────────────────────────────────────────
    /// <summary>
    /// Tamamlanma yüzdesi.
    /// ⚠️ Sıfıra bölme koruması ŞART — hiç görev yoksa çökerdi.
    /// </summary>
    public int TamamlanmaYuzdesi =>
        ToplamGorev > 0
            ? (TamamlananGorev * 100) / ToplamGorev
            : 0;
}

/// <summary>
/// Kategori başına görev dağılımı.
/// Sadece dashboard'da kullanılır, bir tabloya karşılık gelmez.
/// </summary>
public class KategoriDagilim
{
    public string KategoriAd { get; set; } = "";
    public string Renk { get; set; } = "secondary";
    public int ToplamGorev { get; set; }
    public int TamamlananGorev { get; set; }

    public int Yuzde =>
        ToplamGorev > 0
            ? (TamamlananGorev * 100) / ToplamGorev
            : 0;
}
```

---

## ⌨️ Adım 2: Repository

`Data/DashboardRepository.cs`:

```csharp
using Microsoft.Data.SqlClient;
using GorevTakip.Models;

namespace GorevTakip.Data;

public class DashboardRepository
{
    private readonly string _baglantiMetni;

    public DashboardRepository(IConfiguration configuration)
    {
        _baglantiMetni = configuration.GetConnectionString("GorevDb")!;
    }

    /// <summary>
    /// Altı sayıyı TEK sorguda getirir.
    /// out parametreleriyle birden çok değer dışarı verilir.
    /// </summary>
    public void SayilariGetir(out int toplam, out int tamamlanan, out int bekleyen,
                              out int devamEden, out int gecikmis, out int bugunBiten)
    {
        string sql = @"
            SELECT
                COUNT(*) AS toplam,

                SUM(CASE WHEN durum = 'Tamamlandi'   THEN 1 ELSE 0 END) AS tamamlanan,
                SUM(CASE WHEN durum = 'Beklemede'    THEN 1 ELSE 0 END) AS bekleyen,
                SUM(CASE WHEN durum = 'Devam ediyor' THEN 1 ELSE 0 END) AS devam_eden,

                -- Gecikmiş: tarihi var + geçmiş + tamamlanmamış
                SUM(CASE WHEN bitis_tarihi IS NOT NULL
                          AND bitis_tarihi < CAST(GETDATE() AS DATE)
                          AND durum <> 'Tamamlandi'
                         THEN 1 ELSE 0 END) AS gecikmis,

                -- Bugün bitmesi gerekenler
                SUM(CASE WHEN bitis_tarihi = CAST(GETDATE() AS DATE)
                          AND durum <> 'Tamamlandi'
                         THEN 1 ELSE 0 END) AS bugun_biten

            FROM gorev
            WHERE aktif_mi = 1";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                if (okuyucu.Read())
                {
                    toplam = okuyucu.GetInt32(okuyucu.GetOrdinal("toplam"));

                    // ⚠️ SUM boş tabloda NULL döner, 0 değil!
                    //    Hiç görev yoksa uygulama çökerdi.
                    tamamlanan = OkuVeyaSifir(okuyucu, "tamamlanan");
                    bekleyen   = OkuVeyaSifir(okuyucu, "bekleyen");
                    devamEden  = OkuVeyaSifir(okuyucu, "devam_eden");
                    gecikmis   = OkuVeyaSifir(okuyucu, "gecikmis");
                    bugunBiten = OkuVeyaSifir(okuyucu, "bugun_biten");
                }
                else
                {
                    toplam = tamamlanan = bekleyen = devamEden = gecikmis = bugunBiten = 0;
                }
            }
        }
    }

    /// <summary>
    /// Sütun NULL ise 0 döner. SUM'ın boş tabloda NULL dönmesine karşı koruma.
    /// </summary>
    private int OkuVeyaSifir(SqlDataReader okuyucu, string sutunAdi)
    {
        int sutunNo = okuyucu.GetOrdinal(sutunAdi);
        return okuyucu.IsDBNull(sutunNo) ? 0 : okuyucu.GetInt32(sutunNo);
    }

    /// <summary>
    /// Kategorilere göre görev dağılımı.
    /// </summary>
    public List<KategoriDagilim> KategoriDagilimi()
    {
        var liste = new List<KategoriDagilim>();

        string sql = @"
            SELECT k.kategori_ad,
                   k.renk,
                   COUNT(g.gorev_id) AS toplam,
                   SUM(CASE WHEN g.durum = 'Tamamlandi' THEN 1 ELSE 0 END) AS tamamlanan
            FROM kategori k
            LEFT JOIN gorev g ON g.kategori_id = k.kategori_id AND g.aktif_mi = 1
            WHERE k.aktif_mi = 1
            GROUP BY k.kategori_ad, k.renk
            ORDER BY toplam DESC";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                while (okuyucu.Read())
                {
                    liste.Add(new KategoriDagilim
                    {
                        KategoriAd      = okuyucu.GetString(okuyucu.GetOrdinal("kategori_ad")),
                        Renk            = okuyucu.GetString(okuyucu.GetOrdinal("renk")),
                        ToplamGorev     = okuyucu.GetInt32(okuyucu.GetOrdinal("toplam")),
                        TamamlananGorev = OkuVeyaSifir(okuyucu, "tamamlanan")
                    });
                }
            }
        }

        return liste;
    }

    /// <summary>
    /// Yaklaşan görevler: bitiş tarihi olan, tamamlanmamış, en yakın N tanesi.
    /// </summary>
    public List<Gorev> YaklasanGorevler(int adet = 5)
    {
        var liste = new List<Gorev>();

        // ⭐ TOP (@adet) — parametre kullanınca PARANTEZ şart
        string sql = @"SELECT TOP (@adet)
                              g.gorev_id, g.baslik, g.oncelik, g.durum,
                              g.bitis_tarihi, k.kategori_ad, k.renk
                       FROM gorev g
                       INNER JOIN kategori k ON g.kategori_id = k.kategori_id
                       WHERE g.aktif_mi = 1
                         AND g.durum <> 'Tamamlandi'
                         AND g.bitis_tarihi IS NOT NULL
                       ORDER BY g.bitis_tarihi";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@adet", adet);
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                while (okuyucu.Read())
                {
                    // NOT: Gorev nesnesinin TÜM alanlarını doldurmuyoruz —
                    // bu ekranda sadece birkaçını göstereceğiz.
                    // SELECT'te olmayan sütunu okumaya kalkarsan hata alırsın.
                    var g = new Gorev
                    {
                        GorevId      = okuyucu.GetInt64(okuyucu.GetOrdinal("gorev_id")),
                        Baslik       = okuyucu.GetString(okuyucu.GetOrdinal("baslik")),
                        Oncelik      = okuyucu.GetInt32(okuyucu.GetOrdinal("oncelik")),
                        Durum        = okuyucu.GetString(okuyucu.GetOrdinal("durum")),
                        BitisTarihi  = okuyucu.GetDateTime(okuyucu.GetOrdinal("bitis_tarihi")),
                        KategoriAd   = okuyucu.GetString(okuyucu.GetOrdinal("kategori_ad")),
                        KategoriRenk = okuyucu.GetString(okuyucu.GetOrdinal("renk"))
                    };

                    liste.Add(g);
                }
            }
        }

        return liste;
    }
}
```

`Program.cs`: `builder.Services.AddScoped<DashboardRepository>();`

### ⚠️ `SUM` boş tabloda NULL döner

Bu, öğrencinin takılacağı nokta. **Deney yaptır:**

```sql
SELECT SUM(CASE WHEN durum = 'Tamamlandi' THEN 1 ELSE 0 END)
FROM gorev WHERE 1 = 0;    -- hiçbir satır getirmeyen sorgu
```

Sonuç: `NULL`. **`0` değil!**

`COUNT` boş tabloda 0 döner ama `SUM` NULL döner. Bu yüzden `OkuVeyaSifir` yardımcısını yazdık.

> Alternatif çözüm SQL tarafında: `ISNULL(SUM(...), 0)`. İkisini de göster, farkı tartıştır.

---

## ⌨️ Adım 3: Controller

```csharp
public class HomeController : Controller
{
    private readonly DashboardRepository _repo;

    public HomeController(DashboardRepository repo)
    {
        _repo = repo;
    }

    public IActionResult Index()
    {
        // out parametreleri karşıla
        _repo.SayilariGetir(out int toplam, out int tamamlanan, out int bekleyen,
                            out int devamEden, out int gecikmis, out int bugunBiten);

        var model = new DashboardViewModel
        {
            ToplamGorev     = toplam,
            TamamlananGorev = tamamlanan,
            BekleyenGorev   = bekleyen,
            DevamEdenGorev  = devamEden,
            GecikmisGorev   = gecikmis,
            BugunBitenGorev = bugunBiten,

            KategoriDagilimlari = _repo.KategoriDagilimi(),
            YaklasanGorevler    = _repo.YaklasanGorevler(5)
        };

        return View(model);
    }
}
```

> **`out int toplam` — metot çağırırken tanımlama.** C#'ta `out` parametreler böyle karşılanır. Metot tek değer döner, `out` ile ek değerler dışarı verilir.

---

## ⌨️ Adım 4: Dashboard view'ı

`Views/Home/Index.cshtml`:

```html
@model GorevTakip.Models.DashboardViewModel
@{
    ViewData["Title"] = "Panel";
}

@* ═══════════ ÜST KARTLAR ═══════════ *@
<div class="row g-3 mb-4">

    <div class="col-md-3">
        <a asp-controller="Gorev" asp-action="Index" class="text-decoration-none">
            <div class="card border-0 shadow-sm h-100">
                <div class="card-body d-flex justify-content-between align-items-center">
                    <div>
                        <div class="text-muted small">Toplam görev</div>
                        <div class="fs-3 fw-bold text-dark">@Model.ToplamGorev</div>
                    </div>
                    <i class="bi bi-list-task fs-1 text-primary opacity-25"></i>
                </div>
            </div>
        </a>
    </div>

    <div class="col-md-3">
        @* Filtreli listeye link — tıklayınca sadece bekleyenler *@
        <a asp-controller="Gorev" asp-action="Index" asp-route-durum="Beklemede"
           class="text-decoration-none">
            <div class="card border-0 shadow-sm h-100">
                <div class="card-body d-flex justify-content-between align-items-center">
                    <div>
                        <div class="text-muted small">Bekleyen</div>
                        <div class="fs-3 fw-bold text-dark">@Model.BekleyenGorev</div>
                    </div>
                    <i class="bi bi-hourglass-split fs-1 text-secondary opacity-25"></i>
                </div>
            </div>
        </a>
    </div>

    <div class="col-md-3">
        <a asp-controller="Gorev" asp-action="Index" asp-route-durum="Tamamlandi"
           class="text-decoration-none">
            <div class="card border-0 shadow-sm h-100">
                <div class="card-body d-flex justify-content-between align-items-center">
                    <div>
                        <div class="text-muted small">Tamamlanan</div>
                        <div class="fs-3 fw-bold text-dark">@Model.TamamlananGorev</div>
                    </div>
                    <i class="bi bi-check2-circle fs-1 text-success opacity-25"></i>
                </div>
            </div>
        </a>
    </div>

    <div class="col-md-3">
        <a asp-controller="Gorev" asp-action="Index" asp-route-sadeceGecikmis="true"
           class="text-decoration-none">
            @* Gecikmiş varsa kartı kırmızı çerçevele — dikkat çeksin *@
            <div class="card border-0 shadow-sm h-100 @(Model.GecikmisGorev > 0 ? "border-danger border-2" : "")">
                <div class="card-body d-flex justify-content-between align-items-center">
                    <div>
                        <div class="text-muted small">Gecikmiş</div>
                        <div class="fs-3 fw-bold @(Model.GecikmisGorev > 0 ? "text-danger" : "text-dark")">
                            @Model.GecikmisGorev
                        </div>
                    </div>
                    <i class="bi bi-exclamation-triangle fs-1 text-danger opacity-25"></i>
                </div>
            </div>
        </a>
    </div>

</div>


@* ═══════════ BUGÜN UYARISI ═══════════ *@
@if (Model.BugunBitenGorev > 0)
{
    <div class="alert alert-warning">
        <i class="bi bi-calendar-event"></i>
        Bugün son tarihi olan <strong>@Model.BugunBitenGorev görev</strong> var.
    </div>
}


<div class="row g-3">

    @* ═══════════ TAMAMLANMA ORANI ═══════════ *@
    <div class="col-lg-4">
        <div class="card border-0 shadow-sm h-100">
            <div class="card-header bg-white fw-semibold">Genel ilerleme</div>
            <div class="card-body text-center">

                <div class="display-4 fw-bold text-success mb-2">
                    %@Model.TamamlanmaYuzdesi
                </div>

                <div class="progress mb-3" style="height: 10px;">
                    <div class="progress-bar bg-success"
                         style="width: @Model.TamamlanmaYuzdesi%;"></div>
                </div>

                <p class="text-muted small mb-0">
                    @Model.ToplamGorev görevden @Model.TamamlananGorev tanesi tamamlandı
                </p>

            </div>
        </div>
    </div>

    @* ═══════════ KATEGORİ DAĞILIMI ═══════════ *@
    <div class="col-lg-4">
        <div class="card border-0 shadow-sm h-100">
            <div class="card-header bg-white fw-semibold">Kategorilere göre</div>
            <div class="card-body">

                @if (Model.KategoriDagilimlari.Count == 0)
                {
                    <p class="text-muted small mb-0">Henüz kategori yok.</p>
                }
                else
                {
                    @foreach (var k in Model.KategoriDagilimlari)
                    {
                        <div class="mb-3">
                            <div class="d-flex justify-content-between small mb-1">
                                <span class="badge bg-@k.Renk">@k.KategoriAd</span>
                                <span class="text-muted">
                                    @k.TamamlananGorev / @k.ToplamGorev
                                </span>
                            </div>
                            <div class="progress" style="height: 6px;">
                                <div class="progress-bar bg-@k.Renk"
                                     style="width: @k.Yuzde%;"></div>
                            </div>
                        </div>
                    }
                }

            </div>
        </div>
    </div>

    @* ═══════════ YAKLAŞAN GÖREVLER ═══════════ *@
    <div class="col-lg-4">
        <div class="card border-0 shadow-sm h-100">
            <div class="card-header bg-white fw-semibold">Yaklaşan görevler</div>
            <div class="card-body p-0">

                @if (Model.YaklasanGorevler.Count == 0)
                {
                    <p class="text-muted small p-3 mb-0">
                        Bitiş tarihi olan bekleyen görev yok.
                    </p>
                }
                else
                {
                    <ul class="list-group list-group-flush">
                        @foreach (var g in Model.YaklasanGorevler)
                        {
                            <li class="list-group-item d-flex justify-content-between align-items-center">
                                <div>
                                    <a asp-controller="Gorev" asp-action="Details"
                                       asp-route-id="@g.GorevId"
                                       class="text-decoration-none small fw-semibold">
                                        @g.Baslik
                                    </a>
                                    <div>
                                        <span class="badge bg-@g.KategoriRenk"
                                              style="font-size: .65rem;">@g.KategoriAd</span>
                                    </div>
                                </div>

                                <span class="small @(g.GecikmisMi ? "text-danger fw-semibold" : "text-muted")">
                                    @g.BitisTarihi!.Value.ToString("dd.MM")
                                </span>
                            </li>
                        }
                    </ul>
                }

            </div>
        </div>
    </div>

</div>
```

> **`@g.BitisTarihi!.Value`** — buradaki `!` işareti C#'a "biliyorum, bu null değil" demek. Sorgumuz zaten `bitis_tarihi IS NOT NULL` filtresi kullanıyor, o yüzden güvenli. Bu işareti kullanırken **gerçekten emin olmalısın**; yanılırsan uygulama çöker.

---

## ▶️ Test senaryosu

| Test | Beklenen |
|---|---|
| Dashboard aç | Gerçek sayılar |
| SSMS'ten doğrula | `SELECT COUNT(*) FROM gorev WHERE aktif_mi=1` |
| Yeni görev ekle | Sayı arttı |
| Görev tamamla | Tamamlanan arttı, oran değişti |
| "Gecikmiş" kartına tıkla | Filtreli görev listesi |
| Tüm görevleri sil | **Çökmüyor**, sıfırlar görünüyor |
| Bugün tarihli görev ekle | Sarı uyarı çıktı |

---

## ⚠️ Sık yapılan hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| `Data is Null` (boş veritabanında) | `SUM` NULL döndü | `IsDBNull` kontrolü / `ISNULL(...)` |
| `Attempted to divide by zero` | Görev yokken yüzde hesabı | `ToplamGorev > 0` kontrolü |
| `Object reference not set` | ViewModel listesi null | `= new()` ile başlat |
| Sayılar hep 0 | `aktif_mi = '1'` yazılmış | Tırnağı kaldır |
| `Invalid column name 'devam_eden'` | `AS` takma adı yok | SQL'de `AS devam_eden` |
| Kart linkleri filtrelemiyor | `asp-route-*` adı yanlış | Controller parametre adıyla aynı olmalı |
| `Nullable object must have a value` | `.Value` null üzerinde | Sorgudaki `IS NOT NULL` filtresini kontrol et |

---

## ✏️ Öğrenci alıştırması

**A.** Dashboard'ı tamamla, boş veritabanıyla da test et.

**B.** "Bu hafta tamamlananlar" kartı ekle.
İpucu: `tamamlanma_tarihi >= DATEADD(day, -7, GETDATE())`

**C.** Öncelik dağılımı kartı: Yüksek/Orta/Düşük kaç görev var, renkli çubuklarla.

**D.** Chart.js ile kategori dağılımını halka grafiği yap.
⚠️ `@Html.Raw` kullanacaksın — kullanıcı verisiyle **asla** kullanma (XSS açığı). Burada güvenli, çünkü veriyi biz üretiyoruz.

**E. Düşünme soruları:**
1. Dashboard 3 sorgu çalıştırıyor. Tek sorguya indirebilir miydik? Değer miydi?
2. `SUM(CASE WHEN...)` yerine 4 ayrı `COUNT` sorgusu yazsaydık ne değişirdi?
3. 100.000 görev olsa bu dashboard ne kadar sürerdi? Neyi hızlandırırdın?

---

👉 Sonraki (opsiyonel): [`08-opsiyonel-etiketler.md`](08-opsiyonel-etiketler.md)
