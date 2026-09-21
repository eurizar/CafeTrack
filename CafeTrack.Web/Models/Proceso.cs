namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Procesos</c>: paso del lote por una etapa del beneficiado.</summary>
public class Proceso
{
    public int IdProceso { get; set; }
    public int IdLote { get; set; }
    public int IdEtapa { get; set; }
    public DateTime FechaInicio { get; set; }
    public DateTime? FechaFin { get; set; }
    public decimal PesoEntradaQuintales { get; set; }
    public decimal? PesoSalidaQuintales { get; set; }
    public string Responsable { get; set; } = string.Empty;
}
