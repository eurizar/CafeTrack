using System.Security.Claims;

namespace CafeTrack.Web.Helpers;

/// <summary>
/// Identidad con la que la aplicacion trabaja contra la base: decide que se
/// escribe en <c>usuario_registro</c> y en la bitacora, y con que usuario de
/// MySQL se abre la conexion.
/// </summary>
public interface IUsuarioActual
{
    /// <summary>Usuario de la tabla <c>Usuarios</c>, o "invitado" si no hay sesion.</summary>
    string Nombre { get; }

    /// <summary>Nombre completo para mostrar en pantalla.</summary>
    string NombreCompleto { get; }

    /// <summary>Rol: admin, gerente, acopiador, catador o auditor. Vacio si no hay sesion.</summary>
    string Rol { get; }

    /// <summary>Indica si hay una sesion iniciada.</summary>
    bool Autenticado { get; }
}

/// <summary>
/// Ajustes del sistema que se leen de la configuracion (User Secrets o
/// appsettings). Hoy solo uno, pero deja el lugar para los que vengan.
/// </summary>
public sealed class Ajustes
{
    /// <summary>
    /// Permite registrar etapas con fecha futura. Sirve para demostrar en
    /// minutos un beneficiado que dura dias; en produccion va apagado.
    /// El orden entre etapas se sigue exigiendo siempre.
    /// </summary>
    public bool PermitirFechasFuturas { get; init; }

    public static Ajustes Leer(IConfiguration configuracion) => new()
    {
        PermitirFechasFuturas =
            configuracion.GetValue("CafeTrack:PermitirFechasFuturas", false)
    };
}

/// <summary>Lee la identidad de la cookie de sesion.</summary>
public sealed class UsuarioDeSesion : IUsuarioActual
{
    /// <summary>Claim con el nombre completo del usuario.</summary>
    public const string ClaimNombreCompleto = "cafetrack:nombre_completo";

    private readonly IHttpContextAccessor _contexto;

    public UsuarioDeSesion(IHttpContextAccessor contexto) => _contexto = contexto;

    private ClaimsPrincipal? Principal => _contexto.HttpContext?.User;

    public bool Autenticado => Principal?.Identity?.IsAuthenticated == true;

    public string Nombre => Autenticado ? Principal!.Identity!.Name ?? "invitado" : "invitado";

    public string NombreCompleto =>
        Principal?.FindFirstValue(ClaimNombreCompleto) ?? Nombre;

    /// <summary>
    /// Rol de la sesion. Sin sesion devuelve vacio, con lo que la fabrica de
    /// conexiones usa la cadena por omision (la que valida el login).
    /// </summary>
    public string Rol => Autenticado ? Principal!.FindFirstValue(ClaimTypes.Role) ?? "" : "";
}
