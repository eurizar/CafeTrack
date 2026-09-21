using System.Globalization;

namespace CafeTrack.Web.Helpers;

/// <summary>
/// Helpers de presentacion: formato guatemalteco (es-GT) y traduccion de los valores
/// ENUM, que en la base estan escritos sin tildes tal como los define el script SQL.
/// </summary>
public static class Formato
{
    /// <summary>Cultura de Guatemala: fechas dd/MM/yyyy y moneda Q.</summary>
    public static readonly CultureInfo CulturaGt = CultureInfo.GetCultureInfo("es-GT");

    /// <summary>Fecha corta: 05/02/2026.</summary>
    public static string Fecha(DateTime? valor) =>
        valor?.ToString("dd/MM/yyyy", CulturaGt) ?? "—";

    /// <summary>Fecha corta a partir de un DATE.</summary>
    public static string Fecha(DateOnly? valor) =>
        valor?.ToString("dd/MM/yyyy", CulturaGt) ?? "—";

    /// <summary>Fecha y hora: 05/02/2026 14:30.</summary>
    public static string FechaHora(DateTime? valor) =>
        valor?.ToString("dd/MM/yyyy HH:mm", CulturaGt) ?? "—";

    /// <summary>Moneda en quetzales con dos decimales: Q 1,250.00.</summary>
    public static string Moneda(decimal? valor) =>
        valor is null ? "—" : "Q " + valor.Value.ToString("N2", CulturaGt);

    /// <summary>Cantidad en quintales con dos decimales.</summary>
    public static string Quintales(decimal? valor) =>
        valor is null ? "—" : valor.Value.ToString("N2", CulturaGt);

    /// <summary>Numero con la cantidad de decimales indicada.</summary>
    public static string Numero(decimal? valor, int decimales = 2) =>
        valor is null ? "—" : valor.Value.ToString("N" + decimales, CulturaGt);

    /// <summary>Porcentaje con un decimal: 62.5 %.</summary>
    public static string Porcentaje(decimal? valor, int decimales = 1) =>
        valor is null ? "—" : valor.Value.ToString("N" + decimales, CulturaGt) + " %";

    /// <summary>Texto libre o guion largo cuando viene vacio.</summary>
    public static string Texto(string? valor) =>
        string.IsNullOrWhiteSpace(valor) ? "—" : valor;

    /// <summary>
    /// Devuelve el ENUM con la ortografia correcta para mostrarlo en pantalla.
    /// La base conserva los valores sin tildes ('Organico', 'Credito 30 dias').
    /// </summary>
    public static string Enum(string? valor) => valor switch
    {
        null or "" => "—",
        "Organico" => "Orgánico",
        "Credito 30 dias" => "Crédito 30 días",
        "Credito 60 dias" => "Crédito 60 días",
        "Clasificacion" => "Clasificación",
        "Fermentacion" => "Fermentación",
        "Ajuste" => "Ajuste",
        _ => valor
    };

    /// <summary>Sufijo de clase CSS para la etiqueta de estado de un lote.</summary>
    public static string ClaseEstadoLote(string? estado) => estado switch
    {
        "En acopio" => "acopio",
        "En proceso" => "proceso",
        "En bodega" => "bodega",
        "Vendido" => "vendido",
        "Rechazado" => "rechazado",
        _ => "neutro"
    };

    /// <summary>Sufijo de clase CSS para la etiqueta de certificacion.</summary>
    public static string ClaseCertificacion(string? certificacion) =>
        certificacion is null or "Ninguna" ? "neutro" : "certificada";
}
