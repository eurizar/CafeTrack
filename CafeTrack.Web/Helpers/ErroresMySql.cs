using MySqlConnector;

namespace CafeTrack.Web.Helpers;

/// <summary>
/// Traduce los errores de MySQL a mensajes que puede leer el usuario.
/// Las reglas de negocio viven en la base (SIGNAL, CHECK y los GRANT por rol),
/// asi que la aplicacion muestra lo que la base responde en lugar de duplicar
/// esas validaciones en C#.
/// </summary>
public static class ErroresMySql
{
    /// <summary>Error que genera un SIGNAL SQLSTATE '45000' dentro de una rutina.</summary>
    public const int SignalReglaNegocio = 1644;

    /// <summary>Restriccion CHECK violada (MySQL 8+).</summary>
    public const int CheckViolado = 3819;

    /// <summary>El usuario de MySQL no tiene permiso sobre la tabla (ERROR 1142).</summary>
    public const int PermisoDenegado = 1142;

    /// <summary>Devuelve el mensaje que se muestra en pantalla.</summary>
    public static string Traducir(MySqlException ex) => ex.Number switch
    {
        // El mensaje del SIGNAL ya viene redactado en espanol desde la rutina.
        SignalReglaNegocio => ex.Message,

        CheckViolado =>
            "El dato no cumple una restriccion de la base: " + DetalleCheck(ex.Message),

        PermisoDenegado =>
            "Su usuario no tiene permiso para realizar esta operacion sobre esa tabla.",

        1062 => "Ya existe un registro con ese valor unico (por ejemplo, el codigo de lote).",
        1451 or 1452 => "El dato referenciado no existe o esta en uso por otro registro.",
        1264 => "Un valor numerico quedo fuera del rango permitido por la columna.",
        1406 => "Un texto excede el largo permitido por la columna.",
        1216 or 1217 => "No se puede completar la operacion por una relacion con otra tabla.",
        1305 => "La rutina no existe en la base. Ejecute sql/04_rutinas.sql.",
        1045 => "Credenciales de MySQL incorrectas.",
        1049 => "No existe la base trazabilidad_cafe.",
        0 or 1042 or 1043 => "No hay conexion con el servidor MySQL.",
        _ => "No se pudo completar la operacion (MySQL error " + ex.Number + ")."
    };

    /// <summary>Extrae el nombre de la restriccion CHECK del mensaje crudo de MySQL.</summary>
    private static string DetalleCheck(string mensaje)
    {
        // Mensaje tipico: Check constraint 'chk_aco_peso' is violated.
        var inicio = mensaje.IndexOf('\'');
        var fin = inicio >= 0 ? mensaje.IndexOf('\'', inicio + 1) : -1;
        if (inicio < 0 || fin < 0)
        {
            return mensaje;
        }

        var nombre = mensaje[(inicio + 1)..fin];
        return nombre switch
        {
            "chk_aco_peso" => "el peso recibido debe ser mayor que cero.",
            "chk_ven_peso" => "la cantidad vendida debe ser mayor que cero.",
            "chk_ven_precio" => "el precio por quintal debe ser mayor que cero.",
            "chk_mov_cantidad" => "la cantidad del movimiento debe ser mayor que cero.",
            "chk_mer_peso" => "el peso perdido debe ser mayor que cero.",
            "chk_mer_pct" => "el porcentaje de merma debe estar entre 0 y 100.",
            "chk_cal_sca" => "el puntaje SCA debe estar entre 0 y 100.",
            "chk_pag_monto" => "el monto pagado debe ser mayor que cero.",
            "chk_pag_deduc" => "las deducciones no pueden superar el monto pagado.",
            "chk_cos_humedad" => "la humedad debe estar entre 0 y 100.",
            "chk_par_altitud" => "la altitud debe estar entre 0 y 4300 metros.",
            _ => $"no se cumple la restriccion {nombre}."
        };
    }
}
