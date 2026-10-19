using System.Security.Claims;
using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Cuenta;

/// <summary>
/// Cambio de contrasena del propio usuario. Es obligatorio cuando el
/// administrador entrego una clave temporal: hasta que no registre la suya,
/// el sistema lo devuelve a esta pantalla.
/// </summary>
public class CambiarClaveModel : PageModel
{
    private readonly ISeguridadRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public CambiarClaveModel(ISeguridadRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    [BindProperty]
    public CambioClaveForm Datos { get; set; } = new();

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }

    /// <summary>La sesion trae una clave temporal: el cambio es obligatorio.</summary>
    public bool Obligatorio => User.HasClaim(ClaimDebeCambiar, "1");

    /// <summary>Claim que marca la contrasena temporal.</summary>
    public const string ClaimDebeCambiar = "cafetrack:debe_cambiar";

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        try
        {
            await _repositorio.CambiarPasswordAsync(
                _usuario.Nombre, Datos.Actual, Datos.Nueva, ct);

            // La sesion se renueva sin la marca de clave temporal.
            await RenovarSesionAsync();

            Exito = "Su contraseña quedó registrada.";
            return RedirectToPage("/Index");
        }
        catch (MySqlException ex)
        {
            ErrorBase = ErroresMySql.Traducir(ex);
            return Page();
        }
    }

    private async Task RenovarSesionAsync()
    {
        var claims = User.Claims
            .Where(c => c.Type != ClaimDebeCambiar)
            .ToList();

        var identidad = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

        await HttpContext.SignInAsync(
            CookieAuthenticationDefaults.AuthenticationScheme,
            new ClaimsPrincipal(identidad));
    }
}
