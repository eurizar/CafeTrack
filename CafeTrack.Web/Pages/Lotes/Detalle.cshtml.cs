using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Lotes;

/// <summary>Trazabilidad de un lote: cosecha, acopio, beneficiado, calidad, bodega, venta y pago.</summary>
public class DetalleModel : PageModel
{
    private readonly ILoteRepository _repositorio;

    public DetalleModel(ILoteRepository repositorio) => _repositorio = repositorio;

    public string Codigo { get; private set; } = string.Empty;
    public LoteDetalleViewModel Detalle { get; private set; } = new();

    public async Task<IActionResult> OnGetAsync(string codigo, CancellationToken ct)
    {
        Codigo = codigo;

        var detalle = await _repositorio.ObtenerDetalleAsync(codigo, ct);
        if (detalle is null)
        {
            // Codigo inexistente: se responde con la pagina de error amable, no con una excepcion.
            return NotFound();
        }

        Detalle = detalle;
        return Page();
    }
}
