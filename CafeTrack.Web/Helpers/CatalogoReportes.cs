namespace CafeTrack.Web.Helpers;

/// <summary>
/// Un reporte: la pregunta que responde y la vista de MySQL
/// que la resuelve.
/// </summary>
/// <param name="Clave">Identificador en la URL, por ejemplo "existencias".</param>
/// <param name="Titulo">Nombre del reporte.</param>
/// <param name="Pregunta">Qué responde, en lenguaje llano.</param>
/// <param name="Vista">Nombre de la vista en la base.</param>
/// <param name="Icono">Icono del catálogo de <c>_Icono.cshtml</c>.</param>
public record Reporte(string Clave, string Titulo, string Pregunta, string Vista, string Icono);

/// <summary>
/// Las 11 consultas del proyecto. La lista es fija y vive en el código:
/// el nombre de la vista nunca llega desde la URL, solo su clave, de modo
/// que no hay forma de inyectar un nombre de objeto en el SQL.
/// </summary>
public static class CatalogoReportes
{
    public static readonly IReadOnlyList<Reporte> Todos =
    [
        new("existencias", "Existencias en bodega",
            "¿Cuánto café hay hoy en cada bodega, lote por lote?",
            "vw_existencias_bodega", "bodega"),

        new("trazabilidad", "Trazabilidad por lote",
            "La historia completa de cada lote, de la parcela al estado actual.",
            "vw_trazabilidad_lote", "costal"),

        new("produccion", "Producción por productor",
            "¿Cuánto entregó cada socio y cuánto se le ha pagado?",
            "vw_produccion_productor", "productores"),

        new("mermas", "Mermas por lote y etapa",
            "¿Dónde se está perdiendo el café y cuánto?",
            "vw_mermas_lote", "bascula"),

        new("calidad", "Calidad de los lotes",
            "Puntajes SCA, altura de taza y resultado de cada catación.",
            "vw_calidad_lotes", "taza"),

        new("ventas", "Detalle de ventas",
            "Cada venta con su comprador y cómo quedó frente al precio base.",
            "vw_ventas_detalle", "quetzal"),

        new("temporadas", "Ventas por temporada",
            "¿Cómo le fue a la cooperativa en cada ciclo?",
            "vw_ventas_temporada", "reloj"),

        new("pagos", "Pagos a productores",
            "Cuánto recibió cada socio por cada venta y qué parte del ingreso representa.",
            "vw_pagos_productor", "pago"),

        new("variedades", "Rendimiento por variedad",
            "¿Qué variedad rinde mejor y cuál se cotiza más alto?",
            "vw_rendimiento_variedad", "brote"),

        new("tiempos", "Tiempos del beneficiado",
            "¿Cada etapa se cumplió dentro del rango esperado?",
            "vw_tiempos_beneficiado", "beneficio"),

        new("alertas", "Alertas de auditoría",
            "¿Qué se salió de lo normal? Mermas altas y ventas bajo el precio base.",
            "vw_alertas_auditoria", "certificado")
    ];

    /// <summary>Busca un reporte por su clave; null si no existe.</summary>
    public static Reporte? Buscar(string? clave) =>
        Todos.FirstOrDefault(r => string.Equals(r.Clave, clave, StringComparison.OrdinalIgnoreCase));
}
