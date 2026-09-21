using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>Consultas de solo lectura que alimentan el panel de inicio.</summary>
public interface IPanelRepository
{
    Task<PanelViewModel> ObtenerPanelAsync(CancellationToken ct = default);
}

/// <inheritdoc cref="IPanelRepository"/>
public sealed class PanelRepository : IPanelRepository
{
    private readonly IDbConnectionFactory _fabrica;

    public PanelRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    // Tres consultas en un solo viaje a la base:
    //  1. Cifras generales de la cooperativa y temporada en curso.
    //  2. Lotes agrupados por estado.
    //  3. Ocupacion de cada bodega activa (existencia calculada desde MovimientosBodega).
    private const string Sql = """
        SELECT
          (SELECT COUNT(*) FROM Productores WHERE activo = TRUE)            AS productores_activos,
          (SELECT COUNT(*) FROM Parcelas    WHERE activa = TRUE)            AS parcelas_activas,
          (SELECT COUNT(*) FROM Lotes)                                      AS total_lotes,
          (SELECT COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                                    THEN mb.cantidad_quintales
                                    ELSE -mb.cantidad_quintales END), 0)
             FROM MovimientosBodega mb)                                     AS quintales_en_bodega,
          (SELECT COALESCE(SUM(v.total_venta), 0)
             FROM VentasLotes v
             JOIN Lotes      l ON l.id_lote      = v.id_lote
             JOIN Cosechas   c ON c.id_cosecha   = l.id_cosecha
             JOIN Temporadas t ON t.id_temporada = c.id_temporada
            WHERE t.estado = 'En curso')                                    AS valor_ventas_temporada,
          (SELECT CAST(t.anio AS CHAR)
             FROM Temporadas t WHERE t.estado = 'En curso'
            ORDER BY t.anio DESC LIMIT 1)                                   AS temporada_en_curso,
          (SELECT t.precio_base_quintal
             FROM Temporadas t WHERE t.estado = 'En curso'
            ORDER BY t.anio DESC LIMIT 1)                                   AS precio_base_quintal;

        SELECT l.estado_lote                            AS estado_lote,
               COUNT(*)                                 AS cantidad,
               COALESCE(SUM(l.peso_actual_quintales), 0) AS quintales
          FROM Lotes l
         GROUP BY l.estado_lote
         ORDER BY FIELD(l.estado_lote,
                        'En acopio', 'En proceso', 'En bodega', 'Vendido', 'Rechazado');

        SELECT b.id_bodega                                                   AS id_bodega,
               b.nombre                                                      AS nombre,
               b.ubicacion                                                   AS ubicacion,
               b.responsable                                                 AS responsable,
               b.capacidad_quintales                                         AS capacidad_quintales,
               COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                                 THEN mb.cantidad_quintales
                                 ELSE -mb.cantidad_quintales END), 0)        AS existencia_quintales
          FROM Bodegas b
          LEFT JOIN MovimientosBodega mb ON mb.id_bodega = b.id_bodega
         WHERE b.activa = TRUE
         GROUP BY b.id_bodega, b.nombre, b.ubicacion, b.responsable, b.capacidad_quintales
         ORDER BY b.nombre;
        """;

    public async Task<PanelViewModel> ObtenerPanelAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        using var resultados = await conexion.QueryMultipleAsync(
            new CommandDefinition(Sql, cancellationToken: ct));

        var panel = await resultados.ReadSingleAsync<PanelViewModel>();
        panel.LotesPorEstado = (await resultados.ReadAsync<ConteoEstadoLote>()).AsList();
        panel.Bodegas = (await resultados.ReadAsync<OcupacionBodega>()).AsList();
        return panel;
    }
}
