namespace CafeTrack.Web.Models;

/// <summary>
/// Tabla <c>Usuarios</c> (login SHA2 + salt).
/// <c>password_hash</c> no se mapea: la validacion ocurre dentro de sp_login.
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
