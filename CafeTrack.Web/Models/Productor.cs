namespace CafeTrack.Web.Models;

/// <summary>
/// Tabla <c>Productores</c>. La columna <c>documento_identidad</c> existe en la base
/// pero NO se mapea aqui: ninguna consulta de la aplicacion debe seleccionarla.
/// </summary>
public class Productor
{
    public int IdProductor { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Telefono { get; set; }
    public string? Comunidad { get; set; }
    public DateOnly FechaIngresoCoop { get; set; }
    public bool Activo { get; set; }
}
