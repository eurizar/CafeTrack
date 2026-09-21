namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Mermas</c>: perdida de peso registrada en alguna etapa.</summary>
public class Merma
{
    public int IdMerma { get; set; }
    public int IdLote { get; set; }
    /// <summary>ENUM: 'Natural' | 'Transporte' | 'Proceso' | 'Almacenamiento' | 'Otra'.</summary>
    public string TipoMerma { get; set; } = string.Empty;
    /// <summary>ENUM: 'Cosecha' | 'Acopio' | 'Proceso' | 'Bodega'.</summary>
    public string EtapaOrigen { get; set; } = string.Empty;
    public decimal PesoPerdidoQuintales { get; set; }
    public decimal? PorcentajeMerma { get; set; }
    public DateTime FechaRegistro { get; set; }
    public string Responsable { get; set; } = string.Empty;
    public string? Justificacion { get; set; }
}
