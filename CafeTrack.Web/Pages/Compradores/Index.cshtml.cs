using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Compradores;

/// <summary>
/// Compradores de la cooperativa: la lista de quienes compran y el alta de
/// uno nuevo. El alta pasa por sp_crear_comprador, que rechaza nombres
/// repetidos y tipos que no esten en el ENUM.
/// </summary>
public class IndexModel : PageModel
{
    private readonly IOperacionesRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public IndexModel(IOperacionesRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    /// <summary>ENUM tipo, tal como esta en la base.</summary>
    public static readonly string[] Tipos =
        ["Exportador", "Tostador", "Intermediario", "Cooperativa"];

    [BindProperty]
    public CompradorForm Datos { get; set; } = new();

    public IReadOnlyList<CompradorResumen> Compradores { get; private set; } = [];

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }
    [TempData] public string? ExitoDetalle { get; set; }

    /// <summary>Cuanto se le ha comprado a todos, para el pie de la tabla.</summary>
    public decimal TotalComprado => Compradores.Sum(c => c.TotalComprado);

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
            await _repositorio.CrearCompradorAsync(Datos, _usuario.Nombre, ct);

            Exito = $"{Datos.Nombre} ya está en la lista de compradores.";
            ExitoDetalle = "Desde ahora aparece al registrar una venta.";

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
        Compradores = await _repositorio.ListarCompradoresResumenAsync(ct);
    }
}
