using System.Globalization;
using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Localization;

var builder = WebApplication.CreateBuilder(args);

// Formato guatemalteco en toda la aplicacion: fechas dd/MM/yyyy y moneda Q.
CultureInfo.DefaultThreadCurrentCulture = Formato.CulturaGt;
CultureInfo.DefaultThreadCurrentUICulture = Formato.CulturaGt;

// Mapeo id_productor -> IdProductor y manejadores de DateOnly.
DapperConfiguracion.Aplicar();

// --- Seguridad (Fase 3) -------------------------------------------------
// La identidad viaja en una cookie firmada; las credenciales las valida
// sp_login dentro de MySQL y el rol decide con que usuario de la base se
// abre cada conexion.
builder.Services.AddHttpContextAccessor();

builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(opciones =>
    {
        opciones.Cookie.Name = "CafeTrack.Sesion";
        opciones.Cookie.HttpOnly = true;
        opciones.Cookie.SameSite = SameSiteMode.Lax;
        opciones.LoginPath = "/Cuenta/Ingresar";
        opciones.LogoutPath = "/Cuenta/Salir";
        opciones.AccessDeniedPath = "/Cuenta/SinPermiso";
        opciones.ExpireTimeSpan = TimeSpan.FromHours(8);
        opciones.SlidingExpiration = true;
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("RegistraAcopios", p => p.RequireRole("admin", "acopiador"))
    .AddPolicy("RegistraVentas", p => p.RequireRole("admin", "gerente"))
    .AddPolicy("VeBitacora", p => p.RequireRole("admin", "auditor"));

builder.Services.AddRazorPages(opciones =>
{
    // Todo el sitio pide sesion, salvo el ingreso y las paginas de aviso.
    opciones.Conventions.AuthorizeFolder("/");
    opciones.Conventions.AllowAnonymousToFolder("/Cuenta");
    opciones.Conventions.AllowAnonymousToPage("/Error");

    opciones.Conventions.AuthorizeFolder("/Acopios", "RegistraAcopios");
    opciones.Conventions.AuthorizeFolder("/Ventas", "RegistraVentas");
    opciones.Conventions.AuthorizePage("/Bitacora", "VeBitacora");
});

// --- Acceso a datos -----------------------------------------------------
builder.Services.AddScoped<IUsuarioActual, UsuarioDeSesion>();
builder.Services.AddScoped<IDbConnectionFactory, MySqlConnectionFactory>();
builder.Services.AddScoped<IPanelRepository, PanelRepository>();
builder.Services.AddScoped<ICatalogoRepository, CatalogoRepository>();
builder.Services.AddScoped<IProductorRepository, ProductorRepository>();
builder.Services.AddScoped<IParcelaRepository, ParcelaRepository>();
builder.Services.AddScoped<ILoteRepository, LoteRepository>();
builder.Services.AddScoped<IExistenciaRepository, ExistenciaRepository>();
builder.Services.AddScoped<IOperacionesRepository, OperacionesRepository>();
builder.Services.AddScoped<ISeguridadRepository, SeguridadRepository>();

var app = builder.Build();

// Si la base no responde, se muestra la pagina de error amable, no la excepcion cruda.
app.UseExceptionHandler("/Error");
app.UseStatusCodePagesWithReExecute("/Error", "?codigo={0}");
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new RequestCulture(Formato.CulturaGt),
    SupportedCultures = [Formato.CulturaGt],
    SupportedUICultures = [Formato.CulturaGt]
});

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
