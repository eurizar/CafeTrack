namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>VentasLotes</c>. <c>total_venta</c> es GENERATED: solo lectura.</summary>
public class VentaLote
{
    public int IdVenta { get; set; }
    public int IdLote { get; set; }
    public int IdComprador { get; set; }
    public DateTime FechaVenta { get; set; }
    public decimal PesoVendidoQuintales { get; set; }
    public decimal PrecioQuintal { get; set; }
    /// <summary>Columna GENERATED (peso * precio). Nunca se incluye en INSERT ni UPDATE.</summary>
    public decimal TotalVenta { get; set; }
    /// <summary>ENUM: 'Contado' | 'Credito 30 dias' | 'Credito 60 dias'.</summary>
    public string FormaPago { get; set; } = "Contado";
    /// <summary>ENUM: 'Pendiente' | 'Parcial' | 'Pagado'.</summary>
    public string EstadoPago { get; set; } = "Pendiente";
    public string UsuarioRegistro { get; set; } = string.Empty;
}
