# Modül 5 — Durum İşlemleri ve Filtreleme

**Süre:** 1-2 ders saati
**Kim yazıyor:** Beraber

---

## 🎯 Bu derste ne yapacağız

Uygulamayı **kullanılabilir** hâle getireceğiz:

1. Listeden tek tıkla görev tamamlama (form sayfasına gitmeden)
2. Duruma, kategoriye, önceliğe göre filtreleme
3. Başlıkta arama

---

## 📖 Kavram: Hızlı eylem (quick action)

**Sınıfa sor:** *"Bir görevi tamamlandı yapmak için şu an ne yapıyoruz?"*
→ Düzenle butonuna bas → form aç → durumu değiştir → kaydet → listeye dön. **Beş adım.**

*"Bunu tek tıkla yapabilir miyiz?"*

Yapabiliriz — ama dikkat: durum değiştirmek veriyi **değiştiren** bir işlem. Yani `<a>` linki olamaz, **POST** olmalı.

> **Hatırlatma:** Veriyi değiştiren hiçbir işlem GET ile yapılmaz. Arama motoru botu sayfadaki linkleri gezerse, tüm görevleriniz "tamamlandı" olurdu.

Çözüm: listedeki her satıra küçük bir **form** koymak.

---

## ⌨️ Adım 1: Repository — durum değiştirme

`GorevRepository`'ye ekle:

```csharp
/// <summary>
/// Görevin durumunu değiştirir.
///
/// ⭐ tamamlanma_tarihi'ni de birlikte yönetiyoruz:
///    Tamamlandıysa  → şu anki tarih yazılır
///    Geri alındıysa → NULL yapılır
///
/// İkisini ayrı ayrı güncelleseydik biri değişip diğeri
/// değişmediğinde tutarsız veri oluşurdu.
/// </summary>
public void DurumDegistir(long id, string yeniDurum)
{
    string sql = @"UPDATE gorev
                   SET durum = @durum,
                       tamamlanma_tarihi = @tamamlanmaTarihi,
                       updated_date = @updatedDate
                   WHERE gorev_id = @id";

    using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
    using (SqlCommand komut = new SqlCommand(sql, baglanti))
    {
        komut.Parameters.AddWithValue("@durum", yeniDurum);

        // Tamamlandıysa tarih yaz, değilse NULL
        if (yeniDurum == "Tamamlandi")
            komut.Parameters.AddWithValue("@tamamlanmaTarihi", DateTime.Now);
        else
            komut.Parameters.AddWithValue("@tamamlanmaTarihi", DBNull.Value);

        komut.Parameters.AddWithValue("@updatedDate", DateTime.Now);
        komut.Parameters.AddWithValue("@id", id);

        baglanti.Open();
        komut.ExecuteNonQuery();
    }
}
```

---

## ⌨️ Adım 2: Controller — hızlı eylemler

`GorevController`'a ekle:

```csharp
/// <summary>
/// Görevi tamamlandı olarak işaretler.
/// POST: /Gorev/Tamamla/5
/// </summary>
[HttpPost]
[ValidateAntiForgeryToken]
public IActionResult Tamamla(long id, string? donusUrl = null)
{
    _gorevRepo.DurumDegistir(id, "Tamamlandi");
    TempData["Basarili"] = "Görev tamamlandı.";

    // ⭐ Kullanıcı filtreli bir listedeydi — oraya geri döndürüyoruz.
    //    Bu olmadan filtresi sıfırlanır ve sinirlenir.
    if (!string.IsNullOrEmpty(donusUrl) && Url.IsLocalUrl(donusUrl))
        return Redirect(donusUrl);

    return RedirectToAction("Index");
}

/// <summary>
/// Tamamlanmış görevi geri alır.
/// POST: /Gorev/GeriAl/5
/// </summary>
[HttpPost]
[ValidateAntiForgeryToken]
public IActionResult GeriAl(long id, string? donusUrl = null)
{
    _gorevRepo.DurumDegistir(id, "Beklemede");
    TempData["Basarili"] = "Görev yeniden açıldı.";

    if (!string.IsNullOrEmpty(donusUrl) && Url.IsLocalUrl(donusUrl))
        return Redirect(donusUrl);

    return RedirectToAction("Index");
}
```

> **`Url.IsLocalUrl` yine karşımızda.** Modül 2'de giriş sonrası yönlendirmede görmüştük. Kullanıcıdan gelen bir adrese yönlendirirken **her zaman** bu kontrol yapılır — yoksa açık yönlendirme (open redirect) açığı oluşur.

---

## ⌨️ Adım 3: Listeye tamamla butonu

`Views/Gorev/Index.cshtml`'de her satırın işlemler sütununa:

```html
<td class="text-end text-nowrap">

    @* ⭐ Hızlı eylem — küçük bir form
       method="post" olduğu için antiforgery token otomatik ekleniyor
       (Tag Helper kullandığımız için) *@
    <form asp-action="@(g.TamamlandiMi ? "GeriAl" : "Tamamla")"
          asp-route-id="@g.GorevId"
          method="post" class="d-inline">

        @* Kullanıcı hangi sayfadaydı? Filtreli listeye geri dönebilsin *@
        <input type="hidden" name="donusUrl" value="@Context.Request.Path@Context.Request.QueryString" />

        @if (g.TamamlandiMi)
        {
            <button type="submit" class="btn btn-sm btn-outline-secondary"
                    title="Geri al">
                <i class="bi bi-arrow-counterclockwise"></i>
            </button>
        }
        else
        {
            <button type="submit" class="btn btn-sm btn-outline-success"
                    title="Tamamlandı olarak işaretle">
                <i class="bi bi-check-lg"></i>
            </button>
        }
    </form>

    <a asp-action="Edit" asp-route-id="@g.GorevId"
       class="btn btn-sm btn-outline-primary">
        <i class="bi bi-pencil"></i>
    </a>

    <a asp-action="Delete" asp-route-id="@g.GorevId"
       class="btn btn-sm btn-outline-danger">
        <i class="bi bi-trash"></i>
    </a>
</td>
```

> **`Context.Request.Path` + `QueryString`** → şu anki adresin tamamı. Örneğin `/Gorev?durum=Beklemede&kategoriId=2`. Bunu gizli alanda taşıyarak kullanıcıyı aynı filtreli listeye geri döndürüyoruz.
>
> **Deney:** Bu gizli alanı sil, filtreli bir listede görev tamamla. Filtre sıfırlanır. Sonra geri ekle. Küçük bir detay ama kullanıcı deneyimini belirleyen şey tam olarak bunlar.

---

## ⌨️ Adım 4: Filtreleme — repository

`GorevRepository`'ye:

```csharp
/// <summary>
/// Görevleri filtreleyerek getirir. Tüm parametreler isteğe bağlıdır.
/// </summary>
/// <param name="arama">Başlık veya açıklamada aranacak metin</param>
/// <param name="kategoriId">Belirli kategori (null = hepsi)</param>
/// <param name="durum">Belirli durum (null = hepsi)</param>
/// <param name="oncelik">Belirli öncelik (null = hepsi)</param>
/// <param name="sadeceGecikmis">true ise yalnızca gecikmiş görevler</param>
public List<Gorev> Filtrele(string? arama, long? kategoriId, string? durum,
                            int? oncelik, bool sadeceGecikmis)
{
    var liste = new List<Gorev>();

    // ── Koşulları parça parça kur ────────────────────────────
    // ⚠️ SQL METNİNİ parçalıyoruz — bu güvenli.
    //    DEĞERLERİ hep parametre olarak veriyoruz — bu şart.
    string kosullar = " WHERE g.aktif_mi = 1 ";

    if (!string.IsNullOrWhiteSpace(arama))
        kosullar += " AND (g.baslik LIKE @arama OR g.aciklama LIKE @arama) ";

    if (kategoriId.HasValue && kategoriId.Value > 0)
        kosullar += " AND g.kategori_id = @kategoriId ";

    if (!string.IsNullOrWhiteSpace(durum))
        kosullar += " AND g.durum = @durum ";

    if (oncelik.HasValue && oncelik.Value > 0)
        kosullar += " AND g.oncelik = @oncelik ";

    if (sadeceGecikmis)
    {
        // Gecikmiş = tarihi var + geçmiş + tamamlanmamış
        // (Model'deki GecikmisMi özelliğinin SQL karşılığı)
        kosullar += @" AND g.bitis_tarihi IS NOT NULL
                       AND g.bitis_tarihi < CAST(GETDATE() AS DATE)
                       AND g.durum <> 'Tamamlandi' ";
    }

    string sql = @"SELECT g.gorev_id, g.kategori_id, g.baslik, g.aciklama,
                          g.oncelik, g.durum, g.bitis_tarihi, g.tamamlanma_tarihi,
                          g.created_date, g.updated_date, g.aktif_mi,
                          k.kategori_ad, k.renk
                   FROM gorev g
                   INNER JOIN kategori k ON g.kategori_id = k.kategori_id"
                 + kosullar +
                 @" ORDER BY
                        CASE WHEN g.durum = 'Tamamlandi' THEN 1 ELSE 0 END,
                        g.oncelik DESC,
                        CASE WHEN g.bitis_tarihi IS NULL THEN 1 ELSE 0 END,
                        g.bitis_tarihi";

    using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
    using (SqlCommand komut = new SqlCommand(sql, baglanti))
    {
        // ⚠️ Parametreyi eklerken koşulun EKLENDİĞİ durumla
        //    aynı if'i kullan. Biri varsa diğeri de olmalı,
        //    yoksa "Must declare the scalar variable" hatası alırsın.
        if (!string.IsNullOrWhiteSpace(arama))
            komut.Parameters.AddWithValue("@arama", "%" + arama.Trim() + "%");

        if (kategoriId.HasValue && kategoriId.Value > 0)
            komut.Parameters.AddWithValue("@kategoriId", kategoriId.Value);

        if (!string.IsNullOrWhiteSpace(durum))
            komut.Parameters.AddWithValue("@durum", durum);

        if (oncelik.HasValue && oncelik.Value > 0)
            komut.Parameters.AddWithValue("@oncelik", oncelik.Value);

        baglanti.Open();

        using (SqlDataReader okuyucu = komut.ExecuteReader())
        {
            while (okuyucu.Read())
            {
                Gorev g = SatiriNesneyeCevir(okuyucu);
                g.KategoriAd   = okuyucu.GetString(okuyucu.GetOrdinal("kategori_ad"));
                g.KategoriRenk = okuyucu.GetString(okuyucu.GetOrdinal("renk"));
                liste.Add(g);
            }
        }
    }

    return liste;
}
```

### 📖 `LIKE` ve `%`

```sql
WHERE baslik LIKE '%rapor%'
```

| Desen | Bulur |
|---|---|
| `'rapor%'` | rapor ile **başlayan** |
| `'%rapor'` | rapor ile **biten** |
| `'%rapor%'` | rapor **içeren** |

`%` işaretleri **parametre değerine** eklenir, SQL metnine değil:
```csharp
komut.Parameters.AddWithValue("@arama", "%" + arama.Trim() + "%");
```

### 📖 `CAST(GETDATE() AS DATE)` neden?

`GETDATE()` tarih **ve saat** verir: `2026-10-15 14:32:07`.
`bitis_tarihi` ise sadece tarih: `2026-10-15`.

Karşılaştırırken saat kısmı sorun çıkarır — bugün bitmesi gereken bir görev, saat 14:32'de "gecikmiş" görünür. `CAST(... AS DATE)` saati atar.

> C# tarafında aynı işi `.Date` yapıyordu. Model'deki `GecikmisMi` özelliğine geri dön ve `.Date` kullanımını göster — **aynı problem, iki dilde iki çözüm.**

---

## ⌨️ Adım 5: Controller — filtreleri karşıla

```csharp
// GET: /Gorev?arama=rapor&kategoriId=2&durum=Beklemede
public IActionResult Index(string? arama, long? kategoriId, string? durum,
                           int? oncelik, bool sadeceGecikmis = false)
{
    var liste = _gorevRepo.Filtrele(arama, kategoriId, durum, oncelik, sadeceGecikmis);

    // ⭐ Filtre değerlerini View'a geri gönder — form dolu kalsın
    ViewBag.Arama          = arama;
    ViewBag.SeciliKategori = kategoriId;
    ViewBag.SeciliDurum    = durum;
    ViewBag.SeciliOncelik  = oncelik;
    ViewBag.SadeceGecikmis = sadeceGecikmis;

    KategoriListesiniHazirla(kategoriId);

    return View(liste);
}
```

> **Filtre değerlerini geri göndermezsen** kullanıcı arama yapar, sonuçları görür ama arama kutusu boşalmış olur. "Ne aramıştım ben?" Küçük ama can sıkıcı bir hata.

---

## ⌨️ Adım 6: Filtre formu

`Views/Gorev/Index.cshtml`'in en üstüne:

```html
<div class="card border-0 shadow-sm mb-3">
    <div class="card-body">

        @* ⭐ method="get" — POST DEĞİL!
           Sebep: arama sonuçları paylaşılabilir ve yer imine eklenebilir olmalı.
           Adres çubuğunda /Gorev?arama=rapor&durum=Beklemede görünür.
           Genel kural: arama = GET, kaydetme = POST *@
        <form method="get" asp-action="Index" class="row g-2 align-items-end">

            <div class="col-md-3">
                <label class="form-label small text-muted">Ara</label>
                <input type="text" name="arama" value="@ViewBag.Arama"
                       class="form-control form-control-sm"
                       placeholder="Başlık veya açıklama" />
            </div>

            <div class="col-md-2">
                <label class="form-label small text-muted">Kategori</label>
                <select name="kategoriId" asp-items="ViewBag.Kategoriler"
                        class="form-select form-select-sm">
                    <option value="">Tümü</option>
                </select>
            </div>

            <div class="col-md-2">
                <label class="form-label small text-muted">Durum</label>
                <select name="durum" class="form-select form-select-sm">
                    <option value="">Tümü</option>
                    <option value="Beklemede"
                            selected="@(ViewBag.SeciliDurum as string == "Beklemede")">
                        Beklemede
                    </option>
                    <option value="Devam ediyor"
                            selected="@(ViewBag.SeciliDurum as string == "Devam ediyor")">
                        Devam ediyor
                    </option>
                    <option value="Tamamlandi"
                            selected="@(ViewBag.SeciliDurum as string == "Tamamlandi")">
                        Tamamlandı
                    </option>
                </select>
            </div>

            <div class="col-md-2">
                <label class="form-label small text-muted">Öncelik</label>
                <select name="oncelik" class="form-select form-select-sm">
                    <option value="">Tümü</option>
                    <option value="3" selected="@(ViewBag.SeciliOncelik as int? == 3)">Yüksek</option>
                    <option value="2" selected="@(ViewBag.SeciliOncelik as int? == 2)">Orta</option>
                    <option value="1" selected="@(ViewBag.SeciliOncelik as int? == 1)">Düşük</option>
                </select>
            </div>

            <div class="col-md-3">
                <div class="form-check mb-2">
                    <input type="checkbox" name="sadeceGecikmis" value="true"
                           class="form-check-input" id="gecikmisKutu"
                           checked="@(ViewBag.SadeceGecikmis as bool? == true)" />
                    <label class="form-check-label small" for="gecikmisKutu">
                        Sadece gecikmişler
                    </label>
                </div>

                <button type="submit" class="btn btn-primary btn-sm">
                    <i class="bi bi-search"></i> Filtrele
                </button>
                <a asp-action="Index" class="btn btn-outline-secondary btn-sm">Temizle</a>
            </div>

        </form>
    </div>
</div>
```

### Boş sonuç mesajı — iki farklı durum

```html
@if (Model.Count == 0)
{
    <div class="text-center text-muted py-5">
        @* Filtre var mı yok mu? Kullanıcının atacağı adım farklı. *@
        @{
            bool filtreVar = !string.IsNullOrEmpty(ViewBag.Arama as string)
                          || ViewBag.SeciliKategori != null
                          || !string.IsNullOrEmpty(ViewBag.SeciliDurum as string)
                          || ViewBag.SeciliOncelik != null
                          || (ViewBag.SadeceGecikmis as bool? == true);
        }

        @if (filtreVar)
        {
            <i class="bi bi-search fs-1 d-block mb-2"></i>
            <p class="mb-3">Filtrenize uyan görev bulunamadı.</p>
            <a asp-action="Index" class="btn btn-sm btn-outline-primary">
                Filtreleri temizle
            </a>
        }
        else
        {
            <i class="bi bi-clipboard-check fs-1 d-block mb-2"></i>
            <p class="mb-3">Henüz görev yok.</p>
            <a asp-action="Create" class="btn btn-sm btn-success">İlk görevi ekle</a>
        }
    </div>
}
```

> **Arayüz yazısı dersi:** "Sonuç bulunamadı" iki farklı duruma aynı cevabı verir. Ama kullanıcının yapması gereken şey farklı: birinde filtreyi temizlemeli, diğerinde kayıt eklemeli. **İyi arayüz, kullanıcıya bir sonraki adımı söyler.**

---

## ▶️ Test senaryosu

| Test | Beklenen |
|---|---|
| Yeşil tik butonu | Görev tamamlandı, satır soluklaştı |
| Geri al butonu | Görev yeniden açıldı |
| SSMS'te kontrol | `tamamlanma_tarihi` doldu / NULL oldu |
| Filtrele → tamamla | **Aynı filtreli listeye** dönüyor |
| "rapor" ara | Başlığında/açıklamasında geçenler |
| Kategori + durum birlikte | İkisi de uygulanmış |
| "Sadece gecikmişler" | Kırmızı satırlar |
| Adres çubuğuna `?durum=Beklemede` | Doğrudan filtreli liste |
| Temizle | Tüm filtreler sıfır |
| Olmayan bir şey ara | "Filtreleri temizle" butonu |

---

## ⚠️ Sık yapılan hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| `Must declare the scalar variable '@arama'` | Koşul eklendi, parametre eklenmedi | İki `if` aynı olmalı |
| Arama hiçbir şey bulmuyor | `%` işaretleri eksik | `"%" + arama + "%"` |
| Filtre seçili kalmıyor | ViewBag'e geri gönderilmemiş | Controller'da ata |
| Tamamlayınca filtre sıfırlanıyor | `donusUrl` gizli alanı yok | Ekle |
| `400 Bad Request` (tamamla) | Antiforgery token yok | Formu `asp-action` ile yaz |
| Checkbox hep işaretsiz | `checked` bağlaması yanlış | `as bool? == true` |
| Bugün biten görev "gecikmiş" | Saat karşılaştırması | `CAST(GETDATE() AS DATE)` |
| Tamamlanan görev `tamamlanma_tarihi` boş | `DurumDegistir` çağrılmamış | Edit yerine hızlı eylemi kullan |

---

## ✏️ Öğrenci alıştırması

**A.** Filtreleme ve hızlı eylemleri tamamla.

**B.** Üst kısma **hızlı filtre butonları** ekle: `Bugün` / `Bu hafta` / `Gecikmiş` / `Tamamlanan`. Tek tıkla ilgili listeyi açsın.

**C.** "Devam ediyor" için de hızlı eylem ekle. Buton döngüsü: Beklemede → Devam ediyor → Tamamlandı → Beklemede.

**D.** Toplu işlem: satırlara onay kutusu koy, seçilenleri tek seferde tamamla.
*(Zorlayıcı — birden çok id'yi POST etmeyi gerektirir.)*

**E. Düşünme soruları:**
1. Filtreleme neden GET, tamamlama neden POST? Tersini yapsak ne olurdu?
2. `Filtrele` metodunda SQL metnini birleştiriyoruz. Bu SQL injection açığı mı? Neden?
3. 10.000 görev olsaydı `LIKE '%rapor%'` ne kadar sürerdi? Neden yavaş?

---

👉 Sonraki: [`07-dashboard.md`](07-dashboard.md)
