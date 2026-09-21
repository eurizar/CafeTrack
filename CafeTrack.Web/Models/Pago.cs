namespace CafeTrack.Web.Models;

/// <summary>Tabla <c>Pagos</c>. <c>monto_neto</c> es GENERATED: solo lectura.</summary>
public class Pago
{
    public int IdPago { get; set; }
    public int IdProductor { get; set; }
    public int IdVenta { get; set; }
    public DateTime FechaPago { get; set; }
    public decimal MontoPagado { get; set; }
    public decimal PrecioPagadoQuintal { get; set; }
    public decimal Deducciones { get; set; }
    /// <summary>Columna GENERATED (monto_pagado - deducciones). Nunca se incluye en INSERT ni UPDATE.</summary>
    public decimal MontoNeto { get; set; }
    /// <summary>ENUM: 'Efectivo' | 'Transferencia' | 'Cheque'.</summary>
    public string MetodoPago { get; set; } = string.Empty;
    public string? Comprobante { get; set; }
    public string UsuarioRegistro { get; set; } = string.Empty;
}
