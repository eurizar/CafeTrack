using System.Data;
using Dapper;

namespace CafeTrack.Web.Data;

/// <summary>
/// Configuracion global de Dapper. Se invoca una sola vez al arrancar la aplicacion.
/// </summary>
public static class DapperConfiguracion
{
    public static void Aplicar()
    {
        // id_productor -> IdProductor, peso_actual_quintales -> PesoActualQuintales, etc.
        DefaultTypeMap.MatchNamesWithUnderscores = true;

        // MySqlConnector devuelve las columnas DATE como DateTime; estos manejadores
        // permiten mapearlas a DateOnly en los POCO.
        SqlMapper.AddTypeHandler(new DateOnlyTypeHandler());
        SqlMapper.AddTypeHandler(new DateOnlyNullableTypeHandler());
    }
}

/// <summary>Convierte DATE de MySQL a <see cref="DateOnly"/> y viceversa.</summary>
public sealed class DateOnlyTypeHandler : SqlMapper.TypeHandler<DateOnly>
{
    public override DateOnly Parse(object value) => value switch
    {
        DateOnly d => d,
        DateTime dt => DateOnly.FromDateTime(dt),
        string s => DateOnly.Parse(s),
        _ => throw new InvalidCastException($"No se puede convertir '{value}' a DateOnly.")
    };

    public override void SetValue(IDbDataParameter parameter, DateOnly value)
    {
        parameter.DbType = DbType.Date;
        parameter.Value = value.ToDateTime(TimeOnly.MinValue);
    }
}

/// <summary>Version anulable de <see cref="DateOnlyTypeHandler"/>.</summary>
public sealed class DateOnlyNullableTypeHandler : SqlMapper.TypeHandler<DateOnly?>
{
    public override DateOnly? Parse(object? value) => value switch
    {
        null or DBNull => null,
        DateOnly d => d,
        DateTime dt => DateOnly.FromDateTime(dt),
        string s => DateOnly.Parse(s),
        _ => throw new InvalidCastException($"No se puede convertir '{value}' a DateOnly?.")
    };

    public override void SetValue(IDbDataParameter parameter, DateOnly? value)
    {
        parameter.DbType = DbType.Date;
        parameter.Value = value?.ToDateTime(TimeOnly.MinValue) ?? (object)DBNull.Value;
    }
}
