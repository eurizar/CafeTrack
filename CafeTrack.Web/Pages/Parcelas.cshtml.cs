using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages;

/// <summary>Listado de parcelas con su productor, variedad, altitud y certificacion.</summary>
public class ParcelasModel : PageModel
{
    private readonly IParcelaRepository _repositorio;

    public ParcelasModel(IParcelaRepository repositorio) => _repositorio = repositorio;

    [BindProperty(SupportsGet = true, Name = "q")]
    public string? Busqueda { get; set; }

    [BindProperty(SupportsGet = true, Name = "cert")]
    public string? Certificacion { get; set; }

    public IReadOnlyList<ParcelaFila> Parcelas { get; private set; } = [];
    public IReadOnlyList<string> Certificaciones { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken ct)
    {
        Certificaciones = await _repositorio.ListarCertificacionesAsync(ct);
        Parcelas = await _repositorio.ListarAsync(Busqueda, Certificacion, ct);
    }
}
