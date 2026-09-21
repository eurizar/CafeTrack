using CafeTrack.Web.Models;
using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>Consultas de solo lectura sobre lotes y su trazabilidad.</summary>
public interface ILoteRepository
{
    /// <summary>Lista los lotes con filtros opcionales por estado y temporada.</summary>
    Task<IReadOnlyList<LoteFila>> ListarAsync(
        string? estado, int? anio, string? busqueda, CancellationToken ct = default);

    /// <summary>Anios de temporada disponibles, para el filtro de la pantalla de lotes.</summary>
    Task<IReadOnlyList<int>> ListarAniosTemporadaAsync(CancellationToken ct = default);

    /// <summary>
    /// Trazabilidad completa de un lote a partir de su codigo.
    /// Devuelve null si el codigo no existe.
    /// </summary>
    Task<LoteDetalleViewModel?> ObtenerDetalleAsync(string codigo, CancellationToken ct = default);
}

/// <inheritdoc cref="ILoteRepository"/>
public sealed class LoteRepository : ILoteRepository
{
    private readonly IDbConnectionFactory _fabrica;

    public LoteRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    /// <summary>Estados posibles del lote, en el orden logico del proceso.</summary>
    public static readonly string[] EstadosLote =
        ["En acopio", "En proceso", "En bodega", "Vendido", "Rechazado"];

    // Lote + cosecha + parcela + productor + variedad + temporada.
    // Los tres filtros son opcionales: si el parametro es NULL no restringe.
    private const string SqlListar = """
        SELECT l.id_lote                  AS id_lote,
               l.codigo_lote              AS codigo_lote,
               p.nombre                   AS productor,
               p.comunidad                AS comunidad,
               v.nombre                   AS variedad,
               t.anio                     AS anio,
               c.fecha_recoleccion        AS fecha_recoleccion,
               l.peso_inicial_quintales   AS peso_inicial_quintales,
               l.peso_actual_quintales    AS peso_actual_quintales,
               l.estado_lote              AS estado_lote,
               l.certificacion_aplicable  AS certificacion_aplicable
          FROM Lotes       l
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
          JOIN Variedades  v  ON v.id_variedad  = pa.id_variedad
          JOIN Temporadas  t  ON t.id_temporada = c.id_temporada
         WHERE (@estado IS NULL OR l.estado_lote = @estado)
           AND (@anio   IS NULL OR t.anio        = @anio)
           AND (@busqueda IS NULL
                OR l.codigo_lote LIKE CONCAT('%', @busqueda, '%')
                OR p.nombre      LIKE CONCAT('%', @busqueda, '%')
                OR p.comunidad   LIKE CONCAT('%', @busqueda, '%'))
         ORDER BY t.anio DESC, l.codigo_lote;
        """;

    private const string SqlAnios = """
        SELECT t.anio FROM Temporadas t ORDER BY t.anio DESC;
        """;

    // Trazabilidad del lote en un solo viaje: encabezado, acopio, etapas, calidad,
    // mermas, movimientos de bodega, ventas y pagos.
    private const string SqlDetalle = """
        SELECT l.id_lote                  AS id_lote,
               l.codigo_lote              AS codigo_lote,
               l.fecha_creacion           AS fecha_creacion,
               l.peso_inicial_quintales   AS peso_inicial_quintales,
               l.peso_actual_quintales    AS peso_actual_quintales,
               l.estado_lote              AS estado_lote,
               l.certificacion_aplicable  AS certificacion_aplicable,
               c.id_cosecha               AS id_cosecha,
               c.fecha_recoleccion        AS fecha_recoleccion,
               c.peso_bruto_quintales     AS peso_bruto_quintales,
               c.peso_bruto_kg            AS peso_bruto_kg,
               c.humedad_porcentaje       AS humedad_porcentaje,
               c.recolector               AS recolector,
               c.observaciones            AS observaciones_cosecha,
               pa.nombre                  AS parcela,
               pa.ubicacion               AS ubicacion_parcela,
               pa.altitud_metros          AS altitud_metros,
               pa.certificacion           AS certificacion_parcela,
               v.nombre                   AS variedad,
               p.id_productor             AS id_productor,
               p.nombre                   AS productor,
               p.comunidad                AS comunidad,
               t.anio                     AS anio,
               t.estado                   AS estado_temporada,
               t.precio_base_quintal      AS precio_base_quintal
          FROM Lotes       l
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
          JOIN Variedades  v  ON v.id_variedad  = pa.id_variedad
          JOIN Temporadas  t  ON t.id_temporada = c.id_temporada
         WHERE l.codigo_lote = @codigo;

        SELECT a.id_acopio, a.id_lote, a.fecha_recepcion, a.peso_recibido_quintales,
               a.responsable_recepcion, a.condicion_transporte, a.observaciones
          FROM Acopios a
          JOIN Lotes   l ON l.id_lote = a.id_lote
         WHERE l.codigo_lote = @codigo
         ORDER BY a.fecha_recepcion;

        SELECT e.id_etapa               AS id_etapa,
               e.orden                  AS orden,
               e.nombre                 AS nombre,
               e.descripcion            AS descripcion,
               e.duracion_min_horas     AS duracion_min_horas,
               e.duracion_max_horas     AS duracion_max_horas,
               pr.id_proceso            AS id_proceso,
               pr.fecha_inicio          AS fecha_inicio,
               pr.fecha_fin             AS fecha_fin,
               pr.peso_entrada_quintales AS peso_entrada_quintales,
               pr.peso_salida_quintales  AS peso_salida_quintales,
               pr.responsable           AS responsable
          FROM EtapasProceso e
          LEFT JOIN Procesos pr
                 ON pr.id_etapa = e.id_etapa
                AND pr.id_lote  = (SELECT id_lote FROM Lotes WHERE codigo_lote = @codigo)
         ORDER BY e.orden;

        SELECT ca.id_calidad, ca.id_lote, ca.fecha_evaluacion, ca.evaluador,
               ca.puntaje_sca, ca.altura_taza, ca.defectos_principales,
               ca.perfil_sensorial, ca.aprobado_venta
          FROM Calidad ca
          JOIN Lotes   l ON l.id_lote = ca.id_lote
         WHERE l.codigo_lote = @codigo
         ORDER BY ca.fecha_evaluacion DESC;

        SELECT m.id_merma, m.id_lote, m.tipo_merma, m.etapa_origen,
               m.peso_perdido_quintales, m.porcentaje_merma, m.fecha_registro,
               m.responsable, m.justificacion
          FROM Mermas m
          JOIN Lotes  l ON l.id_lote = m.id_lote
         WHERE l.codigo_lote = @codigo
         ORDER BY m.fecha_registro;

        SELECT mb.id_movimiento      AS id_movimiento,
               b.nombre              AS bodega,
               mb.tipo_movimiento    AS tipo_movimiento,
               mb.fecha_movimiento   AS fecha_movimiento,
               mb.cantidad_quintales AS cantidad_quintales,
               mb.responsable        AS responsable,
               mb.observaciones      AS observaciones
          FROM MovimientosBodega mb
          JOIN Bodegas b ON b.id_bodega = mb.id_bodega
          JOIN Lotes   l ON l.id_lote   = mb.id_lote
         WHERE l.codigo_lote = @codigo
         ORDER BY mb.fecha_movimiento, mb.id_movimiento;

        SELECT ve.id_venta               AS id_venta,
               ve.fecha_venta            AS fecha_venta,
               co.nombre                 AS comprador,
               co.tipo                   AS tipo_comprador,
               co.pais_destino           AS pais_destino,
               ve.peso_vendido_quintales AS peso_vendido_quintales,
               ve.precio_quintal         AS precio_quintal,
               ve.total_venta            AS total_venta,
               ve.forma_pago             AS forma_pago,
               ve.estado_pago            AS estado_pago
          FROM VentasLotes ve
          JOIN Compradores co ON co.id_comprador = ve.id_comprador
          JOIN Lotes       l  ON l.id_lote       = ve.id_lote
         WHERE l.codigo_lote = @codigo
         ORDER BY ve.fecha_venta;

        SELECT pg.id_pago               AS id_pago,
               pg.id_venta              AS id_venta,
               pg.fecha_pago            AS fecha_pago,
               p.nombre                 AS productor,
               pg.monto_pagado          AS monto_pagado,
               pg.precio_pagado_quintal AS precio_pagado_quintal,
               pg.deducciones           AS deducciones,
               pg.monto_neto            AS monto_neto,
               pg.metodo_pago           AS metodo_pago,
               pg.comprobante           AS comprobante
          FROM Pagos       pg
          JOIN Productores p  ON p.id_productor = pg.id_productor
          JOIN VentasLotes ve ON ve.id_venta    = pg.id_venta
          JOIN Lotes       l  ON l.id_lote      = ve.id_lote
         WHERE l.codigo_lote = @codigo
         ORDER BY pg.fecha_pago;
        """;

    public async Task<IReadOnlyList<LoteFila>> ListarAsync(
        string? estado, int? anio, string? busqueda, CancellationToken ct = default)
    {
        var parametros = new
        {
            estado = string.IsNullOrWhiteSpace(estado) ? null : estado,
            anio,
            busqueda = string.IsNullOrWhiteSpace(busqueda) ? null : busqueda.Trim()
        };

        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<LoteFila>(
            new CommandDefinition(SqlListar, parametros, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<int>> ListarAniosTemporadaAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var anios = await conexion.QueryAsync<int>(
            new CommandDefinition(SqlAnios, cancellationToken: ct));
        return anios.AsList();
    }

    public async Task<LoteDetalleViewModel?> ObtenerDetalleAsync(
        string codigo, CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        using var resultados = await conexion.QueryMultipleAsync(
            new CommandDefinition(SqlDetalle, new { codigo }, cancellationToken: ct));

        var encabezado = await resultados.ReadSingleOrDefaultAsync<LoteEncabezado>();
        if (encabezado is null)
        {
            return null;
        }

        var acopios = (await resultados.ReadAsync<Acopio>()).AsList();
        var etapas = (await resultados.ReadAsync<EtapaLinea>()).AsList();
        var calidades = (await resultados.ReadAsync<Calidad>()).AsList();
        var mermas = (await resultados.ReadAsync<Merma>()).AsList();
        var movimientos = (await resultados.ReadAsync<MovimientoFila>()).AsList();
        var ventas = (await resultados.ReadAsync<VentaFila>()).AsList();
        var pagos = (await resultados.ReadAsync<PagoFila>()).AsList();

        return new LoteDetalleViewModel
        {
            Lote = encabezado,
            Acopio = acopios.FirstOrDefault(),
            Etapas = etapas,
            Calidad = calidades.FirstOrDefault(),
            Mermas = mermas,
            Movimientos = movimientos,
            Ventas = ventas,
            Pagos = pagos
        };
    }
}
