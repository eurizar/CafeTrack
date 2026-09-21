using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Lotes;

/// <summary>Listado de lotes con filtros por estado y temporada.</summary>
public class IndexModel : PageModel
{
    private readonly ILoteRepository _repositorio;

    public IndexModel(ILoteRepository repositorio) => _repositorio = repositorio;

    [BindProperty(SupportsGet = true, Name = "estado")]
    public string? Estado { get; set; }

    [BindProperty(SupportsGet = true, Name = "anio")]
    public int? Anio { get; set; }

    [BindProperty(SupportsGet = true, Name = "q")]
    public string? Busqueda { get; set; }

    public IReadOnlyList<LoteFila> Lotes { get; private set; } = [];
    public IReadOnlyList<int> Anios { get; private set; } = [];
    public IReadOnlyList<string> Estados => LoteRepository.EstadosLote;

    public bool HayFiltros =>
        !string.IsNullOrWhiteSpace(Estado) || Anio is not null || !string.IsNullOrWhiteSpace(Busqueda);

    public async Task OnGetAsync(CancellationToken ct)
    {
        Anios = await _repositorio.ListarAniosTemporadaAsync(ct);
        Lotes = await _repositorio.ListarAsync(Estado, Anio, Busqueda, ct);
    }
}
