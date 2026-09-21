using System.Diagnostics;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages;

/// <summary>
/// Pagina de error amable. Nunca muestra la excepcion cruda: solo un mensaje
/// util y el identificador de la solicitud para buscarla en el registro.
/// </summary>
[ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
[IgnoreAntiforgeryToken]
public class ErrorModel : PageModel
{
    private readonly ILogger<ErrorModel> _log;

    public ErrorModel(ILogger<ErrorModel> log) => _log = log;

    public string? RequestId { get; private set; }
    public bool MostrarRequestId => !string.IsNullOrEmpty(RequestId);

    public string Titulo { get; private set; } = "Algo no salió bien";
    public string Mensaje { get; private set; } =
        "Ocurrió un problema al procesar la solicitud. Intente de nuevo en un momento.";
    public string? Detalle { get; private set; }

    public void OnGet(int? codigo)
    {
        RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier;

        var excepcion = HttpContext.Features.Get<IExceptionHandlerPathFeature>()?.Error;

        if (excepcion is MySqlException mysql)
        {
            // La base no responde o rechazo la conexion: se explica sin exponer la cadena.
            Titulo = "No hay conexión con la base de datos";
            Mensaje = "CaféTrack no pudo comunicarse con el servidor MySQL. " +
                      "Verifique que el servicio esté encendido y que el secreto " +
                      "ConnectionStrings:CafeTrack sea correcto.";
            Detalle = $"MySQL error {mysql.Number}.";
            _log.LogError(mysql, "Fallo de acceso a MySQL.");
            return;
        }

        if (excepcion is InvalidOperationException invalida &&
            invalida.Message.Contains("cadena de conexion", StringComparison.OrdinalIgnoreCase))
        {
            Titulo = "Falta configurar la conexión";
            Mensaje = "Todavía no se ha configurado la cadena de conexión en User Secrets. " +
                      "Consulte el README para el comando dotnet user-secrets.";
            _log.LogError(invalida, "Cadena de conexion ausente.");
            return;
        }

        if (excepcion is not null)
        {
            _log.LogError(excepcion, "Error no controlado en la solicitud {RequestId}.", RequestId);
            return;
        }

        switch (codigo)
        {
            case 404:
                Titulo = "No encontramos esa página";
                Mensaje = "El enlace puede estar equivocado o el código de lote no existe.";
                break;
            case 403:
                Titulo = "Sin permiso";
                Mensaje = "Su usuario no tiene permiso para ver esta información.";
                break;
            case not null:
                Titulo = "Algo no salió bien";
                Mensaje = $"El servidor respondió con el código {codigo}.";
                break;
        }
    }
}
