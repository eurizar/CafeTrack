namespace CafeTrack.Web.Models;

/// <summary>
/// Tabla <c>Usuarios</c>. Se utiliza a partir de la Fase 3 (login SHA2 + salt).
/// <c>password_hash</c> no se mapea: ninguna pantalla de la Fase 1 lo necesita.
/// </summary>
public class Usuario
{
    public int IdUsuario { get; set; }
    public string Username { get; set; } = string.Empty;
    public string NombreCompleto { get; set; } = string.Empty;
    /// <summary>ENUM: 'admin' | 'gerente' | 'acopiador' | 'catador' | 'auditor'.</summary>
    public string Rol { get; set; } = string.Empty;
    public bool Activo { get; set; }
    public DateTime? UltimoAcceso { get; set; }
}
