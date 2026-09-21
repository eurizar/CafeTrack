using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>
/// Kardex resumido. La existencia nunca se lee de una columna: se calcula
/// desde MovimientosBodega ('Entrada' suma, los demas tipos restan).
/// </summary>
public interface IExistenciaRepository
{
    /// <summary>Existencias por bodega y lote; filtro opcional por bodega.</summary>
    Task<IReadOnlyList<ExistenciaFila>> ListarAsync(int? idBodega, CancellationToken ct = default);

    /// <summary>Bodegas activas con su ocupacion, para el encabezado de la pantalla.</summary>
    Task<IReadOnlyList<OcupacionBodega>> ListarBodegasAsync(CancellationToken ct = default);
}

/// <inheritdoc cref="IExistenciaRepository"/>
public sealed class ExistenciaRepository : IExistenciaRepository
{
    private readonly IDbConnectionFactory _fabrica;

    public ExistenciaRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    // Entradas, salidas y existencia de cada lote en cada bodega.
    // Se listan tambien los lotes con existencia 0 para dejar rastro del movimiento.
    private const string SqlKardex = """
        SELECT b.id_bodega    AS id_bodega,
               b.nombre       AS bodega,
               l.id_lote      AS id_lote,
               l.codigo_lote  AS codigo_lote,
               p.nombre       AS productor,
               l.estado_lote  AS estado_lote,
               COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                                 THEN mb.cantidad_quintales ELSE 0 END), 0)  AS entradas,
               COALESCE(SUM(CASE WHEN mb.tipo_movimiento <> 'Entrada'
                                 THEN mb.cantidad_quintales ELSE 0 END), 0)  AS salidas,
               COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                                 THEN mb.cantidad_quintales
                                 ELSE -mb.cantidad_quintales END), 0)        AS existencia,
               MAX(mb.fecha_movimiento)                                      AS ultimo_movimiento
          FROM MovimientosBodega mb
          JOIN Bodegas     b  ON b.id_bodega    = mb.id_bodega
          JOIN Lotes       l  ON l.id_lote      = mb.id_lote
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
         WHERE (@idBodega IS NULL OR b.id_bodega = @idBodega)
         GROUP BY b.id_bodega, b.nombre, l.id_lote, l.codigo_lote, p.nombre, l.estado_lote
         ORDER BY b.nombre, l.codigo_lote;
        """;

    private const string SqlBodegas = """
        SELECT b.id_bodega            AS id_bodega,
               b.nombre               AS nombre,
               b.ubicacion            AS ubicacion,
               b.responsable          AS responsable,
               b.capacidad_quintales  AS capacidad_quintales,
               COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                                 THEN mb.cantidad_quintales
                                 ELSE -mb.cantidad_quintales END), 0) AS existencia_quintales
          FROM Bodegas b
          LEFT JOIN MovimientosBodega mb ON mb.id_bodega = b.id_bodega
         GROUP BY b.id_bodega, b.nombre, b.ubicacion, b.responsable, b.capacidad_quintales
         ORDER BY b.nombre;
        """;

    public async Task<IReadOnlyList<ExistenciaFila>> ListarAsync(
        int? idBodega, CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<ExistenciaFila>(
            new CommandDefinition(SqlKardex, new { idBodega }, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<OcupacionBodega>> ListarBodegasAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var bodegas = await conexion.QueryAsync<OcupacionBodega>(
            new CommandDefinition(SqlBodegas, cancellationToken: ct));
        return bodegas.AsList();
    }
}
