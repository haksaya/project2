# Modül 1 — Proje İskeleti ve Layout

**Süre:** 1 ders saati
**Kim yazıyor:** Eğitmen (öğrenci izler ve aynı anda yazar)

---

## 🎯 Bu derste ne yapacağız

Projeyi oluşturup bağlantıyı kuracağız ve ortak sayfa iskeletini yazacağız. **Yeni kavram yok** — bu modül tamamen tekrar. Hızlı geç.

---

## ⌨️ Adım 1: Proje

**Visual Studio:** Yeni proje → `ASP.NET Core Web App (Model-View-Controller)` → ad: `GorevTakip`

**Terminal:**
```bash
dotnet new mvc -n GorevTakip
cd GorevTakip
dotnet add package Microsoft.Data.SqlClient
```

> Paketi kurmayı unutma. `Microsoft.Data.SqlClient` — eski `System.Data.SqlClient` değil.

---

## ⌨️ Adım 2: Bağlantı dizesi

`appsettings.json`:

```json
{
  "ConnectionStrings": {
    "GorevDb": "Server=localhost\\SQLEXPRESS;Database=GorevDB;Trusted_Connection=True;TrustServerCertificate=True;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

**Sınıfa sor:** *"Anahtarın adı `GorevDb`. Bunu kodda nasıl okuyacağız?"*
→ `configuration.GetConnectionString("GorevDb")` — **birebir aynı yazılmalı.**

---

## ⌨️ Adım 3: Layout

`Views/Shared/_Layout.cshtml` — içeriğini tamamen sil, şunu yaz:

```html
@{
    var aktifSayfa = ViewContext.RouteData.Values["controller"]?.ToString() ?? "";
}

<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewData["Title"] - GörevTakip</title>

    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css" rel="stylesheet">

    <style>
        .sidebar {
            min-height: 100vh;
            background-color: #0f172a;
        }
        .sidebar a {
            color: #cbd5e1;
            text-decoration: none;
            padding: 12px 20px;
            display: block;
            border-left: 3px solid transparent;
        }
        .sidebar a:hover {
            background-color: #1e293b;
            color: #ffffff;
        }
        .sidebar a.active {
            background-color: #1e293b;
            color: #ffffff;
            border-left: 3px solid #22c55e;
        }
        .sidebar-baslik {
            color: #ffffff;
            padding: 20px;
            font-weight: bold;
            border-bottom: 1px solid #1e293b;
        }
    </style>
</head>
<body class="bg-light">

    <div class="container-fluid">
        <div class="row">

            <!-- ═══════ SOL MENÜ ═══════ -->
            <nav class="col-md-3 col-lg-2 sidebar p-0">

                <div class="sidebar-baslik">
                    <i class="bi bi-check2-square"></i> GörevTakip
                </div>

                <a asp-controller="Home" asp-action="Index"
                   class="@(aktifSayfa == "Home" ? "active" : "")">
                    <i class="bi bi-speedometer2"></i> Panel
                </a>

                <a asp-controller="Gorev" asp-action="Index"
                   class="@(aktifSayfa == "Gorev" ? "active" : "")">
                    <i class="bi bi-list-task"></i> Görevler
                </a>

                <a asp-controller="Kategori" asp-action="Index"
                   class="@(aktifSayfa == "Kategori" ? "active" : "")">
                    <i class="bi bi-tags"></i> Kategoriler
                </a>

            </nav>

            <!-- ═══════ İÇERİK ═══════ -->
            <main class="col-md-9 col-lg-10 px-4 py-3">

                <div class="d-flex justify-content-between align-items-center
                            border-bottom pb-2 mb-4">

                    <h4 class="mb-0">@ViewData["Title"]</h4>

                    <div class="d-flex align-items-center gap-3">
                        <span class="text-muted small d-none d-md-inline">
                            <i class="bi bi-calendar3"></i>
                            @DateTime.Now.ToString("dd MMMM yyyy")
                        </span>

                        @* Kullanıcı menüsü Modül 2'de buraya eklenecek *@
                    </div>
                </div>

                @RenderBody()

                <footer class="mt-5 pt-3 border-top text-muted small text-center">
                    &copy; @DateTime.Now.Year — GörevTakip
                </footer>

            </main>

        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    @await RenderSectionAsync("Scripts", required: false)

</body>
</html>
```

> Okul projesinin layout'uyla neredeyse aynı. Farklar: renkler, menü başlıkları, üç menü öğesi. Öğrenci burada hiç zorlanmamalı — zorlanıyorsa ilk projeye dönüp bakmalı.

---

## ⌨️ Adım 4: Geçici ana sayfa

`Views/Home/Index.cshtml` — Modül 6'da gerçek dashboard'ı yazacağız, şimdilik boş:

```html
@{
    ViewData["Title"] = "Panel";
}

<div class="alert alert-info">
    <i class="bi bi-info-circle"></i>
    Dashboard Modül 6'da yazılacak.
</div>
```

---

## ▶️ Çalıştır ve gör

Uygulamayı başlat. Sol menü görünüyor, tıklanan menü vurgulanıyor. Görevler ve Kategoriler linkleri **henüz hata verecek** — o controller'lar yok. Normal.

---

## ⚠️ Sık yapılan hatalar

| Hata | Çözüm |
|---|---|
| Sayfa stilsiz | Bootstrap CDN yüklenmedi, interneti kontrol et |
| Menü linkleri çalışmıyor | `_ViewImports.cshtml`'de `@addTagHelper` satırı var mı? |
| `Value cannot be null (connectionString)` | `appsettings.json`'daki anahtar adı `GorevDb` mi? |
| İkonlar kare görünüyor | Bootstrap Icons CSS linki eksik |

---

## ✏️ Öğrenci alıştırması

1. Projeyi kur, layout'u yaz, çalıştır.
2. Sol menü rengini kendi seçtiğin renge çevir.
3. **Süre tut:** Bu modül sana kaç dakika sürdü? İlk projede aynı işi kaç derste yapmıştık? Farkı not et.

---

👉 Sonraki: [`03-login.md`](03-login.md)
