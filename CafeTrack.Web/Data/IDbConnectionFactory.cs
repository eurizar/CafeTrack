using System.Data.Common;

namespace CafeTrack.Web.Data;

/// <summary>
/// Fabrica de conexiones a MySQL. Se inyecta en los repositorios para que ninguno
/// conozca la cadena de conexion ni el ciclo de vida de la conexion.
/// </summary>
/// <remarks>
/// Cada rol de la aplicacion (admin, gerente, acopiador, catador, auditor) se
/// conecta con un usuario MySQL distinto, con sus propios GRANT. Sin sesion se
/// usa la cadena por omision (<c>cafetrack_dev</c>), la que valida el login.
/// </remarks>
public interface IDbConnectionFactory
{
    /// <summary>Abre una conexion con el usuario de aplicacion por omision.</summary>
    Task<DbConnection> CrearConexionAsync(CancellationToken ct = default);

    /// <summary>
    /// Abre una conexion con el usuario MySQL asociado al rol indicado.
    /// Si no hay una cadena configurada para ese rol, usa la de omision.
    /// </summary>
    Task<DbConnection> CrearConexionAsync(string rol, CancellationToken ct = default);
}
