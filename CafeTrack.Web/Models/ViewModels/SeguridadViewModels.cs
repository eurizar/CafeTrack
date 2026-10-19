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

/// <summary>
/// Lo que devuelve <c>sp_login</c>: los datos del usuario más la marca de
/// contraseña temporal, que no es una columna de la tabla sino algo que el
/// procedimiento deduce del prefijo <c>TMP:</c>.
/// </summary>
public class SesionUsuario
{
    public int IdUsuario { get; set; }
    public string Username { get; set; } = string.Empty;
    public string NombreCompleto { get; set; } = string.Empty;
    public string Rol { get; set; } = string.Empty;
    public bool Activo { get; set; }
    public DateTime? UltimoAcceso { get; set; }

    /// <summary>La contraseña vigente es temporal: hay que registrar una propia.</summary>
    public bool DebeCambiar { get; set; }
}

/// <summary>Fila del listado de usuarios que ve el administrador.</summary>
public class UsuarioFila
{
    public int IdUsuario { get; set; }
    public string Username { get; set; } = string.Empty;
    public string NombreCompleto { get; set; } = string.Empty;
    public string Rol { get; set; } = string.Empty;
    public bool Activo { get; set; }
    public DateTime? UltimoAcceso { get; set; }

    /// <summary>"temporal" o "propia": lo calcula la consulta, no se guarda.</summary>
    public string TipoContrasena { get; set; } = "propia";

    public bool EsTemporal => TipoContrasena == "temporal";
}

/// <summary>Datos del formulario para crear un usuario.</summary>
public class UsuarioNuevoForm
{
    [Required(ErrorMessage = "Escriba el nombre de usuario.")]
    [StringLength(50, MinimumLength = 3, ErrorMessage = "Entre 3 y 50 caracteres.")]
    [RegularExpression("^[a-zA-Z0-9._-]+$",
        ErrorMessage = "Solo letras, números, punto, guion y guion bajo.")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escriba el nombre completo.")]
    [StringLength(100)]
    public string NombreCompleto { get; set; } = string.Empty;

    [Required(ErrorMessage = "Elija el rol.")]
    public string Rol { get; set; } = "acopiador";
}

/// <summary>Cambio de contraseña del propio usuario.</summary>
public class CambioClaveForm
{
    [Required(ErrorMessage = "Escriba su contraseña actual.")]
    [DataType(DataType.Password)]
    public string Actual { get; set; } = string.Empty;

    [Required(ErrorMessage = "Escriba la contraseña nueva.")]
    [StringLength(255, MinimumLength = 8, ErrorMessage = "Debe tener al menos 8 caracteres.")]
    [DataType(DataType.Password)]
    public string Nueva { get; set; } = string.Empty;

    [Required(ErrorMessage = "Repita la contraseña nueva.")]
    [Compare(nameof(Nueva), ErrorMessage = "Las dos contraseñas no coinciden.")]
    [DataType(DataType.Password)]
    public string Repetir { get; set; } = string.Empty;
}
