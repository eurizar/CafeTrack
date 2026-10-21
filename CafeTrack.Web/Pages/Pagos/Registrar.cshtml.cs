using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Pagos;

/// <summary>
/// Pago al productor por una venta. El monto lo calcula la base con el
/// peso vendido; aqui solo se indica el precio acordado y las deducciones.
/// </summary>
public class RegistrarModel : PageModel
{
    private readonly IOperacionesRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public RegistrarModel(IOperacionesRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    /// <summary>ENUM metodo_pago, tal como esta en la base.</summary>
    public static readonly string[] Metodos = ["Transferencia", "Cheque", "Efectivo"];

    [BindProperty]
    public PagoForm Datos { get; set; } = new();

    public IReadOnlyList<VentaSinPago> Ventas { get; private set; } = [];

    /// <summary>Lo que pagaron los compradores por las ventas sin liquidar.</summary>
    public decimal TotalPendiente => Ventas.Sum(v => v.TotalVenta);

    /// <summary>Dias que lleva esperando la venta sin pagar mas antigua.</summary>
    public int DiasEsperando => Ventas.Count == 0
        ? 0
        : (int)Math.Round((DateTime.Now - Ventas.Min(v => v.FechaVenta)).TotalDays);

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }
    [TempData] public string? ExitoDetalle { get; set; }

    /// <param name="venta">
    /// Id que manda la lista de pendientes al tocar "Pagar"; deja la venta
    /// ya elegida. Sin el, el formulario arranca vacio.
    /// </param>
    public async Task OnGetAsync(int? venta, CancellationToken ct)
    {
        await CargarAsync(ct);

        if (venta is > 0 && Ventas.Any(v => v.IdVenta == venta))
        {
            Datos.IdVenta = venta;
        }
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            await CargarAsync(ct);
            return Page();
        }

        await CargarAsync(ct);
        var elegida = Ventas.FirstOrDefault(v => v.IdVenta == Datos.IdVenta);

        try
        {
            await _repositorio.RegistrarPagoAsync(Datos, _usuario.Nombre, ct);

            var monto = (elegida?.PesoVendido ?? 0) * (Datos.Precio ?? 0);
            var deducciones = Datos.Deducciones ?? 0;

            Exito = $"Se le pagaron {Formato.Moneda(monto - deducciones)} a " +
                    $"{elegida?.Productor ?? "el productor"} por el lote " +
                    $"{elegida?.CodigoLote ?? ""}.";

            ExitoDetalle = deducciones > 0
                ? $"Del total de {Formato.Moneda(monto)} se descontaron " +
                  $"{Formato.Moneda(deducciones)} de deducciones. La venta queda saldada."
                : "Sin deducciones. La venta queda saldada.";

            return RedirectToPage();
        }
        catch (MySqlException ex)
        {
            ErrorBase = ErroresMySql.Traducir(ex);
            await CargarAsync(ct);
            return Page();
        }
    }

    private async Task CargarAsync(CancellationToken ct)
    {
        Ventas = await _repositorio.ListarVentasSinPagoAsync(ct);
    }
}
