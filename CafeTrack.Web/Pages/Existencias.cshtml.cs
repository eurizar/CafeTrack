using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages;

/// <summary>Kardex resumido por bodega y lote; la existencia se calcula, no se almacena.</summary>
public class ExistenciasModel : PageModel
{
    private readonly IExistenciaRepository _repositorio;

    public ExistenciasModel(IExistenciaRepository repositorio) => _repositorio = repositorio;

    [BindProperty(SupportsGet = true, Name = "bodega")]
    public int? IdBodega { get; set; }

    public IReadOnlyList<ExistenciaFila> Filas { get; private set; } = [];
    public IReadOnlyList<OcupacionBodega> Bodegas { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct)
    {
        Bodegas = await _repositorio.ListarBodegasAsync(ct);
        Filas = await _repositorio.ListarAsync(IdBodega, ct);
    }
}
