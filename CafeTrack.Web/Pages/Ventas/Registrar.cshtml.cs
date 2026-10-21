using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Ventas;

/// <summary>
/// Formulario de venta. Llama a sp_registrar_venta, que comprueba la existencia
/// con fn_existencia_lote, exige catacion aprobada y genera la salida de bodega.
/// </summary>
public class RegistrarModel : PageModel
{
    private readonly IOperacionesRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public RegistrarModel(IOperacionesRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    [BindProperty]
    public VentaForm Datos { get; set; } = new();

    public IReadOnlyList<LoteOpcion> Lotes { get; private set; } = [];
    public IReadOnlyList<Comprador> Compradores { get; private set; } = [];
    public IReadOnlyList<Bodega> Bodegas { get; private set; } = [];

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }
    [TempData] public string? ExitoDetalle { get; set; }

    /// <summary>Valores del ENUM forma_pago, tal como estan en la base (sin tildes).</summary>
    public static readonly string[] FormasPago = ["Contado", "Credito 30 dias", "Credito 60 dias"];

    public async Task OnGetAsync(CancellationToken ct)
    {
        await CargarAsync(ct);
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            await CargarAsync(ct);
            return Page();
        }

        await CargarAsync(ct);
        var elegido = Lotes.FirstOrDefault(l => l.IdLote == Datos.IdLote);
        var comprador = Compradores.FirstOrDefault(c => c.IdComprador == Datos.IdComprador);

        try
        {
            var idVenta = await _repositorio.RegistrarVentaAsync(Datos, _usuario.Nombre, ct);

            var lote = elegido?.CodigoLote ?? "seleccionado";
            var peso = Datos.Peso ?? 0;
            var total = peso * (Datos.Precio ?? 0);

            Exito = $"Vendidos {Formato.Quintales(peso)} quintales del lote {lote} a " +
                    $"{comprador?.Nombre ?? "el comprador"} por {Formato.Moneda(total)}.";
            ExitoDetalle = $"Es la venta número {idVenta}. El café salió de la bodega solo, " +
                           "así que las existencias ya están al día. Falta registrarle el pago " +
                           "al productor.";

            return RedirectToPage();
        }
        catch (MySqlException ex)
        {
            ErrorBase = ErroresMySql.Traducir(ex);
            await CargarAsync(ct);
            return Page();
        }
    }

    private async Task CargarAsync(CancellationToken ct)
    {
        Lotes = await _repositorio.ListarLotesVendiblesAsync(ct);
        Compradores = await _repositorio.ListarCompradoresAsync(ct);
        Bodegas = await _repositorio.ListarBodegasAsync(ct);
    }
}
