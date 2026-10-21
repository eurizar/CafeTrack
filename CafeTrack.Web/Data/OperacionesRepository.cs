using System.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models;
using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>
/// Operaciones de escritura de la Fase 2. Todas pasan por un procedimiento
/// almacenado: la aplicacion no arma INSERT propios para acopios ni ventas,
/// porque las reglas de negocio viven en la base.
/// </summary>
public interface IOperacionesRepository
{
    /// <summary>Lotes que todavia no tienen acopio registrado.</summary>
    Task<IReadOnlyList<LoteOpcion>> ListarLotesSinAcopioAsync(CancellationToken ct = default);

    /// <summary>Lotes con catacion aprobada y existencia disponible en bodega.</summary>
    Task<IReadOnlyList<LoteOpcion>> ListarLotesVendiblesAsync(CancellationToken ct = default);

    Task<IReadOnlyList<Comprador>> ListarCompradoresAsync(CancellationToken ct = default);
    Task<IReadOnlyList<Bodega>> ListarBodegasAsync(CancellationToken ct = default);

    /// <summary>Llama a sp_registrar_acopio y devuelve el id del acopio creado.</summary>
    Task<int> RegistrarAcopioAsync(AcopioForm datos, string usuario, CancellationToken ct = default);

    /// <summary>Llama a sp_registrar_venta y devuelve el id de la venta creada.</summary>
    Task<int> RegistrarVentaAsync(VentaForm datos, string usuario, CancellationToken ct = default);

    // --- Fase 2 ampliada: la cadena completa por rol ---

    /// <summary>Lotes esperando su proxima etapa del beneficiado.</summary>
    Task<IReadOnlyList<LoteEnProceso>> ListarLotesEnProcesoAsync(CancellationToken ct = default);

    /// <summary>Lotes que terminaron el beneficiado y no tienen catacion.</summary>
    Task<IReadOnlyList<LoteParaCatar>> ListarLotesParaCatarAsync(CancellationToken ct = default);

    /// <summary>Lotes aprobados con cafe pendiente de ingresar a bodega.</summary>
    Task<IReadOnlyList<LoteParaBodega>> ListarLotesParaBodegaAsync(CancellationToken ct = default);

    /// <summary>Ventas sin pago registrado.</summary>
    Task<IReadOnlyList<VentaSinPago>> ListarVentasSinPagoAsync(CancellationToken ct = default);

    Task<int> RegistrarProcesoAsync(ProcesoForm datos, string usuario, CancellationToken ct = default);
    Task<int> RegistrarCalidadAsync(CalidadForm datos, string usuario, CancellationToken ct = default);
    Task<int> RegistrarIngresoBodegaAsync(IngresoBodegaForm datos, string usuario, CancellationToken ct = default);
    Task<int> RegistrarPagoAsync(PagoForm datos, string usuario, CancellationToken ct = default);

    // --- Ventas, compradores y pagos ---

    /// <summary>Cuanto hay de cada lote en cada bodega, solo lo que queda.</summary>
    Task<IReadOnlyList<ExistenciaEnBodega>> ListarExistenciasPorBodegaAsync(CancellationToken ct = default);

    /// <summary>Compradores con lo que llevan comprado, activos e inactivos.</summary>
    Task<IReadOnlyList<CompradorResumen>> ListarCompradoresResumenAsync(CancellationToken ct = default);

    /// <summary>Llama a sp_crear_comprador y devuelve el id del comprador nuevo.</summary>
    Task<int> CrearCompradorAsync(CompradorForm datos, string usuario, CancellationToken ct = default);

    /// <summary>Pagos ya registrados, del mas reciente al mas viejo.</summary>
    Task<IReadOnlyList<PagoHecho>> ListarPagosAsync(CancellationToken ct = default);

    /// <summary>Bodegas activas con lo que tienen guardado y lo que les cabe.</summary>
    Task<IReadOnlyList<BodegaConEspacio>> ListarBodegasConEspacioAsync(CancellationToken ct = default);

    /// <summary>Llama a sp_trasladar_lote y devuelve el id del movimiento de entrada.</summary>
    Task<int> TrasladarLoteAsync(TrasladoForm datos, string usuario, CancellationToken ct = default);
}

/// <inheritdoc cref="IOperacionesRepository"/>
public sealed partial class OperacionesRepository : IOperacionesRepository
{
    private readonly IDbConnectionFactory _fabrica;
    private readonly IUsuarioActual _usuario;
    private readonly Ajustes _ajustes;

    public OperacionesRepository(
        IDbConnectionFactory fabrica, IUsuarioActual usuario, Ajustes ajustes)
    {
        _fabrica = fabrica;
        _usuario = usuario;
        _ajustes = ajustes;
    }

    // Lotes cosechados que aun no pasan por el centro de acopio.
    private const string SqlLotesSinAcopio = """
        SELECT l.id_lote                AS id_lote,
               l.codigo_lote            AS codigo_lote,
               p.nombre                 AS productor,
               v.nombre                 AS variedad,
               c.peso_bruto_quintales   AS peso_referencia
          FROM Lotes       l
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
          JOIN Variedades  v  ON v.id_variedad  = pa.id_variedad
         WHERE NOT EXISTS (SELECT 1 FROM Acopios a WHERE a.id_lote = l.id_lote)
         ORDER BY l.codigo_lote;
        """;

    // Lotes vendibles: catacion aprobada y existencia > 0.
    // La existencia se pide a la funcion fn_existencia_lote de la Fase 2.
    private const string SqlLotesVendibles = """
        SELECT l.id_lote                     AS id_lote,
               l.codigo_lote                 AS codigo_lote,
               p.nombre                      AS productor,
               v.nombre                      AS variedad,
               fn_existencia_lote(l.id_lote) AS peso_referencia,
               ca.puntaje_sca                AS puntaje_sca,
               ca.altura_taza                AS altura_taza,
               t.precio_base_quintal         AS precio_base,
               t.anio                        AS anio,
               (SELECT mb.id_bodega
                  FROM MovimientosBodega mb
                 WHERE mb.id_lote = l.id_lote AND mb.tipo_movimiento = 'Entrada'
                 ORDER BY mb.fecha_movimiento DESC LIMIT 1) AS id_bodega,
               (SELECT b.nombre
                  FROM MovimientosBodega mb
                  JOIN Bodegas b ON b.id_bodega = mb.id_bodega
                 WHERE mb.id_lote = l.id_lote AND mb.tipo_movimiento = 'Entrada'
                 ORDER BY mb.fecha_movimiento DESC LIMIT 1) AS bodega
          FROM Lotes       l
          JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
          JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
          JOIN Productores p  ON p.id_productor = pa.id_productor
          JOIN Variedades  v  ON v.id_variedad  = pa.id_variedad
          JOIN Temporadas  t  ON t.id_temporada = c.id_temporada
          JOIN Calidad     ca ON ca.id_lote     = l.id_lote
         WHERE ca.aprobado_venta = TRUE
           AND fn_existencia_lote(l.id_lote) > 0
         ORDER BY l.codigo_lote;
        """;

    private const string SqlCompradores = """
        SELECT id_comprador, nombre, tipo, pais_destino, contacto, telefono, activo
          FROM Compradores
         WHERE activo = TRUE
         ORDER BY nombre;
        """;

    private const string SqlBodegas = """
        SELECT id_bodega, nombre, ubicacion, capacidad_quintales, responsable, activa
          FROM Bodegas
         WHERE activa = TRUE
         ORDER BY nombre;
        """;

    public async Task<IReadOnlyList<LoteOpcion>> ListarLotesSinAcopioAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        var filas = await conexion.QueryAsync<LoteOpcion>(
            new CommandDefinition(SqlLotesSinAcopio, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<LoteOpcion>> ListarLotesVendiblesAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        var filas = await conexion.QueryAsync<LoteOpcion>(
            new CommandDefinition(SqlLotesVendibles, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<Comprador>> ListarCompradoresAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        var filas = await conexion.QueryAsync<Comprador>(
            new CommandDefinition(SqlCompradores, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<Bodega>> ListarBodegasAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        var filas = await conexion.QueryAsync<Bodega>(
            new CommandDefinition(SqlBodegas, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<int> RegistrarAcopioAsync(
        AcopioForm datos, string usuario, CancellationToken ct = default)
    {
        var parametros = new DynamicParameters();
        parametros.Add("p_id_lote", datos.IdLote);
        parametros.Add("p_peso_recibido", datos.PesoRecibido!.Value);
        parametros.Add("p_responsable", datos.Responsable);
        parametros.Add("p_condicion", datos.Condicion);
        parametros.Add("p_observaciones", datos.Observaciones);
        parametros.Add("p_usuario", usuario);
        parametros.Add("p_id_acopio", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        await conexion.ExecuteAsync(new CommandDefinition(
            "sp_registrar_acopio", parametros,
            commandType: CommandType.StoredProcedure, cancellationToken: ct));

        return parametros.Get<int?>("p_id_acopio") ?? 0;
    }

    public async Task<int> RegistrarVentaAsync(
        VentaForm datos, string usuario, CancellationToken ct = default)
    {
        var parametros = new DynamicParameters();
        parametros.Add("p_id_lote", datos.IdLote);
        parametros.Add("p_id_comprador", datos.IdComprador);
        parametros.Add("p_id_bodega", datos.IdBodega);
        parametros.Add("p_peso", datos.Peso!.Value);
        parametros.Add("p_precio", datos.Precio!.Value);
        parametros.Add("p_forma_pago", datos.FormaPago);
        parametros.Add("p_responsable", datos.Responsable);
        parametros.Add("p_usuario", usuario);
        parametros.Add("p_id_venta", dbType: DbType.Int32, direction: ParameterDirection.Output);

        await using var conexion = await _fabrica.CrearConexionAsync(_usuario.Rol, ct);
        await conexion.ExecuteAsync(new CommandDefinition(
            "sp_registrar_venta", parametros,
            commandType: CommandType.StoredProcedure, cancellationToken: ct));

        return parametros.Get<int?>("p_id_venta") ?? 0;
    }
}
