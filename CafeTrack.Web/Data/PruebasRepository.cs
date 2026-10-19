using System.Data;
using CafeTrack.Web.Helpers;
using Dapper;
using MySqlConnector;

namespace CafeTrack.Web.Data;

/// <summary>Lo que respondió la base ante una operación que debe fallar.</summary>
public sealed class ResultadoPrueba
{
    public string Caso { get; init; } = string.Empty;
    public string Sql { get; init; } = string.Empty;
    public bool Fallo { get; init; }
    public int Numero { get; init; }
    public string? SqlState { get; init; }
    public string MensajeCrudo { get; init; } = string.Empty;
    public string MensajeAmable { get; init; } = string.Empty;
}

/// <summary>
/// Pruebas de las tres barreras de la base: SIGNAL de una rutina, restricción
/// CHECK y permisos del usuario de MySQL. Todo corre dentro de una transacción
/// que siempre se deshace, así que nada queda escrito.
/// </summary>
public interface IPruebasRepository
{
    Task<ResultadoPrueba> ProbarAsync(string caso, CancellationToken ct = default);
}

/// <inheritdoc cref="IPruebasRepository"/>
public sealed class PruebasRepository : IPruebasRepository
{
    private readonly IDbConnectionFactory _fabrica;

    public PruebasRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    /// <summary>Sentencia de cada caso. La clave nunca viaja al SQL.</summary>
    private static readonly Dictionary<string, string> Sentencias = new()
    {
        // CAF-2025-005 fue rechazado en catacion: sp_registrar_venta lo impide.
        ["signal"] = """
            CALL sp_registrar_venta(5, 1, 1, 1.00, 1300.00, 'Contado',
                                    'Prueba del sistema', 'prueba', @salida);
            """,

        // chk_aco_peso exige peso_recibido_quintales > 0.
        ["check"] = """
            INSERT INTO Acopios (id_lote, peso_recibido_quintales, responsable_recepcion)
            VALUES (1, -5.00, 'Prueba del sistema');
            """,

        // Escritura directa: depende de los GRANT del rol de la sesion.
        ["permiso"] = """
            INSERT INTO Compradores (nombre, tipo)
            VALUES ('Comprador de prueba', 'Tostador');
            """
    };

    public async Task<ResultadoPrueba> ProbarAsync(string caso, CancellationToken ct = default)
    {
        if (!Sentencias.TryGetValue(caso, out var sql))
        {
            throw new InvalidOperationException($"Caso de prueba no reconocido: {caso}");
        }

        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        await using var transaccion = await conexion.BeginTransactionAsync(ct);

        try
        {
            if (caso == "signal")
            {
                // El procedimiento tiene un parametro de salida, asi que se
                // invoca como rutina y no como texto: MySqlConnector tomaria
                // el "@salida" de la sentencia como un parametro por enlazar.
                var parametros = new DynamicParameters();
                parametros.Add("p_id_lote", 5);
                parametros.Add("p_id_comprador", 1);
                parametros.Add("p_id_bodega", 1);
                parametros.Add("p_peso", 1.00m);
                parametros.Add("p_precio", 1300.00m);
                parametros.Add("p_forma_pago", "Contado");
                parametros.Add("p_responsable", "Prueba del sistema");
                parametros.Add("p_usuario", "prueba");
                parametros.Add("p_id_venta", dbType: DbType.Int32,
                               direction: ParameterDirection.Output);

                await conexion.ExecuteAsync(new CommandDefinition(
                    "sp_registrar_venta", parametros, transaction: transaccion,
                    commandType: CommandType.StoredProcedure, cancellationToken: ct));
            }
            else
            {
                await conexion.ExecuteAsync(new CommandDefinition(
                    sql, transaction: transaccion, cancellationToken: ct));
            }

            // Si llega aqui la operacion fue permitida: se deshace igual.
            return new ResultadoPrueba
            {
                Caso = caso,
                Sql = sql.Trim(),
                Fallo = false,
                MensajeAmable = "La base aceptó la operación: su rol tiene permiso para hacerla. " +
                                "El cambio se deshizo, no quedó nada escrito."
            };
        }
        catch (MySqlException ex)
        {
            return new ResultadoPrueba
            {
                Caso = caso,
                Sql = sql.Trim(),
                Fallo = true,
                Numero = ex.Number,
                SqlState = ex.SqlState,
                MensajeCrudo = ex.Message,
                MensajeAmable = ErroresMySql.Traducir(ex)
            };
        }
        finally
        {
            // Pase lo que pase, la prueba no deja rastro.
            try
            {
                await transaccion.RollbackAsync(ct);
            }
            catch (MySqlException)
            {
                // La transaccion ya pudo quedar deshecha por el propio error.
            }
        }
    }
}
