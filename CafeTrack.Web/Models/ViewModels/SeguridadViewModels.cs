using System.ComponentModel.DataAnnotations;

namespace CafeTrack.Web.Models.ViewModels;

/// <summary>Credenciales que captura la pantalla de ingreso.</summary>
public class IngresoForm
{
    [Required(ErrorMessage = "Escriba su usuario.")]
    [StringLength(50)]
    public string Usuario { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escriba su contraseña.")]
    [DataType(DataType.Password)]
    [StringLength(255)]
    public string Clave { get; set; } = string.Empty;
}

/// <summary>Fila de la bitácora de auditoría.</summary>
public class BitacoraFila
{
    public int IdBitacora { get; set; }
    public string TablaAfectada { get; set; } = string.Empty;
    public string Operacion { get; set; } = string.Empty;
    public int? IdRegistroAfectado { get; set; }
    public string Usuario { get; set; } = string.Empty;
    public DateTime FechaHora { get; set; }
    public string? DatosAnteriores { get; set; }
    public string? DatosNuevos { get; set; }

    /// <summary>Las operaciones de alerta se destacan en la tabla.</summary>
    public bool EsAlerta => Operacion.StartsWith("ALERTA", StringComparison.Ordinal);

    /// <summary>Sufijo de clase CSS para la etiqueta de la operación.</summary>
    public string ClaseOperacion => Operacion switch
    {
        "INSERT" => "bodega",
        "UPDATE" => "proceso",
        "DELETE" => "vendido",
        "ALERTA_MERMA_ALTA" => "acopio",
        "ALERTA_PRECIO_BAJO" => "rechazado",
        _ => "neutro"
    };
}
