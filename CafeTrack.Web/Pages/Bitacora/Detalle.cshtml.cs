using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Bitacora;

/// <summary>
/// Desglose de un registro de la bitacora: el antes y el despues completos,
/// con el JSON crudo a la vista de quien lo quiera revisar.
/// </summary>
public class DetalleModel : PageModel
{
    private readonly ISeguridadRepository _repositorio;

    public DetalleModel(ISeguridadRepository repositorio) => _repositorio = repositorio;

    public BitacoraFila Registro { get; private set; } = new();

    /// <summary>Codigo de lote mencionado en el JSON, si lo hay: permite ir al lote.</summary>
    public string? CodigoLote { get; private set; }

    public async Task<IActionResult> OnGetAsync(int id, CancellationToken ct)
    {
        var registro = await _repositorio.ObtenerBitacoraAsync(id, ct);
        if (registro is null)
        {
            return NotFound();
        }

        Registro = registro;
        CodigoLote = BuscarCodigoLote(registro.DatosNuevos) ?? BuscarCodigoLote(registro.DatosAnteriores);
        return Page();
    }

    /// <summary>Lee la propiedad codigo_lote del JSON, si viene.</summary>
    private static string? BuscarCodigoLote(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return null;
        }

        try
        {
            using var documento = System.Text.Json.JsonDocument.Parse(json);
            return documento.RootElement.ValueKind == System.Text.Json.JsonValueKind.Object &&
                   documento.RootElement.TryGetProperty("codigo_lote", out var valor)
                ? valor.GetString()
                : null;
        }
        catch (System.Text.Json.JsonException)
        {
            return null;
        }
    }
}
