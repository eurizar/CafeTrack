using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Reportes;

/// <summary>
/// Muestra un reporte. La URL trae solo la clave; el nombre de la vista sale
/// del catalogo interno, nunca del texto que escribe el usuario.
/// </summary>
public class VerModel : PageModel
{
    private readonly IReporteRepository _repositorio;

    public VerModel(IReporteRepository repositorio) => _repositorio = repositorio;

    public Reporte? Reporte { get; private set; }
    public ResultadoReporte Datos { get; private set; } = new();

    public IReadOnlyList<Reporte> Otros =>
        CatalogoReportes.Todos.Where(r => r.Clave != Reporte?.Clave).ToList();

    public async Task<IActionResult> OnGetAsync(string clave, CancellationToken ct)
    {
        Reporte = CatalogoReportes.Buscar(clave);
        if (Reporte is null)
        {
            return NotFound();
        }

        Datos = await _repositorio.EjecutarAsync(Reporte, ct);
        return Page();
    }
}
