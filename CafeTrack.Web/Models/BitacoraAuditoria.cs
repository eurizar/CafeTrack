namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>BitacoraAuditoria</c>. Se consulta a partir de la Fase 3.</summary>
public class BitacoraAuditoria
{
    public int IdBitacora { get; set; }
    public string TablaAfectada { get; set; } = string.Empty;
    /// <summary>ENUM: 'INSERT' | 'UPDATE' | 'DELETE' | 'ALERTA_PRECIO_BAJO' | 'ALERTA_MERMA_ALTA'.</summary>
    public string Operacion { get; set; } = string.Empty;
    public int? IdRegistroAfectado { get; set; }
    public string Usuario { get; set; } = string.Empty;
    public DateTime FechaHora { get; set; }
    /// <summary>Columna JSON, se lee como texto.</summary>
    public string? DatosAnteriores { get; set; }
    /// <summary>Columna JSON, se lee como texto.</summary>
    public string? DatosNuevos { get; set; }
}
