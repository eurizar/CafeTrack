namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>EtapasProceso</c>: etapas del beneficiado humedo y seco.</summary>
public class EtapaProceso
{
    public int IdEtapa { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public int Orden { get; set; }
    public decimal? DuracionMinHoras { get; set; }
    public decimal? DuracionMaxHoras { get; set; }
    public string? Descripcion { get; set; }
}
