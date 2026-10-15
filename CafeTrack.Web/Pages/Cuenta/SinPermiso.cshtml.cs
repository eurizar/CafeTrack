using CafeTrack.Web.Helpers;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Cuenta;

/// <summary>Aviso amable cuando el rol no cubre la pantalla solicitada.</summary>
public class SinPermisoModel : PageModel
{
    private readonly IUsuarioActual _usuario;

    public SinPermisoModel(IUsuarioActual usuario) => _usuario = usuario;

    public string Rol => string.IsNullOrWhiteSpace(_usuario.Rol) ? "sin rol" : _usuario.Rol;
}
