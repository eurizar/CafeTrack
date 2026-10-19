using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace CafeTrack.Web.Pages.Pruebas;

/// <summary>
/// Demuestra las tres barreras de la base y como las muestra la aplicacion:
/// SIGNAL de una rutina, restriccion CHECK y permisos del usuario de MySQL.
/// </summary>
public class ErroresModel : PageModel
{
    private readonly IPruebasRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public ErroresModel(IPruebasRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    public string Rol => string.IsNullOrWhiteSpace(_usuario.Rol) ? "sin rol" : _usuario.Rol;

    public ResultadoPrueba? Resultado { get; private set; }

    public async Task<IActionResult> OnPostAsync(string caso, CancellationToken ct)
    {
        Resultado = await _repositorio.ProbarAsync(caso, ct);
        return Page();
    }
}
