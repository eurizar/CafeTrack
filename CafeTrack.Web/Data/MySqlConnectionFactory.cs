using System.Data.Common;
using MySqlConnector;

namespace CafeTrack.Web.Data;

/// <summary>
/// Implementacion de <see cref="IDbConnectionFactory"/> para MySQL con MySqlConnector.
/// Las cadenas viven en User Secrets, nunca en archivos versionados.
/// </summary>
public sealed class MySqlConnectionFactory : IDbConnectionFactory
{
    /// <summary>Nombre de la cadena de conexion de omision.</summary>
    public const string NombreCadena = "CafeTrack";

    private readonly IConfiguration _configuracion;
    private readonly ILogger<MySqlConnectionFactory> _log;

    public MySqlConnectionFactory(IConfiguration configuracion, ILogger<MySqlConnectionFactory> log)
    {
        _configuracion = configuracion;
        _log = log;
    }

    public Task<DbConnection> CrearConexionAsync(CancellationToken ct = default) =>
        AbrirAsync(NombreCadena, ct);

    public Task<DbConnection> CrearConexionAsync(string rol, CancellationToken ct = default)
    {
        // Fase 3: la cadena por rol se llamara, por ejemplo, "CafeTrack:acopiador".
        var nombre = string.IsNullOrWhiteSpace(rol) ? NombreCadena : $"{NombreCadena}:{rol}";
        if (string.IsNullOrWhiteSpace(_configuracion.GetConnectionString(nombre)))
        {
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
