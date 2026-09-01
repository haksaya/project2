# Modül 2 — Giriş Sistemi

**Süre:** 1-2 ders saati
**Kim yazıyor:** Eğitmen

---

## 🎯 Bu derste ne yapacağız

Sisteme giriş ekranı ekleyeceğiz. Giriş yapmayan **hiçbir sayfayı** göremeyecek.

> **Neden bu kadar erken?** Okul projesinde login en sondaydı ve opsiyoneldi. Gerçek projelerde güvenlik sonradan eklenen bir süs değil, en baştan kurulan bir temeldir. Bu sefer doğru sırayla yapıyoruz.

---

## 📖 Kavram 1: Şifreler asla düz metin saklanmaz

**Sınıfa sor:** *"Şifreyi veritabanına olduğu gibi yazsak ne olur?"*

Cevaplar gelsin, sonra üçünü de tahtaya yaz:
1. Veritabanı sızarsa herkesin şifresi açığa çıkar
2. Veritabanına erişimi olan herkes — **siz dâhil** — şifreleri görür
3. İnsanlar aynı şifreyi başka sitelerde kullanır → zincirleme felaket

**Çözüm: hash (özet)** — geri çevrilemez tek yönlü dönüşüm.

```
"gorev123"  ──SHA256──▶  "8A9F2C...64 karakter..."
                                 ▲
                       buradan geriye DÖNÜLEMEZ
```

Girişte kullanıcının yazdığını tekrar hash'ler, saklananla karşılaştırırız. Şifreyi hiç bilmeyiz.

> ⚠️ **Dürüst uyarı — mutlaka söyle:**
> SHA256 bu ders için uygun ama **gerçek projede şifre için yeterli değil.** İki sebeple: çok *hızlı* (saldırgan saniyede milyarlarca deneme yapar) ve *tuz* içermiyor (aynı şifre hep aynı hash'i verir). Gerçekte BCrypt, Argon2 veya ASP.NET Core'un `PasswordHasher` sınıfı kullanılır. Bunu söylemezsen öğrenci SHA256'yı doğru yöntem sanır.

---

## 📖 Kavram 2: Kimlik doğrulama vs yetkilendirme

| | Soru | Bizim sistemde |
|---|---|---|
| **Kimlik doğrulama** (authentication) | "Sen kimsin?" | ✅ Var |
| **Yetkilendirme** (authorization) | "Buna hakkın var mı?" | ❌ Yok |

Tek kullanıcı, tek yetki seviyesi. Giren herkes her şeyi yapabilir. Bu bilinçli bir sadeleştirme — rol eklemek iyi bir genişletme alıştırması olur.

---

## ⌨️ Adım 1: Admin hesabını ekle

```sql
USE GorevDB;
GO

-- Kullanıcı adı: admin   |   Şifre: gorev123
INSERT INTO kullanici (kullanici_adi, sifre_hash, ad_soyad)
VALUES ('admin',
        '8A9F2C0C8E5B7A9A9C8E5F1B7D3A2E4C6B8D0F2A4C6E8B0D2F4A6C8E0B2D4F6A',
        N'Sistem Yöneticisi');
GO
```

> ⚠️ **Yukarıdaki hash örnektir, doğru değildir.** Doğrusunu Adım 3'te kendi kodunuzla üreteceksiniz — bu, dersin en güzel anlarından biri. Şimdilik bu satırı çalıştırmayın.

---

## ⌨️ Adım 2: Model

`Models/Kullanici.cs`:

```csharp
using System.ComponentModel.DataAnnotations;

namespace GorevTakip.Models;

public class Kullanici
{
    public long KullaniciId { get; set; }
    public string KullaniciAdi { get; set; } = "";
    public string SifreHash { get; set; } = "";   // şifrenin kendisi değil, özeti
    public string AdSoyad { get; set; } = "";
    public DateTime CreatedDate { get; set; }
    public bool AktifMi { get; set; } = true;     // ⭐ bool — BIT sütunun karşılığı
}

/// <summary>
/// Giriş formunun taşıyıcısı.
///
/// ⭐ NEDEN AYRI SINIF? — sınıfa sor:
///    Forma doğrudan Kullanici verseydik, form SifreHash alanını da
///    içerirdi. Kötü niyetli biri F12 ile gizli alan ekleyip doğrudan
///    hash göndermeyi deneyebilirdi.
///    Kural: kullanıcıdan gelen modele SADECE gereken alanları koy.
/// </summary>
public class GirisViewModel
{
    [Required(ErrorMessage = "Kullanıcı adı gerekli.")]
    [Display(Name = "Kullanıcı adı")]
    public string KullaniciAdi { get; set; } = "";

    [Required(ErrorMessage = "Şifre gerekli.")]
    [DataType(DataType.Password)]
    [Display(Name = "Şifre")]
    public string Sifre { get; set; } = "";

    [Display(Name = "Beni hatırla")]
    public bool BeniHatirla { get; set; }
}
```

> **`bool AktifMi` — ilk fark burada görünüyor.** Okul projesinde `string IsActive = "1"` yazıyorduk. BIT sütunu `bool` ile eşleşir, okurken `GetBoolean` kullanılır.

---

## ⌨️ Adım 3: Repository

`Data/KullaniciRepository.cs`:

```csharp
using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.SqlClient;
using GorevTakip.Models;

namespace GorevTakip.Data;

public class KullaniciRepository
{
    private readonly string _baglantiMetni;

    public KullaniciRepository(IConfiguration configuration)
    {
        _baglantiMetni = configuration.GetConnectionString("GorevDb")!;
    }

    /// <summary>
    /// Metnin SHA256 özetini döner.
    /// static → nesne oluşturmadan çağrılabilir:
    ///     KullaniciRepository.SifreyiHashle("gorev123")
    /// </summary>
    public static string SifreyiHashle(string sifre)
    {
        byte[] bayt = Encoding.UTF8.GetBytes(sifre);   // metni bayta çevir
        byte[] hash = SHA256.HashData(bayt);           // özeti hesapla
        return Convert.ToHexString(hash);              // okunabilir metne çevir
    }

    /// <summary>
    /// Kullanıcı adı ve şifre doğruysa kullanıcıyı, yanlışsa null döner.
    ///
    /// ⭐ Karşılaştırmayı VERİTABANINDA yapıyoruz:
    ///    "bu ad VE bu hash'e sahip satır var mı?"
    ///    Böylece hash hiç uygulamaya taşınmıyor.
    /// </summary>
    public Kullanici? Dogrula(string kullaniciAdi, string sifre)
    {
        string hash = SifreyiHashle(sifre);

        // sifre_hash sütununu SELECT'e koymuyoruz — dolaşmasına gerek yok
        string sql = @"SELECT kullanici_id, kullanici_adi, ad_soyad,
                              created_date, aktif_mi
                       FROM kullanici
                       WHERE kullanici_adi = @ad
                         AND sifre_hash    = @hash
                         AND aktif_mi      = 1";

        using (SqlConnection baglanti = new SqlConnection(_baglantiMetni))
        using (SqlCommand komut = new SqlCommand(sql, baglanti))
        {
            // ⭐ Giriş formu, SQL injection'ın en klasik hedefidir.
            //    Şifre alanına  ' OR '1'='1  yazan biri,
            //    parametre kullanmasaydık içeri girerdi.
            komut.Parameters.AddWithValue("@ad", kullaniciAdi);
            komut.Parameters.AddWithValue("@hash", hash);

            baglanti.Open();

            using (SqlDataReader okuyucu = komut.ExecuteReader())
            {
                if (okuyucu.Read())
                {
                    return new Kullanici
                    {
                        KullaniciId  = okuyucu.GetInt64(okuyucu.GetOrdinal("kullanici_id")),
                        KullaniciAdi = okuyucu.GetString(okuyucu.GetOrdinal("kullanici_adi")),
                        AdSoyad      = okuyucu.GetString(okuyucu.GetOrdinal("ad_soyad")),
                        CreatedDate  = okuyucu.GetDateTime(okuyucu.GetOrdinal("created_date")),

                        // ⭐ BIT sütunu → GetBoolean
                        AktifMi      = okuyucu.GetBoolean(okuyucu.GetOrdinal("aktif_mi"))
                    };
                }
            }
        }

        return null;   // kullanıcı yok VEYA şifre yanlış
    }
}
```

### 🎬 Canlı deney: hash'i kendimiz üretelim

Bu, dersin en akılda kalıcı 5 dakikası. `HomeController`'a **geçici** bir metot ekle:

```csharp
// ⚠️ GEÇİCİ — deneyden sonra SİL!
public IActionResult HashUret()
{
    return Content(KullaniciRepository.SifreyiHashle("gorev123"));
}
```

Tarayıcıda `/Home/HashUret` adresine git. Ekranda 64 karakterlik bir metin çıkacak. **Onu kopyala** ve SQL'e yapıştır:

```sql
INSERT INTO kullanici (kullanici_adi, sifre_hash, ad_soyad)
VALUES ('admin', 'BURAYA_YAPISTIR', N'Sistem Yöneticisi');
```

Sonra `"gorev124"` (tek karakter fark) ile dene — çıktı tamamen değişir.

**Sor:** *"Bu metinden şifreyi geri bulabilir misiniz?"* → Hayır, hash tek yönlüdür.

> ⚠️ Deney bitince `HashUret` metodunu **sil.** Canlıda kalırsa isteyen istediği hash'i üretir.

---

## ⌨️ Adım 4: Controller

`Controllers/HesapController.cs`:

```csharp
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using GorevTakip.Data;
using GorevTakip.Models;

namespace GorevTakip.Controllers;

// ⭐ [AllowAnonymous] ŞART!
//    Program.cs'te tüm uygulamayı "giriş zorunlu" yapacağız.
//    Bu controller muaf olmazsa, giriş sayfasına girmek için
//    giriş yapmak gerekir → SONSUZ DÖNGÜ.
[AllowAnonymous]
public class HesapController : Controller
{
    private readonly KullaniciRepository _repo;

    public HesapController(KullaniciRepository repo)
    {
        _repo = repo;
    }

    // GET: /Hesap/Giris
    [HttpGet]
    public IActionResult Giris(string? donusUrl = null)
    {
        // Zaten girmişse formu gösterme
        if (User.Identity != null && User.Identity.IsAuthenticated)
            return RedirectToAction("Index", "Home");

        ViewBag.DonusUrl = donusUrl;
        return View();
    }

    // POST: /Hesap/Giris
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Giris(GirisViewModel model, string? donusUrl = null)
    {
        ViewBag.DonusUrl = donusUrl;

        if (!ModelState.IsValid)
            return View(model);

        Kullanici? kullanici = _repo.Dogrula(model.KullaniciAdi, model.Sifre);

        if (kullanici == null)
        {
            // ⚠️ "Kullanıcı yok" ile "şifre yanlış"ı AYIRMA!
            //    Ayrı söyleseydik saldırgan, kayıtlı kullanıcı adlarını
            //    tek tek deneyerek öğrenirdi (user enumeration).
            //    Belirsizlik KASITLIDIR.
            ModelState.AddModelError("", "Kullanıcı adı veya şifre hatalı.");
            return View(model);
        }

        // Claim = kullanıcı hakkında bir bilgi parçası.
        // Çereze şifrelenerek yazılır, her istekte sunucuya gelir.
        var iddialar = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, kullanici.KullaniciId.ToString()),
            new Claim(ClaimTypes.Name, kullanici.AdSoyad),
            new Claim("KullaniciAdi", kullanici.KullaniciAdi)
        };

        var kimlik = new ClaimsIdentity(iddialar,
            CookieAuthenticationDefaults.AuthenticationScheme);

        var ozellikler = new AuthenticationProperties
        {
            IsPersistent = model.BeniHatirla,   // tarayıcı kapansa da yaşasın mı?
            AllowRefresh = true
        };

        // Çerezi oluştur — kullanıcı artık giriş yapmış sayılır
        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(kimlik),
            ozellikler);

        // ⚠️ Url.IsLocalUrl kontrolü ŞART!
        //    Olmasaydı saldırgan şöyle link hazırlayabilirdi:
        //      /Hesap/Giris?donusUrl=https://sahte-site.com
        //    Kullanıcı giriş sonrası sahte siteye giderdi (open redirect).
        if (!string.IsNullOrEmpty(donusUrl) && Url.IsLocalUrl(donusUrl))
            return Redirect(donusUrl);

        return RedirectToAction("Index", "Home");
    }

    // POST: /Hesap/Cikis
    //
    // ⚠️ Neden POST? Çıkış durumu DEĞİŞTİREN bir işlem.
    //    GET olsaydı kötü niyetli sitedeki
    //      <img src=".../Hesap/Cikis">
    //    etiketi kullanıcıyı habersizce çıkartırdı.
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Cikis()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        TempData["Bilgi"] = "Oturumunuz kapatıldı.";
        return RedirectToAction("Giris");
    }
}
```

---

## ⌨️ Adım 5: Giriş sayfası

`Views/Hesap/Giris.cshtml`:

```html
@model GorevTakip.Models.GirisViewModel
@{
    Layout = null;   @* ⭐ Giriş sayfasında sol menü olmasın — henüz içeri girmedi *@
}

<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Giriş - GörevTakip</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css" rel="stylesheet">
</head>
<body class="bg-light">

    <div class="container">
        <div class="row justify-content-center align-items-center" style="min-height: 100vh;">
            <div class="col-md-4">

                <div class="card border-0 shadow">
                    <div class="card-body p-4">

                        <div class="text-center mb-4">
                            <i class="bi bi-check2-square fs-1 text-success"></i>
                            <h5 class="mt-2 mb-1">GörevTakip</h5>
                            <p class="text-muted small mb-0">Devam etmek için giriş yapın</p>
                        </div>

                        @if (TempData["Bilgi"] != null)
                        {
                            <div class="alert alert-info py-2 small">@TempData["Bilgi"]</div>
                        }

                        <form asp-action="Giris" method="post">

                            <input type="hidden" name="donusUrl" value="@ViewBag.DonusUrl" />

                            <div asp-validation-summary="ModelOnly"
                                 class="alert alert-danger py-2 small"></div>

                            <div class="mb-3">
                                <label asp-for="KullaniciAdi" class="form-label"></label>
                                <input asp-for="KullaniciAdi" class="form-control" autofocus />
                                <span asp-validation-for="KullaniciAdi" class="text-danger small"></span>
                            </div>

                            <div class="mb-3">
                                <label asp-for="Sifre" class="form-label"></label>
                                <input asp-for="Sifre" type="password" class="form-control" />
                                <span asp-validation-for="Sifre" class="text-danger small"></span>
                            </div>

                            <div class="form-check mb-3">
                                <input asp-for="BeniHatirla" class="form-check-input" />
                                <label asp-for="BeniHatirla" class="form-check-label small"></label>
                            </div>

                            <button type="submit" class="btn btn-success w-100">
                                <i class="bi bi-box-arrow-in-right"></i> Giriş yap
                            </button>

                        </form>

                    </div>
                </div>

                @* ⚠️ CANLIYA ÇIKMADAN ÖNCE SİL *@
                <div class="alert alert-warning small mt-3 mb-0">
                    <strong>Ders ortamı:</strong> <code>admin</code> / <code>gorev123</code>
                </div>

            </div>
        </div>
    </div>

    <partial name="_ValidationScriptsPartial" />
</body>
</html>
```

---

## ⌨️ Adım 6: Program.cs

Üç ekleme + bir sıra kuralı:

```csharp
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Authorization;
using GorevTakip.Data;

var builder = WebApplication.CreateBuilder(args);

// ── 1. "Giriş zorunlu" filtresi ─────────────────────────────
//
// ⭐ Neden global filtre, her controller'a [Authorize] değil?
//    Yarın yeni controller yazıp [Authorize] koymayı unutursan
//    o sayfa herkese açık kalır. Global filtreyle varsayılan KAPALI olur.
//    GÜVENLİK İLKESİ: varsayılan hep en kısıtlayıcı seçenek olmalı.
builder.Services.AddControllersWithViews(secenekler =>
{
    var politika = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();

    secenekler.Filters.Add(new AuthorizeFilter(politika));
});

// ── 2. Çerez ayarı ──────────────────────────────────────────
builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(secenekler =>
    {
        secenekler.LoginPath = "/Hesap/Giris";
        secenekler.ReturnUrlParameter = "donusUrl";   // controller parametresiyle aynı olmalı!
        secenekler.ExpireTimeSpan = TimeSpan.FromHours(8);
        secenekler.SlidingExpiration = true;
        secenekler.Cookie.HttpOnly = true;            // JS çereze erişemez → XSS koruması
        secenekler.Cookie.SameSite = SameSiteMode.Lax; // CSRF koruması
        secenekler.Cookie.Name = "GorevTakip.Oturum";
    });

// ── 3. Repository ───────────────────────────────────────────
builder.Services.AddScoped<KullaniciRepository>();

var app = builder.Build();

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

// ⭐⭐ SIRA KRİTİK
app.UseAuthentication();   // ÖNCE: "sen kimsin?" (çerezi okur)
app.UseAuthorization();    // SONRA: "girebilir mi?" (filtreyi uygular)

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();
```

> **Ters yazma deneyi:** İki satırın yerini bilerek değiştir. Doğru şifreyle giren kullanıcı bile içeri alınmaz, üstelik hata mesajı hiçbir ipucu vermez — sadece giriş sayfasına döner durur. Bu deneyi yaptır; öğrencinin ileride saatlerini kurtarır.

---

## ⌨️ Adım 7: Layout'a kullanıcı menüsü

`_Layout.cshtml`'de "Kullanıcı menüsü Modül 2'de buraya eklenecek" yazan yorumun yerine:

```html
@if (User.Identity != null && User.Identity.IsAuthenticated)
{
    <div class="dropdown">
        <button class="btn btn-sm btn-outline-secondary dropdown-toggle"
                data-bs-toggle="dropdown">
            <i class="bi bi-person-circle"></i> @User.Identity.Name
        </button>
        <ul class="dropdown-menu dropdown-menu-end">
            <li>
                <span class="dropdown-item-text small text-muted">
                    @User.FindFirst("KullaniciAdi")?.Value
                </span>
            </li>
            <li><hr class="dropdown-divider"></li>
            <li>
                @* Çıkış POST olmalı — sebebi controller'da yazılı *@
                <form asp-controller="Hesap" asp-action="Cikis" method="post">
                    <button type="submit" class="dropdown-item text-danger">
                        <i class="bi bi-box-arrow-right"></i> Çıkış yap
                    </button>
                </form>
            </li>
        </ul>
    </div>
}
```

> **`@User` her view'da hazır bulunur** — controller'dan göndermeye gerek yok. Adım 4'te yazdığımız `new Claim(ClaimTypes.Name, ...)` satırının karşılığı işte burada ekrana geliyor. Bu bağlantıyı öğrenciye göster.

---

## ▶️ Test senaryosu

| Test | Beklenen |
|---|---|
| `/` adresine git | Giriş sayfasına yönlendirir |
| Yanlış şifre | "Kullanıcı adı veya şifre hatalı" |
| Doğru giriş | Panele gider, sağ üstte ad görünür |
| `/Gorev` yaz (giriş yapmadan) | Giriş sayfası + adreste `?donusUrl=/Gorev` |
| Giriş yap | Doğrudan `/Gorev`'e gider |
| Çıkış yap | Giriş sayfası, "oturum kapatıldı" mesajı |

---

## ⚠️ Sık yapılan hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| Sonsuz yönlendirme döngüsü | `HesapController`'da `[AllowAnonymous]` yok | Ekle |
| Giriş oluyor ama sayfa hâlâ engelli | `UseAuthentication` yanlış sırada | `UseAuthorization`'dan **önce** |
| Şifre doğru ama girmiyor | Veritabanındaki hash farklı | `HashUret` deneyiyle karşılaştır |
| `@User.Identity.Name` boş | Claim eklenmemiş | `ClaimTypes.Name` claim'i var mı? |
| Giriş sonrası hep panele gidiyor | `ReturnUrlParameter` ile metot parametresi farklı | İkisi de `donusUrl` olmalı |
| Kullanıcı menüsü açılmıyor | Bootstrap JS yok | Layout'ta `bootstrap.bundle.min.js` |

---

## ✏️ Öğrenci alıştırması

**A.** Login sistemini kur, tüm test senaryolarını geçir.

**B.** Şifre değiştirme ekranı yaz. Form: mevcut şifre + yeni şifre + yeni şifre tekrar.
İpucu: `[Compare("YeniSifre")]` özniteliği iki alanın eşitliğini kontrol eder.

**C. Düşünme soruları:**
1. Şifreleri düz metin saklasaydık ve veritabanı sızsaydı, sadece bu site mi etkilenirdi?
2. "Kullanıcı adı veya şifre hatalı" yerine "Böyle bir kullanıcı yok" deseydik saldırgan ne öğrenirdi?
3. Çerez çalınırsa ne olur? Nasıl korunulur?

---

👉 Sonraki: [`04-kategori-crud.md`](04-kategori-crud.md)
