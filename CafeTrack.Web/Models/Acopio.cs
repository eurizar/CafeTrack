namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Acopios</c>: recepcion del lote en el centro de acopio.</summary>
public class Acopio
{
    public int IdAcopio { get; set; }
    public int IdLote { get; set; }
    public DateTime FechaRecepcion { get; set; }
    public decimal PesoRecibidoQuintales { get; set; }
    public string ResponsableRecepcion { get; set; } = string.Empty;
    /// <summary>ENUM: 'Buena' | 'Regular' | 'Mala'.</summary>
    public string CondicionTransporte { get; set; } = "Buena";
    public string? Observaciones { get; set; }
}
