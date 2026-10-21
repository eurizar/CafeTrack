using System.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>
/// Resto de la cadena de operación: beneficiado, catación, ingreso a bodega
/// y pago al productor. Cada uno llama a su procedimiento (sql/10_operacion.sql)
/// y es MySQL quien decide si el rol de la sesión puede ejecutarlo.
/// </summary>
public sealed partial class OperacionesRepository
{
    // La "próxima etapa" de un lote es la que quedó abierta o, si no hay
    // ninguna abierta, la que sigue en orden a la última cerrada.
    private const string SqlLotesEnProceso = """
        SELECT l.id_lote                 AS id_lote,
               l.codigo_lote             AS codigo_lote,
               p.nombre                  AS productor,
               l.peso_actual_quintales   AS peso_actual,
               e.id_etapa                AS id_etapa,
               e.nombre                  AS etapa,
               e.orden                   AS orden,
               e.duracion_min_horas      AS duracion_min_horas,
               e.duracion_max_horas      AS duracion_max_horas,
               (SELECT pr.fecha_inicio FROM Procesos pr
                 WHERE pr.id_lote = l.id_lote AND pr.id_etapa = e.id_etapa
                   AND pr.fecha_fin IS NULL LIMIT 1)              AS fecha_inicio,
               EXISTS (SELECT 1 FROM Procesos pr
                        WHERE pr.id_lote = l.id_lote AND pr.id_etapa = e.id_etapa
                          AND pr.fecha_fin IS NULL)               AS abierta
          FROM Lotes       l
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
          JOIN EtapasProceso e ON e.id_etapa = COALESCE(
                 (SELECT pr.id_etapa FROM Procesos pr
                   WHERE pr.id_lote = l.id_lote AND pr.fecha_fin IS NULL
                   ORDER BY pr.id_proceso LIMIT 1),
                 (SELECT e2.id_etapa FROM EtapasProceso e2
                   WHERE e2.orden = (SELECT COALESCE(MAX(e3.orden), 0) + 1
                                       FROM Procesos pr3
                                       JOIN EtapasProceso e3 ON e3.id_etapa = pr3.id_etapa
                                      WHERE pr3.id_lote = l.id_lote)))
         WHERE EXISTS (SELECT 1 FROM Acopios a WHERE a.id_lote = l.id_lote)
           AND l.estado_lote NOT IN ('Rechazado', 'Vendido')
           AND NOT EXISTS (SELECT 1 FROM Calidad ca WHERE ca.id_lote = l.id_lote)
         ORDER BY l.codigo_lote;
        """;

    // Terminó todas las etapas y todavía no lo cata nadie.
    private const string SqlLotesParaCatar = """
        SELECT l.id_lote               AS id_lote,
               l.codigo_lote           AS codigo_lote,
               p.nombre                AS productor,
               v.nombre                AS variedad,
               pa.altitud_metros       AS altitud_metros,
               l.peso_actual_quintales AS peso_actual
          FROM Lotes       l
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
          JOIN Variedades  v  ON v.id_variedad  = pa.id_variedad
         WHERE NOT EXISTS (SELECT 1 FROM Calidad ca WHERE ca.id_lote = l.id_lote)
           AND l.estado_lote NOT IN ('Rechazado', 'Vendido')
           AND (SELECT COUNT(*) FROM Procesos pr
                 WHERE pr.id_lote = l.id_lote AND pr.fecha_fin IS NOT NULL)
               >= (SELECT COUNT(*) FROM EtapasProceso)
         ORDER BY l.codigo_lote;
        """;

    // Aprobado en catación y con café que todavía no está en bodega.
    private const string SqlLotesParaBodega = """
        SELECT l.id_lote                     AS id_lote,
               l.codigo_lote                 AS codigo_lote,
               p.nombre                      AS productor,
               l.peso_actual_quintales       AS peso_actual,
               fn_existencia_lote(l.id_lote) AS en_bodega
          FROM Lotes       l
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
         WHERE EXISTS (SELECT 1 FROM Calidad ca
                        WHERE ca.id_lote = l.id_lote AND ca.aprobado_venta = TRUE)
           AND l.estado_lote <> 'Vendido'
           AND fn_existencia_lote(l.id_lote) < l.peso_actual_quintales
         ORDER BY l.codigo_lote;
        """;

    private const string SqlVentasSinPago = """
        SELECT ve.id_venta               AS id_venta,
               l.codigo_lote             AS codigo_lote,
               p.nombre                  AS productor,
               co.nombre                 AS comprador,
               ve.fecha_venta            AS fecha_venta,
               ve.peso_vendido_quintales AS peso_vendido,
               ve.precio_quintal         AS precio_venta,
               ve.total_venta            AS total_venta,
               ve.forma_pago             AS forma_pago,
               (SELECT b.nombre
                  FROM MovimientosBodega mb
                  JOIN Bodegas b ON b.id_bodega = mb.id_bodega
                 WHERE mb.id_venta = ve.id_venta LIMIT 1) AS bodega
          FROM VentasLotes ve
          JOIN Lotes       l  ON l.id_lote       = ve.id_lote
          JOIN Compradores co ON co.id_comprador = ve.id_comprador
          JOIN Cosechas    c  ON c.id_cosecha    = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela   = c.id_parcela
          JOIN Productores p  ON p.id_productor  = pa.id_productor
         WHERE NOT EXISTS (SELECT 1 FROM Pagos pg WHERE pg.id_venta = ve.id_venta)
         ORDER BY ve.fecha_venta DESC;
        """;

    public async Task<IReadOnlyList<LoteEnProceso>> ListarLotesEnProcesoAsync(
        CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<LoteEnProceso>(
            new CommandDefinition(SqlLotesEnProceso, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<LoteParaCatar>> ListarLotesParaCatarAsync(
        CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<LoteParaCatar>(
            new CommandDefinition(SqlLotesParaCatar, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<LoteParaBodega>> ListarLotesParaBodegaAsync(
        CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<LoteParaBodega>(
            new CommandDefinition(SqlLotesParaBodega, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<VentaSinPago>> ListarVentasSinPagoAsync(
        CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<VentaSinPago>(
            new CommandDefinition(SqlVentasSinPago, cancellationToken: ct));
        return filas.AsList();
    }

    public Task<int> RegistrarProcesoAsync(
        ProcesoForm datos, string usuario, CancellationToken ct = default)
    {
        var parametros = new DynamicParameters();
        parametros.Add("p_id_lote", datos.IdLote);
        parametros.Add("p_id_etapa", datos.IdEtapa);
        parametros.Add("p_fecha_inicio", datos.FechaInicio);
        parametros.Add("p_fecha_fin", datos.FechaFin);
        parametros.Add("p_peso_entrada", datos.PesoEntrada!.Value);
        parametros.Add("p_peso_salida", datos.PesoSalida);
        parametros.Add("p_responsable", datos.Responsable);
        parametros.Add("p_usuario", usuario);
        // Solo en modo demostración se aceptan fechas futuras.
        parametros.Add("p_permitir_futuras", _ajustes.PermitirFechasFuturas);
        parametros.Add("p_id_proceso", dbType: DbType.Int32, direction: ParameterDirection.Output);

        return LlamarAsync("sp_registrar_proceso", parametros, "p_id_proceso", ct);
    }

    public Task<int> RegistrarCalidadAsync(
        CalidadForm datos, string usuario, CancellationToken ct = default)
    {
        var parametros = new DynamicParameters();
        parametros.Add("p_id_lote", datos.IdLote);
        parametros.Add("p_evaluador", datos.Evaluador);
        parametros.Add("p_puntaje", datos.Puntaje!.Value);
        parametros.Add("p_altura", datos.Altura);
        parametros.Add("p_defectos", datos.Defectos);
        parametros.Add("p_perfil", datos.Perfil);
        parametros.Add("p_aprobado", datos.Aprobado!.Value);
        parametros.Add("p_usuario", usuario);
        parametros.Add("p_id_calidad", dbType: DbType.Int32, direction: ParameterDirection.Output);

        return LlamarAsync("sp_registrar_calidad", parametros, "p_id_calidad", ct);
    }

    public Task<int> RegistrarIngresoBodegaAsync(
        IngresoBodegaForm datos, string usuario, CancellationToken ct = default)
    {
        var parametros = new DynamicParameters();
        parametros.Add("p_id_lote", datos.IdLote);
        parametros.Add("p_id_bodega", datos.IdBodega);
        parametros.Add("p_cantidad", datos.Cantidad!.Value);
        parametros.Add("p_responsable", datos.Responsable);
        parametros.Add("p_usuario", usuario);
        parametros.Add("p_id_movimiento", dbType: DbType.Int32, direction: ParameterDirection.Output);

        return LlamarAsync("sp_registrar_ingreso_bodega", parametros, "p_id_movimiento", ct);
    }

    public Task<int> RegistrarPagoAsync(
        PagoForm datos, string usuario, CancellationToken ct = default)
    {
        var parametros = new DynamicParameters();
        parametros.Add("p_id_venta", datos.IdVenta);
        parametros.Add("p_precio", datos.Precio!.Value);
        parametros.Add("p_deducciones", datos.Deducciones ?? 0);
        parametros.Add("p_metodo", datos.Metodo);
        parametros.Add("p_comprobante", datos.Comprobante);
        parametros.Add("p_usuario", usuario);
        parametros.Add("p_id_pago", dbType: DbType.Int32, direction: ParameterDirection.Output);

        return LlamarAsync("sp_registrar_pago", parametros, "p_id_pago", ct);
    }

    /// <summary>Llama a un procedimiento y devuelve su parámetro de salida.</summary>
    private async Task<int> LlamarAsync(
        string rutina, DynamicParameters parametros, string salida, CancellationToken ct)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        await conexion.ExecuteAsync(new CommandDefinition(
            rutina, parametros, commandType: CommandType.StoredProcedure, cancellationToken: ct));

        return parametros.Get<int?>(salida) ?? 0;
    }
}
