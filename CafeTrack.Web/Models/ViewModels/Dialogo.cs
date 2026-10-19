namespace CafeTrack.Web.Models.ViewModels;

/// <summary>Contenido de una ventana flotante (elemento &lt;dialog&gt;).</summary>
public class Dialogo
{
    /// <summary>Encabezado de la ventana.</summary>
    public string Titulo { get; set; } = string.Empty;

    /// <summary>Mensaje principal, redactado para el usuario.</summary>
    public string Mensaje { get; set; } = string.Empty;

    /// <summary>Dato técnico opcional: número de error, SQLSTATE, etc.</summary>
    public string? Detalle { get; set; }

    /// <summary>Texto crudo del motor, para quien quiera verlo.</summary>
    public string? Crudo { get; set; }

    /// <summary>"error" o "exito": decide el color y el icono.</summary>
    public string Tipo { get; set; } = "error";

    public bool EsError => Tipo == "error";
}
