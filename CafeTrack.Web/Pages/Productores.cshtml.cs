using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages;

/// <summary>
/// Listado de productores con busqueda por nombre o comunidad.
/// Nunca se consulta ni se muestra documento_identidad.
/// </summary>
public class ProductoresModel : PageModel
{
    private readonly IProductorRepository _repositorio;

    public ProductoresModel(IProductorRepository repositorio) => _repositorio = repositorio;

    [BindProperty(SupportsGet = true, Name = "q")]
    public string? Busqueda { get; set; }

    public IReadOnlyList<ProductorFila> Productores { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct)
    {
        Productores = await _repositorio.ListarAsync(Busqueda, ct);
    }
}
