using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>Consultas de solo lectura sobre los productores de la cooperativa.</summary>
public interface IProductorRepository
{
    /// <summary>Lista los productores, filtrando por nombre o comunidad.</summary>
    Task<IReadOnlyList<ProductorFila>> ListarAsync(string? busqueda, CancellationToken ct = default);
}

/// <inheritdoc cref="IProductorRepository"/>
public sealed class ProductorRepository : IProductorRepository
{
    private readonly IDbConnectionFactory _fabrica;

    public ProductorRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    // Productores con el resumen de sus parcelas y lotes.
    // IMPORTANTE: no se selecciona documento_identidad (dato sensible).
    // El filtro es opcional: si @busqueda es NULL devuelve todos.
    private const string SqlListar = """
        SELECT p.id_productor                                AS id_productor,
               p.nombre                                      AS nombre,
               p.telefono                                    AS telefono,
               p.comunidad                                   AS comunidad,
               p.fecha_ingreso_coop                          AS fecha_ingreso_coop,
               p.activo                                      AS activo,
               COUNT(DISTINCT pa.id_parcela)                 AS total_parcelas,
               COUNT(DISTINCT l.id_lote)                     AS total_lotes,
               COALESCE(SUM(DISTINCT pa.area_manzanas), 0)   AS area_total_manzanas
          FROM Productores p
          LEFT JOIN Parcelas pa ON pa.id_productor = p.id_productor
          LEFT JOIN Cosechas c  ON c.id_parcela    = pa.id_parcela
          LEFT JOIN Lotes    l  ON l.id_cosecha    = c.id_cosecha
         WHERE (@busqueda IS NULL
                OR p.nombre    LIKE CONCAT('%', @busqueda, '%')
                OR p.comunidad LIKE CONCAT('%', @busqueda, '%'))
         GROUP BY p.id_productor, p.nombre, p.telefono, p.comunidad,
                  p.fecha_ingreso_coop, p.activo
         ORDER BY p.nombre;
        """;

    public async Task<IReadOnlyList<ProductorFila>> ListarAsync(
        string? busqueda, CancellationToken ct = default)
    {
        var filtro = string.IsNullOrWhiteSpace(busqueda) ? null : busqueda.Trim();

        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<ProductorFila>(
            new CommandDefinition(SqlListar, new { busqueda = filtro }, cancellationToken: ct));
        return filas.AsList();
    }
}
