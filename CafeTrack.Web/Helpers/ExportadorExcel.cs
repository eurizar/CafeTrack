using System.Globalization;
using System.IO.Compression;
using System.Text;

namespace CafeTrack.Web.Helpers;

/// <summary>
/// Arma un archivo .xlsx (Excel) a mano, sin librerías externas.
/// Un .xlsx es un ZIP con unos pocos XML dentro, así que basta
/// <see cref="ZipArchive"/>, que viene con .NET.
/// </summary>
public static class ExportadorExcel
{
    /// <summary>Tipo MIME de un libro de Excel.</summary>
    public const string TipoMime =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    // Estilos declarados en styles.xml, en el mismo orden.
    private const int EstiloTexto = 0;
    private const int EstiloEncabezado = 1;
    private const int EstiloNumero = 2;
    private const int EstiloMoneda = 3;
    private const int EstiloFecha = 4;
    private const int EstiloFechaHora = 5;

    /// <summary>
    /// Genera el libro con una hoja: la primera fila son los encabezados y
    /// el resto, los datos. Devuelve los bytes listos para descargar.
    /// </summary>
    public static byte[] Generar(
        string nombreHoja,
        IReadOnlyList<string> columnas,
        IReadOnlyList<IDictionary<string, object?>> filas)
    {
        using var memoria = new MemoryStream();

        using (var zip = new ZipArchive(memoria, ZipArchiveMode.Create, leaveOpen: true))
        {
            Escribir(zip, "[Content_Types].xml", ContentTypes);
            Escribir(zip, "_rels/.rels", RelacionesRaiz);
            Escribir(zip, "xl/workbook.xml", Libro(nombreHoja));
            Escribir(zip, "xl/_rels/workbook.xml.rels", RelacionesLibro);
            Escribir(zip, "xl/styles.xml", Estilos);
            Escribir(zip, "xl/worksheets/sheet1.xml", Hoja(columnas, filas));
        }

        return memoria.ToArray();
    }

    /// <summary>Nombre de archivo sugerido, con la fecha del día.</summary>
    public static string NombreArchivo(string clave) =>
        $"cafetrack-{clave}-{DateTime.Now:yyyyMMdd}.xlsx";

    private static void Escribir(ZipArchive zip, string ruta, string contenido)
    {
        var entrada = zip.CreateEntry(ruta, CompressionLevel.Optimal);
        using var flujo = entrada.Open();
        using var escritor = new StreamWriter(flujo, new UTF8Encoding(false));
        escritor.Write(contenido);
    }

    // ------------------------------------------------------------------ hoja

    private static string Hoja(
        IReadOnlyList<string> columnas,
        IReadOnlyList<IDictionary<string, object?>> filas)
    {
        var xml = new StringBuilder();
        xml.Append("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>""");
        xml.Append("""<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">""");

        // Ancho de columna estimado con el encabezado y las primeras filas.
        xml.Append("<cols>");
        for (var i = 0; i < columnas.Count; i++)
        {
            var ancho = Math.Clamp(AnchoSugerido(columnas[i], filas), 10, 40);
            xml.Append(CultureInfo.InvariantCulture,
                $"""<col min="{i + 1}" max="{i + 1}" width="{ancho}" customWidth="1"/>""");
        }
        xml.Append("</cols><sheetData>");

        // Fila 1: encabezados, en negrita.
        xml.Append("""<row r="1">""");
        for (var i = 0; i < columnas.Count; i++)
        {
            xml.Append(CeldaTexto(Referencia(i, 1), Formato.Encabezado(columnas[i]), EstiloEncabezado));
        }
        xml.Append("</row>");

        // Filas de datos.
        for (var f = 0; f < filas.Count; f++)
        {
            var numero = f + 2;
            xml.Append(CultureInfo.InvariantCulture, $"""<row r="{numero}">""");

            for (var i = 0; i < columnas.Count; i++)
            {
                var columna = columnas[i];
                filas[f].TryGetValue(columna, out var valor);
                xml.Append(Celda(Referencia(i, numero), columna, valor));
            }

            xml.Append("</row>");
        }

        xml.Append("</sheetData></worksheet>");
        return xml.ToString();
    }

    private static string Celda(string referencia, string columna, object? valor)
    {
        switch (valor)
        {
            case null or DBNull:
                return string.Empty;

            case bool b:
                return CeldaTexto(referencia, b ? "Sí" : "No", EstiloTexto);

            case DateTime f:
            {
                // Excel guarda las fechas como días desde el 30/12/1899.
                var serie = (f - new DateTime(1899, 12, 30)).TotalDays;
                var estilo = f.TimeOfDay == TimeSpan.Zero ? EstiloFecha : EstiloFechaHora;
                return CeldaNumero(referencia, serie, estilo);
            }

            case DateOnly d:
            {
                var serie = (d.ToDateTime(TimeOnly.MinValue) - new DateTime(1899, 12, 30)).TotalDays;
                return CeldaNumero(referencia, serie, EstiloFecha);
            }

            case decimal n:
                return CeldaNumero(referencia, (double)n, EstiloNumeroSegun(columna));

            case double n:
                return CeldaNumero(referencia, n, EstiloNumeroSegun(columna));

            case float n:
                return CeldaNumero(referencia, n, EstiloNumeroSegun(columna));

            case int e:
                return CeldaNumero(referencia, e, EstiloTexto);

            case long e:
                return CeldaNumero(referencia, e, EstiloTexto);

            default:
                return CeldaTexto(referencia, Formato.Enum(valor.ToString()), EstiloTexto);
        }
    }

    /// <summary>Las columnas de dinero se formatean con el símbolo Q.</summary>
    private static int EstiloNumeroSegun(string columna)
    {
        var nombre = columna.ToLowerInvariant();
        var esMoneda = nombre.Contains("precio") || nombre.Contains("total") ||
                       nombre.Contains("monto") || nombre.Contains("ingreso") ||
                       nombre.Contains("pagado") || nombre.Contains("deduccion") ||
                       nombre.Contains("diferencia_vs_base");
        return esMoneda ? EstiloMoneda : EstiloNumero;
    }

    private static string CeldaTexto(string referencia, string texto, int estilo) =>
        $"""<c r="{referencia}" s="{estilo}" t="inlineStr"><is><t xml:space="preserve">{Escapar(texto)}</t></is></c>""";

    private static string CeldaNumero(string referencia, double valor, int estilo) =>
        string.Create(CultureInfo.InvariantCulture,
            $"""<c r="{referencia}" s="{estilo}"><v>{valor:0.############}</v></c>""");

    /// <summary>Convierte (columna, fila) en referencia de Excel: A1, B2, AA3…</summary>
    private static string Referencia(int indiceColumna, int fila)
    {
        var letras = string.Empty;
        var n = indiceColumna;

        do
        {
            letras = (char)('A' + n % 26) + letras;
            n = n / 26 - 1;
        }
        while (n >= 0);

        return letras + fila.ToString(CultureInfo.InvariantCulture);
    }

    private static int AnchoSugerido(
        string columna, IReadOnlyList<IDictionary<string, object?>> filas)
    {
        var ancho = Formato.Encabezado(columna).Length + 2;

        foreach (var fila in filas.Take(40))
        {
            if (fila.TryGetValue(columna, out var valor) && valor is not null)
            {
                ancho = Math.Max(ancho, valor.ToString()?.Length + 2 ?? ancho);
            }
        }

        return ancho;
    }

    private static string Escapar(string texto) => texto
        .Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;");

    // -------------------------------------------------- partes fijas del libro

    private const string ContentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """;

    private const string RelacionesRaiz = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """;

    private const string RelacionesLibro = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """;

    private static string Libro(string nombreHoja) => $"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets><sheet name="{Escapar(Recortar(nombreHoja))}" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """;

    /// <summary>Excel no acepta nombres de hoja de más de 31 caracteres.</summary>
    private static string Recortar(string nombre)
    {
        var limpio = new string(nombre.Where(c => !"[]:*?/\\".Contains(c)).ToArray());
        return limpio.Length <= 31 ? limpio : limpio[..31];
    }

    private const string Estilos = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <numFmts count="3">
            <numFmt numFmtId="164" formatCode="&quot;Q&quot;\ #,##0.00"/>
            <numFmt numFmtId="165" formatCode="dd/mm/yyyy"/>
            <numFmt numFmtId="166" formatCode="dd/mm/yyyy\ hh:mm"/>
          </numFmts>
          <fonts count="2">
            <font><sz val="11"/><name val="Calibri"/></font>
            <font><b/><sz val="11"/><name val="Calibri"/></font>
          </fonts>
          <fills count="2">
            <fill><patternFill patternType="none"/></fill>
            <fill><patternFill patternType="gray125"/></fill>
          </fills>
          <borders count="1"><border/></borders>
          <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
          <cellXfs count="6">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
            <xf numFmtId="2" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
            <xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
            <xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
            <xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
          </cellXfs>
          <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
        </styleSheet>
        """;
}
