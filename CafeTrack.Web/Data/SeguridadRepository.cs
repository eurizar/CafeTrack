using CafeTrack.Web.Models;
using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>
/// Autenticacion y bitacora. La comparacion de la contrasena ocurre dentro de
/// MySQL (<c>sp_login</c>): la aplicacion nunca ve el hash ni el salt.
/// </summary>
public interface ISeguridadRepository
{
    /// <summary>
    /// Valida las credenciales con <c>sp_login</c>. Devuelve el usuario si son
    /// correctas; si no, el procedimiento levanta un SIGNAL.
    /// </summary>
    Task<Usuario?> IngresarAsync(string usuario, string clave, CancellationToken ct = default);

    /// <summary>Movimientos de la bitacora con filtros opcionales.</summary>
    Task<IReadOnlyList<BitacoraFila>> ListarBitacoraAsync(
        string? operacion, string? tabla, string? usuario, int limite, CancellationToken ct = default);

    /// <summary>Valores distintos de tabla y operacion presentes en la bitacora.</summary>
    Task<(IReadOnlyList<string> Tablas, IReadOnlyList<string> Operaciones)>
        ListarFiltrosBitacoraAsync(CancellationToken ct = default);
}

/// <inheritdoc cref="ISeguridadRepository"/>
public sealed class SeguridadRepository : ISeguridadRepository
{
    private readonly IDbConnectionFactory _fabrica;

    public SeguridadRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    private const string SqlBitacora = """
        SELECT b.id_bitacora          AS id_bitacora,
               b.tabla_afectada       AS tabla_afectada,
               b.operacion            AS operacion,
               b.id_registro_afectado AS id_registro_afectado,
               b.usuario              AS usuario,
               b.fecha_hora           AS fecha_hora,
               b.datos_anteriores     AS datos_anteriores,
               b.datos_nuevos         AS datos_nuevos
          FROM BitacoraAuditoria b
         WHERE (@operacion IS NULL OR b.operacion      = @operacion)
           AND (@tabla     IS NULL OR b.tabla_afectada = @tabla)
           AND (@usuario   IS NULL OR b.usuario LIKE CONCAT('%', @usuario, '%'))
         ORDER BY b.fecha_hora DESC, b.id_bitacora DESC
         LIMIT @limite;
        """;

    private const string SqlFiltros = """
        SELECT DISTINCT tabla_afectada FROM BitacoraAuditoria ORDER BY tabla_afectada;
        SELECT DISTINCT operacion      FROM BitacoraAuditoria ORDER BY operacion;
        """;

    public async Task<Usuario?> IngresarAsync(
        string usuario, string clave, CancellationToken ct = default)
    {
        // El login ocurre antes de conocer el rol: usa la conexion de omision.
        await using var conexion = await _fabrica.CrearConexionAsync(string.Empty, ct);

        var filas = await conexion.QueryAsync<Usuario>(new CommandDefinition(
            "CALL sp_login(@p_username, @p_password);",
            new { p_username = usuario, p_password = clave },
            cancellationToken: ct));

        return filas.FirstOrDefault();
    }

    public async Task<IReadOnlyList<BitacoraFila>> ListarBitacoraAsync(
        string? operacion, string? tabla, string? usuario, int limite, CancellationToken ct = default)
    {
        var parametros = new
        {
            operacion = string.IsNullOrWhiteSpace(operacion) ? null : operacion,
            tabla = string.IsNullOrWhiteSpace(tabla) ? null : tabla,
            usuario = string.IsNullOrWhiteSpace(usuario) ? null : usuario.Trim(),
            limite = Math.Clamp(limite, 10, 500)
        };

        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<BitacoraFila>(
            new CommandDefinition(SqlBitacora, parametros, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<(IReadOnlyList<string> Tablas, IReadOnlyList<string> Operaciones)>
        ListarFiltrosBitacoraAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        using var resultados = await conexion.QueryMultipleAsync(
            new CommandDefinition(SqlFiltros, cancellationToken: ct));

        var tablas = (await resultados.ReadAsync<string>()).AsList();
        var operaciones = (await resultados.ReadAsync<string>()).AsList();
        return (tablas, operaciones);
    }
}
