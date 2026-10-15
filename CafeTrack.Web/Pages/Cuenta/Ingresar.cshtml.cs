using System.Security.Claims;
using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Cuenta;

/// <summary>
/// Pantalla de ingreso. Las credenciales las valida sp_login dentro de MySQL;
/// la aplicacion solo guarda la sesion con el rol que devuelve la base.
/// </summary>
[AllowAnonymous]
public class IngresarModel : PageModel
{
    private readonly ISeguridadRepository _repositorio;
    private readonly ILogger<IngresarModel> _log;

    public IngresarModel(ISeguridadRepository repositorio, ILogger<IngresarModel> log)
    {
        _repositorio = repositorio;
        _log = log;
    }

    [BindProperty]
    public IngresoForm Datos { get; set; } = new();

    [BindProperty(SupportsGet = true)]
    public string? ReturnUrl { get; set; }

    public string? Error { get; private set; }

    public async Task<IActionResult> OnGetAsync()
    {
        // Si ya hay sesion, no tiene sentido volver a pedir credenciales.
        if (User.Identity?.IsAuthenticated == true)
        {
            return RedirectToPage("/Index");
        }

        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        try
        {
            var usuario = await _repositorio.IngresarAsync(Datos.Usuario.Trim(), Datos.Clave, ct);

            if (usuario is null)
            {
                Error = "Usuario o contraseña incorrectos.";
                return Page();
            }

            var identidad = new ClaimsIdentity(
                [
                    new Claim(ClaimTypes.Name, usuario.Username),
                    new Claim(ClaimTypes.Role, usuario.Rol),
                    new Claim(UsuarioDeSesion.ClaimNombreCompleto, usuario.NombreCompleto),
                    new Claim("cafetrack:id_usuario", usuario.IdUsuario.ToString())
                ],
                CookieAuthenticationDefaults.AuthenticationScheme);

            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(identidad),
                new AuthenticationProperties { IsPersistent = false });

            _log.LogInformation("Sesion iniciada por {Usuario} con rol {Rol}.",
                usuario.Username, usuario.Rol);

            return Url.IsLocalUrl(ReturnUrl) ? LocalRedirect(ReturnUrl) : RedirectToPage("/Index");
        }
        catch (MySqlException ex)
        {
            // sp_login responde con SIGNAL: el mensaje ya viene redactado.
            Error = ErroresMySql.Traducir(ex);
            return Page();
        }
    }
}
