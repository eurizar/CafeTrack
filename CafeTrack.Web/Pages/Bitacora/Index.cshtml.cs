using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Bitacora;

/// <summary>
/// Bitacora de auditoria: lo que escriben los triggers y los procedimientos.
/// Solo la ven los roles admin y auditor.
/// </summary>
public class IndexModel : PageModel
{
    private readonly ISeguridadRepository _repositorio;

    public IndexModel(ISeguridadRepository repositorio) => _repositorio = repositorio;

    [BindProperty(SupportsGet = true, Name = "op")]
    public string? Operacion { get; set; }

    [BindProperty(SupportsGet = true, Name = "tabla")]
    public string? Tabla { get; set; }

    [BindProperty(SupportsGet = true, Name = "q")]
    public string? Usuario { get; set; }

    [BindProperty(SupportsGet = true, Name = "limite")]
    public int Limite { get; set; } = 100;

    public IReadOnlyList<BitacoraFila> Filas { get; private set; } = [];
    public IReadOnlyList<string> Tablas { get; private set; } = [];
    public IReadOnlyList<string> Operaciones { get; private set; } = [];

    public bool HayFiltros =>
        !string.IsNullOrWhiteSpace(Operacion) ||
        !string.IsNullOrWhiteSpace(Tabla) ||
        !string.IsNullOrWhiteSpace(Usuario);

    public int Alertas => Filas.Count(f => f.EsAlerta);

    public async Task OnGetAsync(CancellationToken ct)
    {
        (Tablas, Operaciones) = await _repositorio.ListarFiltrosBitacoraAsync(ct);
        Filas = await _repositorio.ListarBitacoraAsync(Operacion, Tabla, Usuario, Limite, ct);
    }
}
