namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Lotes</c>: unidad de trazabilidad del sistema.</summary>
public class Lote
{
    public int IdLote { get; set; }
    public int IdCosecha { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public DateTime FechaCreacion { get; set; }
    public decimal PesoInicialQuintales { get; set; }
    public decimal PesoActualQuintales { get; set; }
    /// <summary>ENUM: 'En acopio' | 'En proceso' | 'En bodega' | 'Vendido' | 'Rechazado'.</summary>
    public string EstadoLote { get; set; } = "En acopio";
    /// <summary>ENUM: 'Ninguna' | 'Organico' | 'Fair Trade' | 'Rainforest' | 'UTZ'.</summary>
    public string CertificacionAplicable { get; set; } = "Ninguna";
}
