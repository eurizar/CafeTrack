namespace CafeTrack.Web.Models.ViewModels;

/// <summary>Conteo de lotes agrupados por estado, para las tarjetas del panel.</summary>
public class ConteoEstadoLote
{
    public string EstadoLote { get; set; } = string.Empty;
    public int Cantidad { get; set; }
    public decimal Quintales { get; set; }
}

/// <summary>
/// Ocupacion de una bodega: existencia calculada desde MovimientosBodega
/// frente a la capacidad declarada en la tabla Bodegas.
/// </summary>
public class OcupacionBodega
{
    public int IdBodega { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Ubicacion { get; set; }
    public string? Responsable { get; set; }
    public decimal? CapacidadQuintales { get; set; }
    public decimal ExistenciaQuintales { get; set; }

    /// <summary>Porcentaje de ocupacion; null si la bodega no tiene capacidad registrada.</summary>
    public decimal? PorcentajeOcupacion =>
        CapacidadQuintales is > 0
            ? Math.Round(ExistenciaQuintales / CapacidadQuintales.Value * 100m, 1)
            : null;

    /// <summary>Porcentaje recortado a 100 para dibujar la barra sin desbordarla.</summary>
    public decimal PorcentajeBarra =>
        PorcentajeOcupacion is null ? 0m : Math.Min(PorcentajeOcupacion.Value, 100m);
}

/// <summary>Datos que alimentan el panel de inicio.</summary>
public class PanelViewModel
{
    public int ProductoresActivos { get; set; }
    public int ParcelasActivas { get; set; }
    public int TotalLotes { get; set; }
    public decimal QuintalesEnBodega { get; set; }
    public decimal ValorVentasTemporada { get; set; }
    public string? TemporadaEnCurso { get; set; }
    public decimal? PrecioBaseQuintal { get; set; }
    public IReadOnlyList<ConteoEstadoLote> LotesPorEstado { get; set; } = [];
    public IReadOnlyList<OcupacionBodega> Bodegas { get; set; } = [];
}
