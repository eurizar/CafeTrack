namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Temporadas</c>: ciclo anual de cosecha.</summary>
public class Temporada
{
    public int IdTemporada { get; set; }
    public int Anio { get; set; }
    public DateOnly FechaInicio { get; set; }
    public DateOnly? FechaCierre { get; set; }
    /// <summary>ENUM: 'Planificada' | 'En curso' | 'Cerrada'.</summary>
    public string Estado { get; set; } = string.Empty;
    public decimal? PrecioBaseQuintal { get; set; }
}
