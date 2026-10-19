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
    Task<SesionUsuario?> IngresarAsync(string usuario, string clave, CancellationToken ct = default);

    /// <summary>Usuarios del sistema, para la pantalla del administrador.</summary>
    Task<IReadOnlyList<UsuarioFila>> ListarUsuariosAsync(CancellationToken ct = default);

    /// <summary>Crea un usuario con contraseña temporal (sp_crear_usuario).</summary>
    Task CrearUsuarioAsync(UsuarioNuevoForm datos, string temporal, string admin,
                           CancellationToken ct = default);

    /// <summary>Asigna una contraseña temporal nueva (sp_reiniciar_password).</summary>
    Task ReiniciarPasswordAsync(string username, string temporal, string admin,
                                CancellationToken ct = default);

    /// <summary>Cambia el rol de un usuario (sp_cambiar_rol).</summary>
    Task CambiarRolAsync(string username, string rol, string admin, CancellationToken ct = default);

    /// <summary>Activa o desactiva un usuario (sp_cambiar_estado_usuario).</summary>
    Task CambiarEstadoAsync(string username, bool activo, string admin,
                            CancellationToken ct = default);

    /// <summary>Cambia la contraseña del propio usuario (sp_cambiar_password).</summary>
    Task CambiarPasswordAsync(string username, string actual, string nueva,
                              CancellationToken ct = default);

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

    public async Task<SesionUsuario?> IngresarAsync(
        string usuario, string clave, CancellationToken ct = default)
    {
        // El login ocurre antes de conocer el rol: usa la conexion de omision.
        await using var conexion = await _fabrica.CrearConexionAsync(string.Empty, ct);

        var filas = await conexion.QueryAsync<SesionUsuario>(new CommandDefinition(
            "CALL sp_login(@p_username, @p_password);",
            new { p_username = usuario, p_password = clave },
            cancellationToken: ct));

        return filas.FirstOrDefault();
    }

    // La columna tipo_contrasena no existe: se deduce del prefijo del hash.
    private const string SqlUsuarios = """
        SELECT u.id_usuario      AS id_usuario,
               u.username        AS username,
               u.nombre_completo AS nombre_completo,
               u.rol             AS rol,
               u.activo          AS activo,
               u.ultimo_acceso   AS ultimo_acceso,
               IF(LEFT(u.password_hash, 4) = 'TMP:', 'temporal', 'propia') AS tipo_contrasena
          FROM Usuarios u
         ORDER BY u.activo DESC, u.rol, u.username;
        """;

    public async Task<IReadOnlyList<UsuarioFila>> ListarUsuariosAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<UsuarioFila>(
            new CommandDefinition(SqlUsuarios, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task CrearUsuarioAsync(
        UsuarioNuevoForm datos, string temporal, string admin, CancellationToken ct = default)
    {
        await EjecutarAsync("sp_crear_usuario", new
        {
            p_username = datos.Username.Trim(),
            p_nombre = datos.NombreCompleto.Trim(),
            p_rol = datos.Rol,
            p_temporal = temporal,
            p_admin = admin
        }, ct);
    }

    public Task ReiniciarPasswordAsync(
        string username, string temporal, string admin, CancellationToken ct = default) =>
        EjecutarAsync("sp_reiniciar_password",
            new { p_username = username, p_temporal = temporal, p_admin = admin }, ct);

    public Task CambiarRolAsync(
        string username, string rol, string admin, CancellationToken ct = default) =>
        EjecutarAsync("sp_cambiar_rol",
            new { p_username = username, p_rol = rol, p_admin = admin }, ct);

    public Task CambiarEstadoAsync(
        string username, bool activo, string admin, CancellationToken ct = default) =>
        EjecutarAsync("sp_cambiar_estado_usuario",
            new { p_username = username, p_activo = activo, p_admin = admin }, ct);

    public Task CambiarPasswordAsync(
        string username, string actual, string nueva, CancellationToken ct = default) =>
        EjecutarAsync("sp_cambiar_password",
            new { p_username = username, p_password_act = actual, p_password_new = nueva }, ct);

    /// <summary>Llama a un procedimiento sin resultado; los errores los levanta MySQL.</summary>
    private async Task EjecutarAsync(string rutina, object parametros, CancellationToken ct)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        await conexion.ExecuteAsync(new CommandDefinition(
            rutina, parametros, commandType: System.Data.CommandType.StoredProcedure,
            cancellationToken: ct));
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
