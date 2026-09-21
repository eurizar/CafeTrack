namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Calidad</c>: evaluacion sensorial del lote (catacion).</summary>
public class Calidad
{
    public int IdCalidad { get; set; }
    public int IdLote { get; set; }
    public DateTime FechaEvaluacion { get; set; }
    public string Evaluador { get; set; } = string.Empty;
    public decimal? PuntajeSca { get; set; }
    /// <summary>ENUM: 'Estrictamente Altura' | 'Altura' | 'Central' | 'Baja'.</summary>
    public string? AlturaTaza { get; set; }
    public string? DefectosPrincipales { get; set; }
    public string? PerfilSensorial { get; set; }
    public bool AprobadoVenta { get; set; }
}
