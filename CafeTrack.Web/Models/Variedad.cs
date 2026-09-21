namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Variedades</c>: catalogo de variedades de cafe.</summary>
public class Variedad
{
    public int IdVariedad { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activa { get; set; }
}
