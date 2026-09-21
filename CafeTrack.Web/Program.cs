using System.Globalization;
using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using Microsoft.AspNetCore.Localization;

var builder = WebApplication.CreateBuilder(args);

// Formato guatemalteco en toda la aplicacion: fechas dd/MM/yyyy y moneda Q.
CultureInfo.DefaultThreadCurrentCulture = Formato.CulturaGt;
CultureInfo.DefaultThreadCurrentUICulture = Formato.CulturaGt;

// Mapeo id_productor -> IdProductor y manejadores de DateOnly.
DapperConfiguracion.Aplicar();

builder.Services.AddRazorPages();

// Acceso a datos: una sola fabrica de conexiones, repositorios de solo lectura.
builder.Services.AddSingleton<IDbConnectionFactory, MySqlConnectionFactory>();
builder.Services.AddScoped<IPanelRepository, PanelRepository>();
builder.Services.AddScoped<IProductorRepository, ProductorRepository>();
builder.Services.AddScoped<IParcelaRepository, ParcelaRepository>();
builder.Services.AddScoped<ILoteRepository, LoteRepository>();
builder.Services.AddScoped<IExistenciaRepository, ExistenciaRepository>();

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
app.MapRazorPages();

app.Run();
