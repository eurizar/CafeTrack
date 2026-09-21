using System.Data.Common;

namespace CafeTrack.Web.Data;

/// <summary>
/// Fabrica de conexiones a MySQL. Se inyecta en los repositorios para que ninguno
/// conozca la cadena de conexion ni el ciclo de vida de la conexion.
/// </summary>
/// <remarks>
/// El parametro <c>rol</c> esta previsto para la Fase 3: cada rol de la aplicacion
/// (admin, gerente, acopiador, catador, auditor) se conectara con un usuario MySQL
/// distinto, con sus propios GRANT. En la Fase 1 todos los roles resuelven a la
/// misma cadena (<c>cafetrack_dev</c>) porque las pantallas son de solo lectura.
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
