namespace CafeTrack.Web.Models;

/// <summary>
/// Tabla <c>MovimientosBodega</c>. La existencia en bodega no se almacena: se calcula
/// sumando los movimientos de tipo 'Entrada' y restando todos los demas tipos.
/// </summary>
public class MovimientoBodega
{
    public int IdMovimiento { get; set; }
    public int IdBodega { get; set; }
    public int IdLote { get; set; }
    /// <summary>ENUM: 'Entrada' | 'Salida por venta' | 'Salida por merma' | 'Ajuste'.</summary>
    public string TipoMovimiento { get; set; } = string.Empty;
    public DateTime FechaMovimiento { get; set; }
    public decimal CantidadQuintales { get; set; }
    public int? IdVenta { get; set; }
    public string Responsable { get; set; } = string.Empty;
    public string UsuarioRegistro { get; set; } = string.Empty;
    public string? Observaciones { get; set; }
}
