namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Compradores</c>.</summary>
public class Comprador
{
    public int IdComprador { get; set; }
    public string Nombre { get; set; } = string.Empty;
    /// <summary>ENUM: 'Exportador' | 'Tostador' | 'Intermediario' | 'Cooperativa'.</summary>
    public string Tipo { get; set; } = string.Empty;
    public string? PaisDestino { get; set; }
    public string? Contacto { get; set; }
    public string? Telefono { get; set; }
    public bool Activo { get; set; }
}
