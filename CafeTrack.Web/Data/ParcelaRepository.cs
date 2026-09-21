using CafeTrack.Web.Models.ViewModels;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>Consultas de solo lectura sobre las parcelas registradas.</summary>
public interface IParcelaRepository
{
    /// <summary>Lista las parcelas con su productor y variedad; filtro opcional por texto.</summary>
    Task<IReadOnlyList<ParcelaFila>> ListarAsync(
        string? busqueda, string? certificacion, CancellationToken ct = default);

    /// <summary>Valores de certificacion presentes en las parcelas, para el filtro.</summary>
    Task<IReadOnlyList<string>> ListarCertificacionesAsync(CancellationToken ct = default);
}

/// <inheritdoc cref="IParcelaRepository"/>
public sealed class ParcelaRepository : IParcelaRepository
{
    private readonly IDbConnectionFactory _fabrica;

    public ParcelaRepository(IDbConnectionFactory fabrica) => _fabrica = fabrica;

    // Parcela + productor + variedad. Los filtros son opcionales (NULL = sin filtro).
    private const string SqlListar = """
        SELECT pa.id_parcela      AS id_parcela,
               pa.nombre          AS nombre,
               p.nombre           AS productor,
               p.comunidad        AS comunidad,
               v.nombre           AS variedad,
               pa.ubicacion       AS ubicacion,
               pa.area_manzanas   AS area_manzanas,
               pa.altitud_metros  AS altitud_metros,
               pa.certificacion   AS certificacion,
               pa.activa          AS activa
          FROM Parcelas    pa
          JOIN Productores p ON p.id_productor = pa.id_productor
          JOIN Variedades  v ON v.id_variedad  = pa.id_variedad
         WHERE (@busqueda IS NULL
                OR pa.nombre    LIKE CONCAT('%', @busqueda, '%')
                OR p.nombre     LIKE CONCAT('%', @busqueda, '%')
                OR p.comunidad  LIKE CONCAT('%', @busqueda, '%')
                OR v.nombre     LIKE CONCAT('%', @busqueda, '%'))
           AND (@certificacion IS NULL OR pa.certificacion = @certificacion)
         ORDER BY p.nombre, pa.nombre;
        """;

    private const string SqlCertificaciones = """
        SELECT DISTINCT pa.certificacion
          FROM Parcelas pa
         ORDER BY pa.certificacion;
        """;

    public async Task<IReadOnlyList<ParcelaFila>> ListarAsync(
        string? busqueda, string? certificacion, CancellationToken ct = default)
    {
        var parametros = new
        {
            busqueda = string.IsNullOrWhiteSpace(busqueda) ? null : busqueda.Trim(),
            certificacion = string.IsNullOrWhiteSpace(certificacion) ? null : certificacion
        };

        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var filas = await conexion.QueryAsync<ParcelaFila>(
            new CommandDefinition(SqlListar, parametros, cancellationToken: ct));
        return filas.AsList();
    }

    public async Task<IReadOnlyList<string>> ListarCertificacionesAsync(CancellationToken ct = default)
    {
        await using var conexion = await _fabrica.CrearConexionAsync(ct);
        var valores = await conexion.QueryAsync<string>(
            new CommandDefinition(SqlCertificaciones, cancellationToken: ct));
        return valores.AsList();
    }
}
