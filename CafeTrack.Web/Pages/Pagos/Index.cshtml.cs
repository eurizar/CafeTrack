using CafeTrack.Web.Data;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Pagos;

/// <summary>
/// Estado de los pagos al productor: que ventas estan esperando pago y
/// cuales ya se pagaron. Ambas listas salen de consultas, no de un estado
/// guardado: una venta esta pendiente si no tiene fila en Pagos.
/// </summary>
public class IndexModel : PageModel
{
    private readonly IOperacionesRepository _repositorio;

    public IndexModel(IOperacionesRepository repositorio) => _repositorio = repositorio;

    public IReadOnlyList<VentaSinPago> Pendientes { get; private set; } = [];
    public IReadOnlyList<PagoHecho> Pagados { get; private set; } = [];

    /// <summary>Lo que la cooperativa debe hoy, al precio de venta.</summary>
    public decimal TotalPendiente => Pendientes.Sum(v => v.TotalVenta);

    public decimal TotalPagado => Pagados.Sum(p => p.MontoNeto);

    public decimal TotalDeducciones => Pagados.Sum(p => p.Deducciones);

    public decimal TotalMonto => Pagados.Sum(p => p.MontoPagado);

    public async Task OnGetAsync(CancellationToken ct)
    {
        Pendientes = await _repositorio.ListarVentasSinPagoAsync(ct);
        Pagados = await _repositorio.ListarPagosAsync(ct);
    }
}
