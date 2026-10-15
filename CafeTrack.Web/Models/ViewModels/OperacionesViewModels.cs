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
    public int IdLote { get; set; }

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
    [Range(1, int.MaxValue, ErrorMessage = "Seleccione el lote que se vende.")]
    public int IdLote { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Seleccione el comprador.")]
    public int IdComprador { get; set; }

    [Range(1, int.MaxValue, ErrorMessage = "Seleccione la bodega de donde sale el café.")]
    public int IdBodega { get; set; }

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
