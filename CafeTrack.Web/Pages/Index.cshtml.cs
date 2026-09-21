using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages;

/// <summary>Panel de inicio: cifras generales de la cooperativa.</summary>
public class IndexModel : PageModel
{
    private readonly IPanelRepository _repositorio;

    public IndexModel(IPanelRepository repositorio) => _repositorio = repositorio;

    public PanelViewModel Panel { get; private set; } = new();

    public async Task OnGetAsync(CancellationToken ct)
    {
        Panel = await _repositorio.ObtenerPanelAsync(ct);
    }
}
