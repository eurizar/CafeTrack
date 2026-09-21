namespace CafeTrack.Web.Models.ViewModels;

/// <summary>Encabezado del lote: identidad, pesos y origen (parcela, productor, temporada).</summary>
public class LoteEncabezado
{
    public int IdLote { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public DateTime FechaCreacion { get; set; }
    public decimal PesoInicialQuintales { get; set; }
    public decimal PesoActualQuintales { get; set; }
    public string EstadoLote { get; set; } = string.Empty;
    public string CertificacionAplicable { get; set; } = "Ninguna";

    public int IdCosecha { get; set; }
    public DateOnly FechaRecoleccion { get; set; }
    public decimal PesoBrutoQuintales { get; set; }
    public decimal PesoBrutoKg { get; set; }
    public decimal? HumedadPorcentaje { get; set; }
    public string? Recolector { get; set; }
    public string? ObservacionesCosecha { get; set; }

    public string Parcela { get; set; } = string.Empty;
    public string? UbicacionParcela { get; set; }
    public int? AltitudMetros { get; set; }
    public string Variedad { get; set; } = string.Empty;
    public string CertificacionParcela { get; set; } = "Ninguna";

    public int IdProductor { get; set; }
    public string Productor { get; set; } = string.Empty;
    public string? Comunidad { get; set; }

    public int Anio { get; set; }
    public string EstadoTemporada { get; set; } = string.Empty;
    public decimal? PrecioBaseQuintal { get; set; }
}

/// <summary>
/// Una etapa del beneficiado en la linea de tiempo. Si <see cref="Ocurrio"/> es falso
/// la etapa todavia no se ha registrado y se dibuja atenuada.
/// </summary>
public class EtapaLinea
{
    public int IdEtapa { get; set; }
    public int Orden { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public decimal? DuracionMinHoras { get; set; }
    public decimal? DuracionMaxHoras { get; set; }

    public int? IdProceso { get; set; }
    public DateTime? FechaInicio { get; set; }
    public DateTime? FechaFin { get; set; }
    public decimal? PesoEntradaQuintales { get; set; }
    public decimal? PesoSalidaQuintales { get; set; }
    public string? Responsable { get; set; }

    public bool Ocurrio => IdProceso is not null;
    public bool EnCurso => IdProceso is not null && FechaFin is null;

    /// <summary>Horas transcurridas entre inicio y fin; null si la etapa sigue abierta.</summary>
    public decimal? HorasReales =>
        FechaInicio is not null && FechaFin is not null
            ? Math.Round((decimal)(FechaFin.Value - FechaInicio.Value).TotalHours, 1)
            : null;

    /// <summary>Peso perdido en la etapa, en quintales.</summary>
    public decimal? MermaEtapa =>
        PesoEntradaQuintales is not null && PesoSalidaQuintales is not null
            ? PesoEntradaQuintales - PesoSalidaQuintales
            : null;
}

/// <summary>Movimiento de bodega mostrado en la trazabilidad y en el kardex del lote.</summary>
public class MovimientoFila
{
    public int IdMovimiento { get; set; }
    public string Bodega { get; set; } = string.Empty;
    public string TipoMovimiento { get; set; } = string.Empty;
    public DateTime FechaMovimiento { get; set; }
    public decimal CantidadQuintales { get; set; }
    public string Responsable { get; set; } = string.Empty;
    public string? Observaciones { get; set; }

    /// <summary>Signo contable del movimiento: 'Entrada' suma, el resto resta.</summary>
    public bool EsEntrada => TipoMovimiento == "Entrada";
}

/// <summary>Venta del lote con el comprador resuelto.</summary>
public class VentaFila
{
    public int IdVenta { get; set; }
    public DateTime FechaVenta { get; set; }
    public string Comprador { get; set; } = string.Empty;
    public string TipoComprador { get; set; } = string.Empty;
    public string? PaisDestino { get; set; }
    public decimal PesoVendidoQuintales { get; set; }
    public decimal PrecioQuintal { get; set; }
    public decimal TotalVenta { get; set; }
    public string FormaPago { get; set; } = string.Empty;
    public string EstadoPago { get; set; } = string.Empty;
}

/// <summary>Pago liquidado al productor por una venta.</summary>
public class PagoFila
{
    public int IdPago { get; set; }
    public int IdVenta { get; set; }
    public DateTime FechaPago { get; set; }
    public string Productor { get; set; } = string.Empty;
    public decimal MontoPagado { get; set; }
    public decimal PrecioPagadoQuintal { get; set; }
    public decimal Deducciones { get; set; }
    public decimal MontoNeto { get; set; }
    public string MetodoPago { get; set; } = string.Empty;
    public string? Comprobante { get; set; }
}

/// <summary>Trazabilidad completa de un lote: de la cosecha al pago del productor.</summary>
public class LoteDetalleViewModel
{
    public LoteEncabezado Lote { get; set; } = new();
    public Acopio? Acopio { get; set; }
    public IReadOnlyList<EtapaLinea> Etapas { get; set; } = [];
    public Calidad? Calidad { get; set; }
    public IReadOnlyList<Merma> Mermas { get; set; } = [];
    public IReadOnlyList<MovimientoFila> Movimientos { get; set; } = [];
    public IReadOnlyList<VentaFila> Ventas { get; set; } = [];
    public IReadOnlyList<PagoFila> Pagos { get; set; } = [];

    /// <summary>Existencia actual del lote en bodega, calculada desde los movimientos.</summary>
    public decimal ExistenciaEnBodega =>
        Movimientos.Sum(m => m.EsEntrada ? m.CantidadQuintales : -m.CantidadQuintales);

    /// <summary>Merma total entre el peso cosechado y el peso actual del lote.</summary>
    public decimal MermaTotal => Lote.PesoInicialQuintales - Lote.PesoActualQuintales;
}
