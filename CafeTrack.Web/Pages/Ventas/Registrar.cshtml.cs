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

    [TempData]
    public string? Exito { get; set; }

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

        try
        {
            var idVenta = await _repositorio.RegistrarVentaAsync(Datos, _usuario.Nombre, ct);
            Exito = $"Venta {idVenta} registrada. Se generó la salida de bodega y el lote " +
                    "quedó actualizado.";
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
