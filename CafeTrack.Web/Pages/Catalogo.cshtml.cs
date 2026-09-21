using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages;

/// <summary>
/// Catalogo del cafe: variedades cultivadas, flujo del proceso, etapas del
/// beneficiado y certificaciones. Pantalla de consulta, sin escritura.
/// </summary>
public class CatalogoModel : PageModel
{
    private readonly ICatalogoRepository _repositorio;

    public CatalogoModel(ICatalogoRepository repositorio) => _repositorio = repositorio;

    public CatalogoViewModel Catalogo { get; private set; } = new();

    public async Task OnGetAsync(CancellationToken ct)
    {
        Catalogo = await _repositorio.ObtenerCatalogoAsync(ct);
    }
}
