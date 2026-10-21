using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Bodegas;

/// <summary>
/// Ingreso de un lote a bodega. Solo entran los aprobados en catacion y
/// solo si la bodega tiene capacidad: las dos cosas las revisa la base.
/// </summary>
public class IngresarModel : PageModel
{
    private readonly IOperacionesRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public IngresarModel(IOperacionesRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    [BindProperty]
    public IngresoBodegaForm Datos { get; set; } = new();

    public IReadOnlyList<LoteParaBodega> Lotes { get; private set; } = [];
    public IReadOnlyList<Models.Bodega> Bodegas { get; private set; } = [];

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }
    [TempData] public string? ExitoDetalle { get; set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        // Vacio: la cantidad se propone al elegir el lote.
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
        var bodega = Bodegas.FirstOrDefault(b => b.IdBodega == Datos.IdBodega);

        try
        {
            await _repositorio.RegistrarIngresoBodegaAsync(Datos, _usuario.Nombre, ct);

            var lote = elegido?.CodigoLote ?? "seleccionado";
            var cantidad = Formato.Quintales(Datos.Cantidad);

            Exito = $"Entraron {cantidad} quintales del lote {lote} a " +
                    $"{bodega?.Nombre ?? "la bodega"}.";
            ExitoDetalle = "El lote aparece ahora como \"En bodega\" y su café ya cuenta " +
                           "en las existencias. El gerente puede venderlo.";

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
        Lotes = await _repositorio.ListarLotesParaBodegaAsync(ct);
        Bodegas = await _repositorio.ListarBodegasAsync(ct);
    }
}
