using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Acopios;

/// <summary>
/// Formulario de recepcion en el centro de acopio. No arma el INSERT:
/// llama a sp_registrar_acopio y muestra el mensaje que devuelva la base.
/// </summary>
public class RegistrarModel : PageModel
{
    private readonly IOperacionesRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public RegistrarModel(IOperacionesRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    [BindProperty]
    public AcopioForm Datos { get; set; } = new();

    public IReadOnlyList<LoteOpcion> Lotes { get; private set; } = [];

    /// <summary>Mensaje de error devuelto por la base (SIGNAL o CHECK).</summary>
    public string? ErrorBase { get; private set; }

    [TempData]
    public string? Exito { get; set; }

    public static readonly string[] Condiciones = ["Buena", "Regular", "Mala"];

    public async Task OnGetAsync(CancellationToken ct)
    {
        await CargarAsync(ct);
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            await CargarAsync(ct);
            return Page();
        }

        try
        {
            var idAcopio = await _repositorio.RegistrarAcopioAsync(Datos, _usuario.Nombre, ct);
            Exito = $"Acopio registrado con el número {idAcopio}. " +
                    "La merma de transporte quedó registrada automáticamente.";
            return RedirectToPage();
        }
        catch (MySqlException ex)
        {
            // Regla de negocio rechazada por la base: se muestra tal cual.
            ErrorBase = ErroresMySql.Traducir(ex);
            await CargarAsync(ct);
            return Page();
        }
    }

    private async Task CargarAsync(CancellationToken ct)
    {
        Lotes = await _repositorio.ListarLotesSinAcopioAsync(ct);
    }
}
