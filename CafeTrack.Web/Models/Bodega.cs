namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Bodegas</c>: almacenes de la cooperativa.</summary>
public class Bodega
{
    public int IdBodega { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Ubicacion { get; set; }
    public decimal? CapacidadQuintales { get; set; }
    public string? Responsable { get; set; }
    public bool Activa { get; set; }
}
