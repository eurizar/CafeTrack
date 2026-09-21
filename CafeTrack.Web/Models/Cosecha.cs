namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Cosechas</c>. <c>peso_bruto_kg</c> es GENERATED: solo lectura.</summary>
public class Cosecha
{
    public int IdCosecha { get; set; }
    public int IdParcela { get; set; }
    public int IdTemporada { get; set; }
    public DateOnly FechaRecoleccion { get; set; }
    public decimal PesoBrutoQuintales { get; set; }
    /// <summary>Columna GENERATED (quintales * 45.36). Nunca se incluye en INSERT ni UPDATE.</summary>
    public decimal PesoBrutoKg { get; set; }
    public decimal? HumedadPorcentaje { get; set; }
    public string? Recolector { get; set; }
    public string? Observaciones { get; set; }
}
