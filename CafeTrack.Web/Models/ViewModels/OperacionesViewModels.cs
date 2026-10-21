using System.ComponentModel.DataAnnotations;

namespace CafeTrack.Web.Models.ViewModels;

/// <summary>Lote mostrado en los desplegables de los formularios.</summary>
public class LoteOpcion
{
    public int IdLote { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public string Productor { get; set; } = string.Empty;
    public string Variedad { get; set; } = string.Empty;
    public decimal PesoReferencia { get; set; }
    public int? IdBodega { get; set; }
    public string? Bodega { get; set; }

    /// <summary>Texto que se muestra en el &lt;option&gt;.</summary>
    public string Etiqueta => $"{CodigoLote} · {Productor} · {Variedad}";
}

/// <summary>Datos que captura el formulario de acopio; los valida sp_registrar_acopio.</summary>
public class AcopioForm
{
    [Required(ErrorMessage = "Seleccione el lote que se está recibiendo.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione el lote que se está recibiendo.")]
    public int? IdLote { get; set; }

    [Required(ErrorMessage = "Indique el peso recibido.")]
    [Range(0.01, 99999999.99, ErrorMessage = "El peso recibido debe ser mayor que cero.")]
    public decimal? PesoRecibido { get; set; }

    [Required(ErrorMessage = "Indique quién recibe el lote.")]
    [StringLength(100)]
    public string Responsable { get; set; } = string.Empty;

    /// <summary>ENUM de la base: 'Buena', 'Regular' o 'Mala'.</summary>
    public string Condicion { get; set; } = "Buena";

    public string? Observaciones { get; set; }
}

/// <summary>Datos que captura el formulario de venta; los valida sp_registrar_venta.</summary>
public class VentaForm
{
    [Required(ErrorMessage = "Seleccione el lote que se vende.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione el lote que se vende.")]
    public int? IdLote { get; set; }

    [Required(ErrorMessage = "Seleccione el comprador.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione el comprador.")]
    public int? IdComprador { get; set; }

    [Required(ErrorMessage = "Seleccione la bodega de donde sale el café.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione la bodega de donde sale el café.")]
    public int? IdBodega { get; set; }

    [Required(ErrorMessage = "Indique la cantidad vendida.")]
    [Range(0.01, 99999999.99, ErrorMessage = "La cantidad vendida debe ser mayor que cero.")]
    public decimal? Peso { get; set; }

    [Required(ErrorMessage = "Indique el precio por quintal.")]
    [Range(0.01, 99999999.99, ErrorMessage = "El precio por quintal debe ser mayor que cero.")]
    public decimal? Precio { get; set; }

    /// <summary>ENUM de la base: 'Contado', 'Credito 30 dias' o 'Credito 60 dias'.</summary>
    public string FormaPago { get; set; } = "Contado";

    [Required(ErrorMessage = "Indique quién despacha el lote.")]
    [StringLength(100)]
    public string Responsable { get; set; } = string.Empty;
}

/// <summary>Lote esperando su próxima etapa del beneficiado.</summary>
public class LoteEnProceso
{
    public int IdLote { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public string Productor { get; set; } = string.Empty;
    public decimal PesoActual { get; set; }
    public int IdEtapa { get; set; }
    public string Etapa { get; set; } = string.Empty;
    public int Orden { get; set; }
    public decimal? DuracionMinHoras { get; set; }
    public decimal? DuracionMaxHoras { get; set; }

    /// <summary>La etapa ya tiene inicio registrado: esta llamada la cierra.</summary>
    public bool Abierta { get; set; }

    public DateTime? FechaInicio { get; set; }

    public string Etiqueta =>
        $"{CodigoLote} · {Productor} · {(Abierta ? "cerrar" : "etapa")} {Orden}. {Etapa}";
}

/// <summary>Lote que terminó el beneficiado y espera catación.</summary>
public class LoteParaCatar
{
    public int IdLote { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public string Productor { get; set; } = string.Empty;
    public string Variedad { get; set; } = string.Empty;
    public int? AltitudMetros { get; set; }
    public decimal PesoActual { get; set; }

    public string Etiqueta => $"{CodigoLote} · {Productor} · {Variedad}";
}

/// <summary>Lote aprobado que todavía no entró del todo a bodega.</summary>
public class LoteParaBodega
{
    public int IdLote { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public string Productor { get; set; } = string.Empty;
    public decimal PesoActual { get; set; }
    public decimal EnBodega { get; set; }
    public decimal Disponible => PesoActual - EnBodega;

    public string Etiqueta => $"{CodigoLote} · {Productor}";
}

/// <summary>Venta que todavía no se le ha pagado al productor.</summary>
public class VentaSinPago
{
    public int IdVenta { get; set; }
    public string CodigoLote { get; set; } = string.Empty;
    public string Productor { get; set; } = string.Empty;
    public string Comprador { get; set; } = string.Empty;
    public DateTime FechaVenta { get; set; }
    public decimal PesoVendido { get; set; }
    public decimal PrecioVenta { get; set; }
    public decimal TotalVenta { get; set; }

    public string Etiqueta => $"Venta {IdVenta} · {CodigoLote} · {Productor}";
}

/// <summary>Formulario de una etapa del beneficiado.</summary>
public class ProcesoForm
{
    // Anulables para que un desplegable sin elegir avise con este texto y no
    // con el mensaje generico del enlazador.
    [Required(ErrorMessage = "Seleccione el lote.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione el lote.")]
    public int? IdLote { get; set; }

    [Required(ErrorMessage = "Elija primero el lote: la etapa la calcula el sistema.")]
    [Range(1, int.MaxValue, ErrorMessage = "Elija primero el lote: la etapa la calcula el sistema.")]
    public int? IdEtapa { get; set; }

    [Required(ErrorMessage = "Indique cuándo empezó la etapa.")]
    [DisplayFormat(DataFormatString = "{0:yyyy-MM-ddTHH:mm}", ApplyFormatInEditMode = true)]
    public DateTime? FechaInicio { get; set; }

    [DisplayFormat(DataFormatString = "{0:yyyy-MM-ddTHH:mm}", ApplyFormatInEditMode = true)]
    public DateTime? FechaFin { get; set; }

    [Required(ErrorMessage = "Indique el peso que entró.")]
    [Range(0.01, 99999999.99, ErrorMessage = "El peso de entrada debe ser mayor que cero.")]
    public decimal? PesoEntrada { get; set; }

    public decimal? PesoSalida { get; set; }

    [Required(ErrorMessage = "Indique quién responde por la etapa.")]
    [StringLength(100)]
    public string Responsable { get; set; } = string.Empty;
}

/// <summary>Formulario de catación.</summary>
public class CalidadForm
{
    [Required(ErrorMessage = "Seleccione el lote que se cató.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione el lote que se cató.")]
    public int? IdLote { get; set; }

    [Required(ErrorMessage = "Indique quién cató el lote.")]
    [StringLength(100)]
    public string Evaluador { get; set; } = string.Empty;

    [Required(ErrorMessage = "Indique el puntaje SCA.")]
    [Range(0, 100, ErrorMessage = "El puntaje debe estar entre 0 y 100.")]
    public decimal? Puntaje { get; set; }

    /// <summary>ENUM: 'Estrictamente Altura', 'Altura', 'Central' o 'Baja'.</summary>
    [Required(ErrorMessage = "Indique la altura de taza.")]
    public string Altura { get; set; } = string.Empty;

    [StringLength(200)]
    public string? Defectos { get; set; }

    /// <summary>Nota libre que escribe el catador; va al final del perfil.</summary>
    public string? Perfil { get; set; }

    /// <summary>
    /// Notas marcadas en el panel, como "Familia&gt;nota" separadas por "|".
    /// El servidor las ordena y las arma antes de guardar.
    /// </summary>
    public string? Notas { get; set; }

    [Required(ErrorMessage = "Indique si el lote se aprueba o se rechaza.")]
    public bool? Aprobado { get; set; }
}

/// <summary>Formulario de ingreso a bodega.</summary>
public class IngresoBodegaForm
{
    [Required(ErrorMessage = "Seleccione el lote.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione el lote.")]
    public int? IdLote { get; set; }

    [Required(ErrorMessage = "Seleccione la bodega.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione la bodega.")]
    public int? IdBodega { get; set; }

    [Required(ErrorMessage = "Indique la cantidad que ingresa.")]
    [Range(0.01, 99999999.99, ErrorMessage = "La cantidad debe ser mayor que cero.")]
    public decimal? Cantidad { get; set; }

    [Required(ErrorMessage = "Indique quién recibe en bodega.")]
    [StringLength(100)]
    public string Responsable { get; set; } = string.Empty;
}

/// <summary>Formulario de pago al productor.</summary>
public class PagoForm
{
    [Required(ErrorMessage = "Seleccione la venta que se está pagando.")]
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione la venta que se está pagando.")]
    public int? IdVenta { get; set; }

    [Required(ErrorMessage = "Indique el precio pagado por quintal.")]
    [Range(0.01, 99999999.99, ErrorMessage = "El precio debe ser mayor que cero.")]
    public decimal? Precio { get; set; }

    [Range(0, 99999999.99, ErrorMessage = "Las deducciones no pueden ser negativas.")]
    public decimal? Deducciones { get; set; } = 0;

    /// <summary>ENUM: 'Efectivo', 'Transferencia' o 'Cheque'.</summary>
    public string Metodo { get; set; } = "Transferencia";

    [StringLength(50)]
    public string? Comprobante { get; set; }
}
