# Modül 7 — Etiketler: Çoktan Çoğa İlişki *(Opsiyonel)*

**Süre:** 1-2 ders saati
**Durum:** Opsiyonel — zaman kalırsa veya ileri seviye grup için
**Kim yazıyor:** Beraber

---

## 🎯 Bu derste ne yapacağız

Görevlere **etiket** ekleyeceğiz: bir görevin birden çok etiketi, bir etiketin birden çok görevi olabilir.

> ⭐ **Bu modül, iki projede de öğrenilmemiş tek yeni ilişki türünü öğretiyor.** Okul projesinde ve bu projenin ilk altı modülünde hep **bir-çok** (1:N) ilişki vardı. Burada **çoktan çoğa** (N:N) var ve bu, tamamen farklı bir çözüm gerektiriyor.

---

## 📖 Kavram: İlişki türleri

Tahtaya üç şemayı yan yana çiz:

### 1:1 — Bire bir
```
kullanici ──── profil
Her kullanıcının bir profili, her profilin bir kullanıcısı.
```

### 1:N — Bire çok *(şu ana kadar hep bunu yaptık)*
```
kategori ────< gorev
Bir kategorinin çok görevi, bir görevin tek kategorisi.

ÇÖZÜM: Çocuk tabloya yabancı anahtar koy.
       gorev.kategori_id
```

### N:N — Çoktan çoğa *(yeni!)*
```
gorev >────< etiket
Bir görevin çok etiketi, bir etiketin çok görevi.

ÇÖZÜM: ???
```

**Sınıfa sor:** *"Bir görevin 3 etiketi olacak. Bunu `gorev` tablosunda nasıl saklarız?"*

Gelen yanlış cevapları tahtaya yaz ve neden olmadığını tartış:

| Öneri | Neden olmaz |
|---|---|
| `etiket1_id`, `etiket2_id`, `etiket3_id` sütunları | 4. etiket gerekince tabloyu değiştirmen gerekir. Ayrıca "etiketi olan görevleri bul" sorgusu kâbusa döner. |
| `etiketler NVARCHAR(500)` → `"acil,is,rapor"` | Metin içinde arama yavaş, yazım hatası engellenemez, etiketin adını değiştirince tüm satırları düzeltmen gerekir. |

**Doğru cevap: üçüncü bir tablo.**

```
gorev                gorev_etiket              etiket
┌──────────┐         ┌────────────────┐        ┌───────────┐
│ gorev_id │────────<│ gorev_id       │>───────│ etiket_id │
│ baslik   │         │ etiket_id      │        │ etiket_ad │
└──────────┘         └────────────────┘        └───────────┘
                            ▲
                     ARA TABLO (junction table)
                     Sadece iki id tutar, başka bilgi yok.
```

Her satır bir **eşleşmeyi** temsil eder:

```
gorev_id | etiket_id
   1     |    2        ← 1 numaralı görevin 2 numaralı etiketi var
   1     |    5        ← aynı görevin bir etiketi daha
   3     |    2        ← başka bir görev, aynı etiket
```

> **Ders çıkarımı:** *"N:N ilişki doğrudan kurulamaz. Her zaman araya bir tablo girer. Bunu bir kez öğrenirseniz, ömür boyu her projede kullanırsınız — öğrenci-ders, ürün-kategori, film-oyuncu... hepsi aynı."*

---

## ⌨️ Adım 1: Tablolar

```sql
USE GorevDB;
GO

CREATE TABLE etiket (
    etiket_id BIGINT       NOT NULL IDENTITY(1,1) PRIMARY KEY,
    etiket_ad NVARCHAR(50) NOT NULL,
    aktif_mi  BIT          NOT NULL DEFAULT 1
);
GO

CREATE UNIQUE INDEX etiket_ad_unique ON etiket(etiket_ad);
GO


-- ⭐ ARA TABLO
CREATE TABLE gorev_etiket (
    gorev_id  BIGINT NOT NULL,
    etiket_id BIGINT NOT NULL,

    -- ⭐ BİLEŞİK BİRİNCİL ANAHTAR (composite primary key)
    --    İki sütun BİRLİKTE birincil anahtar oluşturuyor.
    --    Sonuç: aynı görev-etiket çifti iki kez eklenemez.
    --    Ayrı bir id sütununa gerek yok.
    CONSTRAINT gorev_etiket_pk PRIMARY KEY (gorev_id, etiket_id),

    CONSTRAINT gorev_etiket_gorev_fk
        FOREIGN KEY (gorev_id)  REFERENCES gorev(gorev_id),

    CONSTRAINT gorev_etiket_etiket_fk
        FOREIGN KEY (etiket_id) REFERENCES etiket(etiket_id)
);
GO


-- Örnek etiketler
INSERT INTO etiket (etiket_ad) VALUES
    (N'acil'), (N'toplantı'), (N'rapor'),
    (N'kişisel'), (N'beklemede'), (N'araştırma');
GO
```

### 📖 Bileşik birincil anahtar

Bu tabloda `gorev_etiket_id` diye bir sütun **yok** — gerek de yok.

```sql
PRIMARY KEY (gorev_id, etiket_id)
```

"Bu iki sütunun **birlikte** oluşturduğu değer benzersiz olmalı" demek.

**Canlı deney:**
```sql
INSERT INTO gorev_etiket VALUES (1, 2);   -- ✅ çalışır
INSERT INTO gorev_etiket VALUES (1, 2);   -- ❌ hata: duplicate key
INSERT INTO gorev_etiket VALUES (1, 3);   -- ✅ çalışır (farklı etiket)
INSERT INTO gorev_etiket VALUES (5, 2);   -- ✅ çalışır (farklı görev)
```

*"Veritabanı bizim yerimize 'aynı etiketi iki kez ekleme' kuralını uyguluyor. Kodda kontrol yazmamıza gerek kalmıyor."*

---

## ⌨️ Adım 2: Model

`Models/Etiket.cs`:

```csharp
namespace GorevTakip.Models;

public class Etiket
{
    public long EtiketId { get; set; }
    public string EtiketAd { get; set; } = "";
    public bool AktifMi { get; set; } = true;
}
```

`Models/Gorev.cs`'e ekle:

```csharp
    // ── Etiketler ────────────────────────────────────────────
    // Veritabanında gorev tablosunda YOK — ara tablodan gelir.

    /// <summary>
    /// Bu göreve atanmış etiketler (listede göstermek için).
    /// </summary>
    public List<Etiket> Etiketler { get; set; } = new();

    /// <summary>
    /// Formdan gelen seçili etiket id'leri.
    /// Checkbox listesi bu alana bağlanır.
    /// </summary>
    public List<long> SeciliEtiketIdler { get; set; } = new();
```

> **İki ayrı alan neden?**
> `Etiketler` → **okumak** için (etiket adları, renkleri)
> `SeciliEtiketIdler` → **yazmak** için (formdan gelen sadece id'ler)
>
> Form gönderirken etiketin adına ihtiyacımız yok, sadece hangilerinin seçildiğine.

---

## ⌨️ Adım 3: Repository

`Data/EtiketRepository.cs`:

```csharp
using Microsoft.Data.SqlClient;
using GorevTakip.Models;

namespace GorevTakip.Data;

public class EtiketRepository
{
    private readonly string _baglantiMetni;

    public EtiketRepository(IConfiguration configuration)
    {
        _baglantiMetni = configuration.GetConnectionString("GorevDb")!;
    }

    /// <summary>
    /// Tüm aktif etiketler (form listesi için).
    /// </summary>
    public List<Etiket> TumunuGetir()
    {
        var liste = new List<Etiket>();

        string sql = @"SELECT etiket_id, etiket_ad, aktif_mi
                       FROM etiket
                       WHERE aktif_mi = 1
                       ORDER BY etiket_ad";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                while (okuyucu.Read())
                {
                    liste.Add(new Etiket
                    {
                        EtiketId = okuyucu.GetInt64(okuyucu.GetOrdinal("etiket_id")),
                        EtiketAd = okuyucu.GetString(okuyucu.GetOrdinal("etiket_ad")),
                        AktifMi  = okuyucu.GetBoolean(okuyucu.GetOrdinal("aktif_mi"))
                    });
                }
            }
        }

        return liste;
    }

    /// <summary>
    /// Bir görevin etiketleri.
    ///
    /// ⭐ İKİ JOIN: gorev_etiket → etiket
    ///    Ara tablo tek başına işe yaramaz, hep etiket tablosuyla
    ///    birleştirilir (id'den isme ulaşmak için).
    /// </summary>
    public List<Etiket> GorevinEtiketleri(long gorevId)
    {
        var liste = new List<Etiket>();

        string sql = @"SELECT e.etiket_id, e.etiket_ad, e.aktif_mi
                       FROM gorev_etiket ge
                       INNER JOIN etiket e ON ge.etiket_id = e.etiket_id
                       WHERE ge.gorev_id = @gorevId
                         AND e.aktif_mi = 1
                       ORDER BY e.etiket_ad";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            komut.Parameters.AddWithValue("@gorevId", gorevId);
            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                while (okuyucu.Read())
                {
                    liste.Add(new Etiket
                    {
                        EtiketId = okuyucu.GetInt64(okuyucu.GetOrdinal("etiket_id")),
                        EtiketAd = okuyucu.GetString(okuyucu.GetOrdinal("etiket_ad")),
                        AktifMi  = okuyucu.GetBoolean(okuyucu.GetOrdinal("aktif_mi"))
                    });
                }
            }
        }

        return liste;
    }

    /// <summary>
    /// Bir görevin etiketlerini kaydeder.
    ///
    /// ⭐ STRATEJİ: Önce HEPSİNİ SİL, sonra seçilenleri EKLE.
    ///
    ///    Alternatif: "hangileri eklendi, hangileri çıkarıldı" diye
    ///    karşılaştırmak. Daha verimli ama çok daha karmaşık.
    ///    Birkaç etiket için sil-ekle yeterli ve anlaşılır.
    ///
    ///    Gerçek projede binlerce ilişki olsaydı fark ederdi.
    /// </summary>
    public void GorevEtiketleriniKaydet(long gorevId, List<long> etiketIdler)
    {
        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        {
            baglanti.Open();

            // ── 1. Mevcut eşleşmeleri sil ────────────────────
            // Burada gerçek DELETE kullanıyoruz, soft delete değil.
            // Ara tablo satırı bir "kayıt" değil, sadece bir bağlantı.
            // Geçmişini saklamanın anlamı yok.
            string silSql = "DELETE FROM gorev_etiket WHERE gorev_id = @gorevId";

            using (SqlCommand silKomut = new SqlCommand(silSql, baglanti))
            {
                silKomut.Parameters.AddWithValue("@gorevId", gorevId);
                silKomut.ExecuteNonQuery();
            }

            // ── 2. Seçilenleri ekle ──────────────────────────
            if (etiketIdler == null || etiketIdler.Count == 0)
                return;   // hiç etiket seçilmemiş, iş bitti

            string ekleSql = @"INSERT INTO gorev_etiket (gorev_id, etiket_id)
                               VALUES (@gorevId, @etiketId)";

            foreach (long etiketId in etiketIdler)
            {
                using (SqlCommand ekleKomut = new SqlCommand(ekleSql, baglanti))
                {
                    ekleKomut.Parameters.AddWithValue("@gorevId", gorevId);
                    ekleKomut.Parameters.AddWithValue("@etiketId", etiketId);
                    ekleKomut.ExecuteNonQuery();
                }
            }
        }
    }
}
```

> **`Ekle` metodunda yeni bir ihtiyaç doğuyor:** Görev eklerken, kaydedilen görevin **id'sini** bilmemiz gerekiyor — etiketleri ona bağlayacağız. Ama `ExecuteNonQuery()` id döndürmez.
>
> Çözüm: `GorevRepository.Ekle`'yi değiştir:
> ```csharp
> public long Ekle(Gorev gorev)   // void değil, long döner
> {
>     string sql = @"INSERT INTO gorev (...) VALUES (...);
>                    SELECT CAST(SCOPE_IDENTITY() AS BIGINT);";
>     // ...
>     return Convert.ToInt64(komut.ExecuteScalar());   // ExecuteNonQuery değil!
> }
> ```
> `SCOPE_IDENTITY()` → "az önce eklediğim satırın otomatik id'si". `ExecuteScalar` ile okunur.

`Program.cs`: `builder.Services.AddScoped<EtiketRepository>();`

---

## ⌨️ Adım 4: Controller

`GorevController`'a `EtiketRepository`'yi enjekte et ve şunları ekle:

```csharp
/// <summary>
/// Etiket listesini View'a hazırlar.
/// </summary>
private void EtiketListesiniHazirla()
{
    ViewBag.TumEtiketler = _etiketRepo.TumunuGetir();
}

// GET: /Gorev/Create
public IActionResult Create()
{
    KategoriListesiniHazirla();
    EtiketListesiniHazirla();      // ⭐ yeni
    return View();
}

// POST: /Gorev/Create
[HttpPost]
[ValidateAntiForgeryToken]
public IActionResult Create(Gorev gorev)
{
    if (!ModelState.IsValid)
    {
        KategoriListesiniHazirla(gorev.KategoriId);
        EtiketListesiniHazirla();   // ⭐ bunu da unutma!
        return View(gorev);
    }

    // ⭐ Ekle artık id döndürüyor
    long yeniId = _gorevRepo.Ekle(gorev);

    // Etiketleri bağla
    _etiketRepo.GorevEtiketleriniKaydet(yeniId, gorev.SeciliEtiketIdler);

    TempData["Basarili"] = "Görev eklendi.";
    return RedirectToAction("Index");
}

// GET: /Gorev/Edit/5
public IActionResult Edit(long id)
{
    var gorev = _gorevRepo.IdIleGetir(id);
    if (gorev == null) return NotFound();

    // ⭐ Mevcut etiketleri işaretli getir
    gorev.SeciliEtiketIdler = _etiketRepo.GorevinEtiketleri(id)
                                          .Select(e => e.EtiketId)
                                          .ToList();

    KategoriListesiniHazirla(gorev.KategoriId);
    EtiketListesiniHazirla();
    return View(gorev);
}

// POST: /Gorev/Edit/5
[HttpPost]
[ValidateAntiForgeryToken]
public IActionResult Edit(Gorev gorev)
{
    if (!ModelState.IsValid)
    {
        KategoriListesiniHazirla(gorev.KategoriId);
        EtiketListesiniHazirla();
        return View(gorev);
    }

    _gorevRepo.Guncelle(gorev);
    _etiketRepo.GorevEtiketleriniKaydet(gorev.GorevId, gorev.SeciliEtiketIdler);

    TempData["Basarili"] = "Görev güncellendi.";
    return RedirectToAction("Index");
}
```

> **`.Select(e => e.EtiketId).ToList()`** — LINQ. "Etiket listesindeki her elemandan sadece id'yi al, liste yap" demek. Öğrenci LINQ'ü henüz bilmiyorsa döngüyle de yazılabilir:
> ```csharp
> var idler = new List<long>();
> foreach (var e in _etiketRepo.GorevinEtiketleri(id))
>     idler.Add(e.EtiketId);
> gorev.SeciliEtiketIdler = idler;
> ```
> İkisini de göster; LINQ'ün ne yaptığı böyle anlaşılır.

---

## ⌨️ Adım 5: Form — checkbox listesi

`Create.cshtml` ve `Edit.cshtml`'e ekle:

```html
<div class="mb-3">
    <label class="form-label">Etiketler</label>

    <div class="border rounded p-3 bg-light">
        @{
            var tumEtiketler = ViewBag.TumEtiketler as List<GorevTakip.Models.Etiket>;
        }

        @if (tumEtiketler == null || tumEtiketler.Count == 0)
        {
            <p class="text-muted small mb-0">Henüz etiket tanımlanmamış.</p>
        }
        else
        {
            @foreach (var etiket in tumEtiketler)
            {
                @* ⭐ Aynı name="SeciliEtiketIdler" ile birden çok checkbox.
                     ASP.NET Core işaretli olanları toplayıp List<long> yapar.
                     Bu, HTML formlarının en kullanışlı davranışlarından biri. *@
                <div class="form-check form-check-inline">
                    <input type="checkbox"
                           name="SeciliEtiketIdler"
                           value="@etiket.EtiketId"
                           id="etiket_@etiket.EtiketId"
                           class="form-check-input"
                           checked="@(Model != null && Model.SeciliEtiketIdler.Contains(etiket.EtiketId))" />

                    <label class="form-check-label small" for="etiket_@etiket.EtiketId">
                        @etiket.EtiketAd
                    </label>
                </div>
            }
        }
    </div>

    <div class="form-text">İsteğe bağlı. Birden çok etiket seçebilirsiniz.</div>
</div>
```

### 📖 Aynı isimde birden çok checkbox

Bu, öğrencinin görmesi gereken önemli bir HTML davranışı:

```html
<input type="checkbox" name="SeciliEtiketIdler" value="1" />
<input type="checkbox" name="SeciliEtiketIdler" value="2" />
<input type="checkbox" name="SeciliEtiketIdler" value="3" />
```

1 ve 3 işaretlenirse tarayıcı şunu gönderir:
```
SeciliEtiketIdler=1&SeciliEtiketIdler=3
```

ASP.NET Core bunu görür ve otomatik olarak `List<long> { 1, 3 }` yapar. **Hiçbir şey yazmamıza gerek yok** — model bağlama (model binding) bunu kendisi hallediyor.

> **Deney:** F12 → Network sekmesini aç, formu gönder, giden veriyi göster. Öğrenci "sihir" sandığı şeyin aslında basit bir kural olduğunu görür.

---

## ⌨️ Adım 6: Listede etiketleri göster

`GorevRepository.TumunuGetir()` her görevin etiketlerini de getirmeli. **En basit yol:**

```csharp
// Controller'da
var liste = _gorevRepo.TumunuGetir();

foreach (var g in liste)
    g.Etiketler = _etiketRepo.GorevinEtiketleri(g.GorevId);
```

> ⚠️ **Bu N+1 problemidir!** 50 görev varsa 51 sorgu çalışır (1 liste + 50 etiket sorgusu).
>
> **Sınıfa sor:** *"Bu kod 50 görevde kaç kez veritabanına gidiyor?"*
>
> Ders için kabul edilebilir ama öğrenci bunun bir sorun olduğunu **bilmeli**. Alıştırma D'de tek sorguyla çözecekler.

View'da:

```html
<td>
    <a asp-action="Details" asp-route-id="@g.GorevId" class="fw-semibold text-decoration-none">
        @g.Baslik
    </a>

    @if (g.Etiketler.Any())
    {
        <div class="mt-1">
            @foreach (var e in g.Etiketler)
            {
                <span class="badge bg-light text-dark border" style="font-size: .7rem;">
                    <i class="bi bi-tag"></i> @e.EtiketAd
                </span>
            }
        </div>
    }
</td>
```

---

## ▶️ Test senaryosu

| Test | Beklenen |
|---|---|
| Yeni görev + 2 etiket | Kaydedilir |
| SSMS: `SELECT * FROM gorev_etiket` | 2 satır var |
| Listede o görev | İki etiket rozeti |
| Düzenle | Mevcut etiketler **işaretli** |
| Bir etiketi kaldır, kaydet | Ara tabloda 1 satır kaldı |
| Hiç etiket seçme | Kaydedilir, rozet yok |
| Hatalı form gönder | Etiket listesi hâlâ görünüyor |

---

## ⚠️ Sık yapılan hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| Etiketler kaydolmuyor | `Ekle` hâlâ `void`, id dönmüyor | `SCOPE_IDENTITY()` + `ExecuteScalar` |
| `Violation of PRIMARY KEY` | Aynı çift iki kez ekleniyor | Önce `DELETE`, sonra `INSERT` |
| Düzenlemede etiketler işaretsiz | `SeciliEtiketIdler` doldurulmamış | `Edit` GET'te doldur |
| Etiket listesi boş (POST sonrası) | `EtiketListesiniHazirla()` çağrılmamış | `ModelState` bloğuna ekle |
| `SeciliEtiketIdler` hep boş | Checkbox `name` yanlış | Model'deki özellikle **birebir** aynı olmalı |
| Görev silinemiyor: FK hatası | Ara tabloda satır var | Önce `gorev_etiket`ten sil, ya da soft delete kullan |
| Liste çok yavaş | N+1 sorgu | Alıştırma D |

---

## ✏️ Öğrenci alıştırması

**A.** Etiket sistemini kur, test senaryolarını geçir.

**B.** Etiket CRUD'u yaz (etiket ekleme/düzenleme/silme ekranı). Artık kalıbı ezbere biliyorsun.

**C.** Etikete göre filtreleme ekle. Görev listesinde etiket rozetine tıklanınca o etiketli görevler gelsin.
İpucu: `WHERE g.gorev_id IN (SELECT gorev_id FROM gorev_etiket WHERE etiket_id = @etiketId)`

**D. N+1 problemini çöz (zorlayıcı).** Tüm etiketleri **tek sorguda** çek, kodda gruplandır:
```sql
SELECT ge.gorev_id, e.etiket_id, e.etiket_ad
FROM gorev_etiket ge
INNER JOIN etiket e ON ge.etiket_id = e.etiket_id
WHERE e.aktif_mi = 1
```
Sonra `Dictionary<long, List<Etiket>>` ile görevlere dağıt. 50 görevde kaç sorgudan kaça düştü?

**E.** Etiket bulutu: en çok kullanılan etiketler daha büyük yazıyla.

**F. Düşünme soruları:**
1. Ara tabloya `eklenme_tarihi` sütunu eklesek ne kazanırdık?
2. Ara tabloda neden soft delete kullanmadık?
3. Öğrenci-ders-not sistemi tasarlasan ara tablo neye benzerdi? Not bilgisi nereye yazılırdı?

---

## 🎓 Proje sonu

İki proje bitti. Öğrenci artık şunları yapabiliyor:

- ✅ Veritabanı tasarımını okuyup **eleştirebiliyor** (BIT vs NVARCHAR tartışması)
- ✅ CRUD kalıbını rehbersiz uygulayabiliyor
- ✅ 1:N ve N:N ilişkileri kurabiliyor
- ✅ Parametreli sorgu yazıyor, neden gerektiğini biliyor
- ✅ NULL'ın hem SQL'de hem C#'ta nasıl davrandığını biliyor
- ✅ Kimlik doğrulama kurabiliyor, şifre hash'lemeyi biliyor
- ✅ GET/POST ayrımını ve nedenini anlıyor

### Son ders: karşılaştırma

Sınıfa üç soru sor:

1. **"İlk proje kaç ders sürdü, bu kaç ders sürdü?"** → Farkı tahtaya yaz.
2. **"İki projede de tekrarlanan kod hangisiydi?"** → CRUD kalıbı. *"Peki bunu azaltmanın bir yolu var mı?"* → Generic repository, base controller, EF Core.
3. **"Üçüncü bir proje verilse ne kadar sürerdi?"**

### Bundan sonra

```
BURADASINIZ
    │
    ├──▶ Entity Framework Core    (SQL'i sizin yerinize yazar)
    ├──▶ ASP.NET Core Identity    (hazır kullanıcı sistemi)
    ├──▶ Web API + JavaScript     (mobil uygulama da bağlanabilir)
    ├──▶ Git ve GitHub            (takım çalışması)
    └──▶ Katmanlı mimari, testler
```
