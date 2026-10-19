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

    /// <summary>
    /// Convierte el JSON de la bitacora en texto legible:
    /// {"evento":"inicio de sesion"} -> "evento: inicio de sesion".
    /// </summary>
    public static string Json(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return "—";
        }

        try
        {
            using var documento = System.Text.Json.JsonDocument.Parse(json);
            if (documento.RootElement.ValueKind != System.Text.Json.JsonValueKind.Object)
            {
                return json;
            }

            var partes = documento.RootElement.EnumerateObject()
                .Select(p => $"{p.Name.Replace('_', ' ')}: {p.Value}");

            return string.Join("  ·  ", partes);
        }
        catch (System.Text.Json.JsonException)
        {
            // Si no es JSON valido se muestra tal cual vino de la base.
            return json;
        }
    }

    /// <summary>
    /// Encabezado legible para una columna de un reporte:
    /// peso_bruto_quintales -> "Peso bruto quintales".
    /// </summary>
    public static string Encabezado(string columna)
    {
        if (string.IsNullOrWhiteSpace(columna))
        {
            return string.Empty;
        }

        var texto = columna.Replace('_', ' ').Trim();
        texto = char.ToUpper(texto[0], CulturaGt) + texto[1..];

        // Siglas y unidades que no deben quedar en minuscula.
        return texto
            .Replace(" sca", " SCA", StringComparison.OrdinalIgnoreCase)
            .Replace("Sca ", "SCA ", StringComparison.Ordinal)
            .Replace(" quintales", " (qq)", StringComparison.OrdinalIgnoreCase)
            .Replace("Porcentaje", "%", StringComparison.Ordinal);
    }

    /// <summary>
    /// Da formato al valor de una celda de reporte segun su tipo y el nombre
    /// de la columna, que es lo unico que se conoce de una vista generica.
    /// </summary>
    public static string Celda(string columna, object? valor)
    {
        if (valor is null or DBNull)
        {
            return "—";
        }

        var nombre = columna.ToLowerInvariant();

        return valor switch
        {
            bool b => b ? "Sí" : "No",
            DateTime f => f.TimeOfDay == TimeSpan.Zero ? Fecha(f) : FechaHora(f),
            DateOnly d => Fecha(d),
            decimal n when EsMoneda(nombre) => Moneda(n),
            decimal n when nombre.Contains("porcentaje") => Porcentaje(n, 2),
            decimal n => Numero(n),
            double n => Numero((decimal)n),
            float n => Numero((decimal)n),
            // Los anios se escriben enteros: 2026, no 2,026.
            long e when EsAnio(nombre) => e.ToString(CulturaGt),
            int e when EsAnio(nombre) => e.ToString(CulturaGt),
            long e => e.ToString("N0", CulturaGt),
            int e => e.ToString("N0", CulturaGt),
            _ => Enum(valor.ToString())
        };
    }

    /// <summary>
    /// Desarma el JSON de la bitacora en pares clave/valor, ya con la clave
    /// legible y el valor con formato. Si no es un objeto JSON, devuelve una
    /// sola pareja con el texto tal cual vino.
    /// </summary>
    public static IReadOnlyList<(string Clave, string Valor)> JsonPares(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return [];
        }

        try
        {
            using var documento = System.Text.Json.JsonDocument.Parse(json);

            if (documento.RootElement.ValueKind != System.Text.Json.JsonValueKind.Object)
            {
                return [("valor", json)];
            }

            return documento.RootElement.EnumerateObject()
                .Select(p => (Encabezado(p.Name), ValorJson(p.Name, p.Value)))
                .ToList();
        }
        catch (System.Text.Json.JsonException)
        {
            return [("valor", json)];
        }
    }

    /// <summary>Da formato al valor de una propiedad del JSON.</summary>
    private static string ValorJson(string clave, System.Text.Json.JsonElement valor) =>
        valor.ValueKind switch
        {
            System.Text.Json.JsonValueKind.Number when valor.TryGetDecimal(out var n) =>
                Celda(clave, n),
            System.Text.Json.JsonValueKind.True => "Sí",
            System.Text.Json.JsonValueKind.False => "No",
            System.Text.Json.JsonValueKind.Null => "—",
            _ => Enum(valor.ToString())
        };

    /// <summary>
    /// Columnas cuyo total tiene sentido: pesos y dinero. Un precio, un
    /// porcentaje o una altitud no se suman, se promedian, asi que quedan fuera.
    /// </summary>
    public static bool EsSumable(string columna)
    {
        var nombre = columna.ToLowerInvariant();

        if (nombre.Contains("precio") || nombre.Contains("porcentaje") ||
            nombre.Contains("altitud") || nombre.Contains("promedio") ||
            nombre.Contains("sca") || nombre.Contains("diferencia") ||
            nombre.Contains("horas") || nombre.Contains("minimo") ||
            nombre.Contains("maximo") || nombre.Contains("capacidad"))
        {
            return false;
        }

        return nombre.Contains("quintales") || nombre.Contains("total") ||
               nombre.Contains("monto") || nombre.Contains("ingreso") ||
               nombre.Contains("pagado") || nombre.Contains("deduccion") ||
               nombre.Contains("area_manzanas") || nombre.Contains("entradas") ||
               nombre.Contains("salidas");
    }

    /// <summary>Columnas que llevan un ano y no deben llevar separador de miles.</summary>
    private static bool EsAnio(string nombre) =>
        nombre is "temporada" or "anio" or "ano" || nombre.EndsWith("_anio");

    /// <summary>Columnas que se muestran como quetzales.</summary>
    private static bool EsMoneda(string nombre) =>
        nombre.Contains("precio") || nombre.Contains("total") || nombre.Contains("monto") ||
        nombre.Contains("ingreso") || nombre.Contains("pagado") || nombre.Contains("deduccion") ||
        nombre.Contains("diferencia_vs_base");

    /// <summary>Indica si la celda se alinea a la derecha.</summary>
    public static bool EsNumerica(object? valor) =>
        valor is decimal or double or float or int or long or short;

    /// <summary>Columnas que se pintan como etiqueta de color.</summary>
    public static string? ClaseCelda(string columna, object? valor)
    {
        if (valor is null)
        {
            return null;
        }

        var texto = valor.ToString();
        return columna.ToLowerInvariant() switch
        {
            "estado_lote" => ClaseEstadoLote(texto),
            "resultado" or "resultado_catacion" =>
                texto == "Aprobado" ? "bodega" : "rechazado",
            "clasificacion" => texto switch
            {
                "Alta" => "rechazado",
                "Media" => "acopio",
                _ => "bodega"
            },
            "cumplimiento" => texto switch
            {
                "Dentro del rango" => "bodega",
                "En curso" => "acopio",
                _ => "rechazado"
            },
            "categoria" => texto == "Bajo el minimo" ? "rechazado" : "bodega",
            "alerta" => texto == "ALERTA_MERMA_ALTA" ? "acopio" : "rechazado",
            "estado" => texto == "Activo" ? "bodega" : "neutro",
            "estado_pago" => texto == "Pagado" ? "bodega" : "acopio",
            "certificacion" => ClaseCertificacion(texto),
            _ => null
        };
    }

    /// <summary>Sufijo de clase CSS para la etiqueta de certificacion.</summary>
    public static string ClaseCertificacion(string? certificacion) =>
        certificacion is null or "Ninguna" ? "neutro" : "certificada";
}
