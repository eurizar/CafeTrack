using System.Data;
using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>
/// Consultas de la venta y del pago: donde esta guardado cada lote, quienes
/// compran y que se ha pagado. El alta de compradores pasa por
/// sp_crear_comprador (sql/11_ventas_pagos.sql).
/// </summary>
public sealed partial class OperacionesRepository
{
    // Existencia viva de cada lote en cada bodega. Lo que ya no esta, no sale.
    private const string SqlExistenciasPorBodega = """
        SELECT mb.id_lote    AS id_lote,
               l.codigo_lote AS codigo_lote,
               p.nombre      AS productor,
               mb.id_bodega  AS id_bodega,
               b.nombre      AS bodega,
               fn_existencia_lote_bodega(mb.id_lote, mb.id_bodega) AS cantidad
          FROM MovimientosBodega mb
          JOIN Bodegas     b  ON b.id_bodega    = mb.id_bodega
          JOIN Lotes       l  ON l.id_lote      = mb.id_lote
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
         GROUP BY mb.id_lote, l.codigo_lote, p.nombre, mb.id_bodega, b.nombre
        HAVING cantidad > 0
         ORDER BY l.codigo_lote, b.nombre;
        """;

    private const string SqlCompradoresResumen = """
        SELECT c.id_comprador AS id_comprador,
               c.nombre       AS nombre,
               c.tipo         AS tipo,
               c.pais_destino AS pais_destino,
               c.contacto     AS contacto,
               c.telefono     AS telefono,
               c.activo       AS activo,
               (SELECT COUNT(*) FROM VentasLotes v
                 WHERE v.id_comprador = c.id_comprador)       AS ventas,
               (SELECT COALESCE(SUM(v.total_venta), 0) FROM VentasLotes v
                 WHERE v.id_comprador = c.id_comprador)       AS total_comprado
          FROM Compradores c
         ORDER BY c.activo DESC, c.nombre;
        """;

    private const string SqlPagos = """
        SELECT pg.id_pago      AS id_pago,
               pg.id_venta     AS id_venta,
               l.codigo_lote   AS codigo_lote,
               p.nombre        AS productor,
               co.nombre       AS comprador,
               pg.fecha_pago   AS fecha_pago,
               pg.monto_pagado AS monto_pagado,
               pg.deducciones  AS deducciones,
               pg.monto_neto   AS monto_neto,
               pg.metodo_pago  AS metodo,
               pg.comprobante  AS comprobante
          FROM Pagos       pg
          JOIN VentasLotes ve ON ve.id_venta     = pg.id_venta
          JOIN Lotes       l  ON l.id_lote       = ve.id_lote
          JOIN Compradores co ON co.id_comprador = ve.id_comprador
          JOIN Productores p  ON p.id_productor  = pg.id_productor
         ORDER BY pg.fecha_pago DESC, pg.id_pago DESC;
        """;

    public async Task<IReadOnlyList<ExistenciaEnBodega>> ListarExistenciasPorBodegaAsync(
        CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        var filas = await conexion.QueryAsync<ExistenciaEnBodega>(
            new CommandDefinition(SqlExistenciasPorBodega, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<CompradorResumen>> ListarCompradoresResumenAsync(
        CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        var filas = await conexion.QueryAsync<CompradorResumen>(
            new CommandDefinition(SqlCompradoresResumen, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<PagoHecho>> ListarPagosAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        var filas = await conexion.QueryAsync<PagoHecho>(
            new CommandDefinition(SqlPagos, cancellationToken: ct));
        return filas.AsList();
    }

    // Lo guardado en cada bodega sale de los movimientos, no de una columna.
    private const string SqlBodegasConEspacio = """
        SELECT b.id_bodega           AS id_bodega,
               b.nombre              AS nombre,
               b.ubicacion           AS ubicacion,
               b.capacidad_quintales AS capacidad_quintales,
               COALESCE((SELECT SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                                         THEN mb.cantidad_quintales
                                         ELSE -mb.cantidad_quintales END)
                           FROM MovimientosBodega mb
                          WHERE mb.id_bodega = b.id_bodega), 0) AS guardado
          FROM Bodegas b
         WHERE b.activa = TRUE
         ORDER BY b.nombre;
        """;

    public async Task<IReadOnlyList<BodegaConEspacio>> ListarBodegasConEspacioAsync(
        CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        var filas = await conexion.QueryAsync<BodegaConEspacio>(
            new CommandDefinition(SqlBodegasConEspacio, cancellationToken: ct));
        return filas.AsList();
    }

    public Task<int> TrasladarLoteAsync(
        TrasladoForm datos, string usuario, CancellationToken ct = default)
    {
        var parametros = new DynamicParameters();
        parametros.Add("p_id_lote", datos.IdLote);
        parametros.Add("p_origen", datos.Origen);
        parametros.Add("p_destino", datos.Destino);
        parametros.Add("p_cantidad", datos.Cantidad!.Value);
        parametros.Add("p_responsable", datos.Responsable);
        parametros.Add("p_motivo", datos.Motivo);
        parametros.Add("p_usuario", usuario);
        parametros.Add("p_id_salida", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parametros.Add("p_id_entrada", dbType: DbType.Int32, direction: ParameterDirection.Output);

        return LlamarAsync("sp_trasladar_lote", parametros, "p_id_entrada", ct);
    }

    public Task<int> CrearCompradorAsync(
        CompradorForm datos, string usuario, CancellationToken ct = default)
    {
        var parametros = new DynamicParameters();
        parametros.Add("p_nombre", datos.Nombre);
        parametros.Add("p_tipo", datos.Tipo);
        parametros.Add("p_pais_destino", datos.PaisDestino);
        parametros.Add("p_contacto", datos.Contacto);
        parametros.Add("p_telefono", datos.Telefono);
        parametros.Add("p_usuario", usuario);
        parametros.Add("p_id_comprador", dbType: DbType.Int32, direction: ParameterDirection.Output);

        return LlamarAsync("sp_crear_comprador", parametros, "p_id_comprador", ct);
    }
}
