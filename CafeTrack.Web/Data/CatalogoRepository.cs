using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>Consultas de catalogo: variedades, etapas del beneficiado y certificaciones.</summary>
public interface ICatalogoRepository
{
    Task<CatalogoViewModel> ObtenerCatalogoAsync(CancellationToken ct = default);
}

/// <inheritdoc cref="ICatalogoRepository"/>
public sealed class CatalogoRepository : ICatalogoRepository
{
    private readonly IDbConnectionFactory _fabrica;

    public CatalogoRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    // Tres consultas en un solo viaje:
    //  1. Cada variedad con sus cifras. Se usan subconsultas escalares en lugar de
    //     JOIN + GROUP BY para que los conteos no se inflen al cruzar parcelas y lotes.
    //  2. Las 7 etapas del beneficiado con la duracion real observada.
    //  3. Parcelas y lotes agrupados por certificacion.
    private const string Sql = """
        SELECT v.id_variedad  AS id_variedad,
               v.nombre       AS nombre,
               v.descripcion  AS descripcion,
               v.activa       AS activa,
               (SELECT COUNT(*)
                  FROM Parcelas pa WHERE pa.id_variedad = v.id_variedad)          AS parcelas,
               (SELECT COUNT(DISTINCT pa.id_productor)
                  FROM Parcelas pa WHERE pa.id_variedad = v.id_variedad)          AS productores,
               (SELECT COALESCE(SUM(pa.area_manzanas), 0)
                  FROM Parcelas pa WHERE pa.id_variedad = v.id_variedad)          AS area_manzanas,
               (SELECT MIN(pa.altitud_metros)
                  FROM Parcelas pa WHERE pa.id_variedad = v.id_variedad)          AS altitud_min,
               (SELECT MAX(pa.altitud_metros)
                  FROM Parcelas pa WHERE pa.id_variedad = v.id_variedad)          AS altitud_max,
               (SELECT COUNT(*)
                  FROM Lotes l
                  JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
                  JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
                 WHERE pa.id_variedad = v.id_variedad)                            AS lotes,
               (SELECT COALESCE(SUM(l.peso_actual_quintales), 0)
                  FROM Lotes l
                  JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
                  JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
                 WHERE pa.id_variedad = v.id_variedad)                            AS quintales,
               (SELECT ROUND(AVG(ca.puntaje_sca), 2)
                  FROM Calidad ca
                  JOIN Lotes    l  ON l.id_lote     = ca.id_lote
                  JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
                  JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
                 WHERE pa.id_variedad = v.id_variedad)                            AS sca_promedio
          FROM Variedades v
         ORDER BY v.nombre;

        SELECT e.id_etapa            AS id_etapa,
               e.orden               AS orden,
               e.nombre              AS nombre,
               e.descripcion         AS descripcion,
               e.duracion_min_horas  AS duracion_min_horas,
               e.duracion_max_horas  AS duracion_max_horas,
               COUNT(pr.id_proceso)  AS procesos_registrados,
               ROUND(AVG(TIMESTAMPDIFF(MINUTE, pr.fecha_inicio, pr.fecha_fin)) / 60, 1)
                                     AS horas_promedio
          FROM EtapasProceso e
          LEFT JOIN Procesos pr
                 ON pr.id_etapa = e.id_etapa
                AND pr.fecha_fin IS NOT NULL
         GROUP BY e.id_etapa, e.orden, e.nombre, e.descripcion,
                  e.duracion_min_horas, e.duracion_max_horas
         ORDER BY e.orden;

        SELECT pa.certificacion                        AS certificacion,
               COUNT(*)                                AS parcelas,
               COALESCE(SUM(pa.area_manzanas), 0)      AS area_manzanas,
               (SELECT COUNT(*)
                  FROM Lotes l
                 WHERE l.certificacion_aplicable = pa.certificacion) AS lotes
          FROM Parcelas pa
         GROUP BY pa.certificacion
         ORDER BY parcelas DESC, pa.certificacion;
        """;

    public async Task<CatalogoViewModel> ObtenerCatalogoAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        using var resultados = await conexion.QueryMultipleAsync(
            new CommandDefinition(Sql, cancellationToken: ct));

        return new CatalogoViewModel
        {
            Variedades = (await resultados.ReadAsync<VariedadFicha>()).AsList(),
            Etapas = (await resultados.ReadAsync<EtapaFicha>()).AsList(),
            Certificaciones = (await resultados.ReadAsync<CertificacionResumen>()).AsList()
        };
    }
}
