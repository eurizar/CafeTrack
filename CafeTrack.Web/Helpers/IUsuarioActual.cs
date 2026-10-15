namespace CafeTrack.Web.Helpers;

/// <summary>
/// Identidad con la que la aplicacion escribe en la base (columnas
/// <c>usuario_registro</c> y la bitacora).
/// </summary>
/// <remarks>
/// En la Fase 2 todavia no hay login: devuelve un usuario fijo. En la Fase 3
/// esta misma interfaz pasa a leer la sesion autenticada y el rol decide con
/// que usuario de MySQL se abre la conexion.
/// </remarks>
public interface IUsuarioActual
{
    /// <summary>Nombre que queda registrado en la base.</summary>
    string Nombre { get; }

    /// <summary>Rol de la aplicacion: admin, gerente, acopiador, catador o auditor.</summary>
    string Rol { get; }
}

/// <summary>Implementacion temporal de la Fase 2, sin autenticacion.</summary>
public sealed class UsuarioFijo : IUsuarioActual
{
    public string Nombre => "sistema";
    public string Rol => "admin";
}
