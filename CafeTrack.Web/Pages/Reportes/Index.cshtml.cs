using CafeTrack.Web.Helpers;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Reportes;

/// <summary>Catalogo de los 11 reportes.</summary>
public class IndexModel : PageModel
{
    public IReadOnlyList<Reporte> Reportes => CatalogoReportes.Todos;
}
