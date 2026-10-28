using CafeTrack.Web.Helpers;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>Resultado de un reporte: sus columnas y sus filas.</summary>
public sealed class ResultadoReporte
{
    public IReadOnlyList<string> Columnas { get; init; } = [];
    public IReadOnlyList<IDictionary<string, object?>> Filas { get; init; } = [];
    public bool Truncado { get; init; }
}

/// <summary>
/// Lee los reportes. Cada uno es un SELECT sobre una vista:
/// el SQL vive en la base (sql/07_vistas.sql), no en C#.
/// </summary>
public interface IReporteRepository
{
    Task<ResultadoReporte> EjecutarAsync(Reporte reporte, CancellationToken ct = default);
}

/// <inheritdoc cref="IReporteRepository"/>
public sealed class ReporteRepository : IReporteRepository
{
    /// <summary>Tope de filas que se traen a la pantalla.</summary>
    private const int MaximoFilas = 500;

    private readonly IDbConnectionFactory _fabrica;

    public ReporteRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    // Las columnas se piden al catalogo del motor para que el reporte muestre
    // su encabezado aunque la vista venga vacia.
    private const string SqlColumnas = """
        SELECT COLUMN_NAME
          FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = @vista
         ORDER BY ORDINAL_POSITION;
        """;

    public async Task<ResultadoReporte> EjecutarAsync(
        Reporte reporte, CancellationToken ct = default)
    {
        // El nombre de la vista sale del catalogo interno, nunca de la URL.
        var vista = reporte.Vista;
        if (!CatalogoReportes.Todos.Any(r => r.Vista == vista))
        {
            throw new InvalidOperationException($"Reporte no reconocido: {vista}");
        }

        await using var conexion = await _fabrica.CrearConexionAsync(ct);

        var columnas = (await conexion.QueryAsync<string>(
            new CommandDefinition(SqlColumnas, new { vista }, cancellationToken: ct))).AsList();

        var filas = (await conexion.QueryAsync(
                new CommandDefinition($"SELECT * FROM {vista} LIMIT {MaximoFilas + 1};",
                    cancellationToken: ct)))
            .Cast<IDictionary<string, object?>>()
            .ToList();

        var truncado = filas.Count > MaximoFilas;
        if (truncado)
        {
            filas.RemoveAt(filas.Count - 1);
        }

        return new ResultadoReporte
        {
            Columnas = columnas.Count > 0
                ? columnas
                : filas.FirstOrDefault()?.Keys.ToList() ?? [],
            Filas = filas,
            Truncado = truncado
        };
    }
}
