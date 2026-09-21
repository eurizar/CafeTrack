namespace CafeTrack.Web.Models.ViewModels;

/// <summary>
/// Fila del listado de productores. No incluye documento_identidad:
/// esa columna no se consulta en ninguna pantalla.
/// </summary>
public class ProductorFila
{
    public int IdProductor { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Telefono { get; set; }
    public string? Comunidad { get; set; }
    public DateOnly FechaIngresoCoop { get; set; }
    public bool Activo { get; set; }
    public int TotalParcelas { get; set; }
    public int TotalLotes { get; set; }
    public decimal AreaTotalManzanas { get; set; }
}

/// <summary>Fila del listado de parcelas, con productor y variedad resueltos.</summary>
public class ParcelaFila
{
    public int IdParcela { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Productor { get; set; } = string.Empty;
    public string? Comunidad { get; set; }
    public string Variedad { get; set; } = string.Empty;
    public string? Ubicacion { get; set; }
    public decimal? AreaManzanas { get; set; }
    public int? AltitudMetros { get; set; }
    public string Certificacion { get; set; } = "Ninguna";
    public bool Activa { get; set; }
}

/// <summary>Fila del listado de lotes, con productor, variedad y temporada resueltos.</summary>
public class LoteFila
{
    public int IdLote { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public string Productor { get; set; } = string.Empty;
    public string? Comunidad { get; set; }
    public string Variedad { get; set; } = string.Empty;
    public int Anio { get; set; }
    public DateOnly FechaRecoleccion { get; set; }
    public decimal PesoInicialQuintales { get; set; }
    public decimal PesoActualQuintales { get; set; }
    public string EstadoLote { get; set; } = string.Empty;
    public string CertificacionAplicable { get; set; } = "Ninguna";

    /// <summary>Diferencia entre el peso inicial y el actual, en quintales.</summary>
    public decimal MermaAcumulada => PesoInicialQuintales - PesoActualQuintales;

    /// <summary>Merma acumulada expresada como porcentaje del peso inicial.</summary>
    public decimal MermaPorcentaje =>
        PesoInicialQuintales > 0
            ? Math.Round(MermaAcumulada / PesoInicialQuintales * 100m, 2)
            : 0m;
}

/// <summary>
/// Fila del kardex resumido: entradas, salidas y existencia de un lote en una bodega.
/// La existencia se calcula, nunca se lee de una columna.
/// </summary>
public class ExistenciaFila
{
    public int IdBodega { get; set; }
    public string Bodega { get; set; } = string.Empty;
    public int IdLote { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public string Productor { get; set; } = string.Empty;
    public string EstadoLote { get; set; } = string.Empty;
    public decimal Entradas { get; set; }
    public decimal Salidas { get; set; }
    public decimal Existencia { get; set; }
    public DateTime? UltimoMovimiento { get; set; }
}
