using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Bodegas;

/// <summary>
/// Traslado de cafe entre bodegas. No existe un tipo de movimiento
/// "traslado": sp_trasladar_lote escribe un Ajuste en la bodega de origen
/// y una Entrada en la de destino, en una sola transaccion. Si algo falla,
/// no queda ninguno de los dos.
/// </summary>
public class TrasladarModel : PageModel
{
    private readonly IOperacionesRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public TrasladarModel(IOperacionesRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    [BindProperty]
    public TrasladoForm Datos { get; set; } = new();

    /// <summary>Lo que hay de cada lote en cada bodega; de ahi salen los dos selectores.</summary>
    public IReadOnlyList<ExistenciaEnBodega> Existencias { get; private set; } = [];

    public IReadOnlyList<BodegaConEspacio> Bodegas { get; private set; } = [];

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }
    [TempData] public string? ExitoDetalle { get; set; }

    /// <summary>Lotes distintos que hoy tienen cafe guardado en alguna bodega.</summary>
    public IEnumerable<IGrouping<int, ExistenciaEnBodega>> PorLote =>
        Existencias.GroupBy(e => e.IdLote);

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

        var origen = Bodegas.FirstOrDefault(b => b.IdBodega == Datos.Origen)?.Nombre ?? "la bodega";
        var destino = Bodegas.FirstOrDefault(b => b.IdBodega == Datos.Destino)?.Nombre ?? "la otra";
        var lote = Existencias.FirstOrDefault(e => e.IdLote == Datos.IdLote);

        try
        {
            await _repositorio.TrasladarLoteAsync(Datos, _usuario.Nombre, ct);

            Exito = $"Se trasladaron {Formato.Quintales(Datos.Cantidad)} quintales de " +
                    $"{origen} a {destino}.";
            ExitoDetalle = "Quedaron dos movimientos: la salida de la bodega de origen y " +
                           "la entrada en la de destino. Las existencias ya están al día.";

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
        Existencias = await _repositorio.ListarExistenciasPorBodegaAsync(ct);
        Bodegas = await _repositorio.ListarBodegasConEspacioAsync(ct);
    }
}
