namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Parcelas</c>: terreno sembrado de un productor.</summary>
public class Parcela
{
    public int IdParcela { get; set; }
    public int IdProductor { get; set; }
    public int IdVariedad { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Ubicacion { get; set; }
    public decimal? AreaManzanas { get; set; }
    public int? AltitudMetros { get; set; }
    /// <summary>ENUM: 'Ninguna' | 'Organico' | 'Fair Trade' | 'Rainforest' | 'UTZ'.</summary>
    public string Certificacion { get; set; } = "Ninguna";
    public bool Activa { get; set; }
}
