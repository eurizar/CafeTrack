using System.Data.Common;
using CafeTrack.Web.Helpers;
using MySqlConnector;

namespace CafeTrack.Web.Data;

/// <summary>
/// Implementacion de <see cref="IDbConnectionFactory"/> para MySQL con MySqlConnector.
/// Las cadenas viven en User Secrets, nunca en archivos versionados.
/// </summary>
/// <remarks>
/// Desde la Fase 3 la conexion depende del rol de quien inicio sesion: busca la
/// cadena <c>ConnectionStrings:CafeTrack:&lt;rol&gt;</c> y, si no existe, usa la de
/// omision. Asi los permisos los decide MySQL y no solo la interfaz: un rol sin
/// privilegios recibe ERROR 1142 del motor.
/// </remarks>
public sealed class MySqlConnectionFactory : IDbConnectionFactory
{
    /// <summary>Nombre de la cadena de conexion de omision.</summary>
    public const string NombreCadena = "CafeTrack";

    private readonly IConfiguration _configuracion;
    private readonly ILogger<MySqlConnectionFactory> _log;
    private readonly IUsuarioActual _usuario;

    public MySqlConnectionFactory(
        IConfiguration configuracion,
        ILogger<MySqlConnectionFactory> log,
        IUsuarioActual usuario)
    {
        _configuracion = configuracion;
        _log = log;
        _usuario = usuario;
    }

    /// <summary>Abre la conexion que corresponde al rol de la sesion actual.</summary>
    public Task<DbConnection> CrearConexionAsync(CancellationToken ct = default) =>
        CrearConexionAsync(_usuario.Rol, ct);

    public Task<DbConnection> CrearConexionAsync(string rol, CancellationToken ct = default)
    {
        var nombre = string.IsNullOrWhiteSpace(rol) ? NombreCadena : $"{NombreCadena}:{rol}";

        if (string.IsNullOrWhiteSpace(_configuracion.GetConnectionString(nombre)))
        {
            // Sin cadena propia para el rol se cae a la de desarrollo.
            nombre = NombreCadena;
        }

        return AbrirAsync(nombre, ct);
    }

    private async Task<DbConnection> AbrirAsync(string nombre, CancellationToken ct)
    {
        var cadena = _configuracion.GetConnectionString(nombre);
        if (string.IsNullOrWhiteSpace(cadena))
        {
            throw new InvalidOperationException(
                $"No hay cadena de conexion '{nombre}'. Configurala con: " +
                "dotnet user-secrets set \"ConnectionStrings:CafeTrack\" \"Server=localhost;Port=3306;" +
                "Database=trazabilidad_cafe;User=cafetrack_dev;Password=...;\"");
        }

        var conexion = new MySqlConnection(cadena);
        try
        {
            await conexion.OpenAsync(ct);
            return conexion;
        }
        catch
        {
            await conexion.DisposeAsync();
            _log.LogError("No se pudo abrir la conexion '{Nombre}' contra MySQL.", nombre);
            throw;
        }
    }
}
