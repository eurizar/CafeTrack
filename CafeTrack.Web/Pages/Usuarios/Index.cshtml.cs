using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Usuarios;

/// <summary>
/// Gestion de usuarios: crear, cambiar rol, activar o desactivar y entregar
/// contrasenas temporales. Todo pasa por procedimientos de la base, que son
/// los que validan y dejan rastro en la bitacora.
/// </summary>
public class IndexModel : PageModel
{
    private readonly ISeguridadRepository _repositorio;
    private readonly IUsuarioActual _usuario;

    public IndexModel(ISeguridadRepository repositorio, IUsuarioActual usuario)
    {
        _repositorio = repositorio;
        _usuario = usuario;
    }

    /// <summary>Los cinco roles del sistema; cada uno usa su propio usuario de MySQL.</summary>
    public static readonly (string Clave, string Descripcion)[] Roles =
    [
        ("admin", "Todo el sistema, incluida la gestión de usuarios"),
        ("gerente", "Consulta todo y registra ventas"),
        ("acopiador", "Consulta todo y registra acopios"),
        ("catador", "Consulta todo; en la base escribe en Calidad"),
        ("auditor", "Solo lectura, incluida la bitácora")
    ];

    [BindProperty]
    public UsuarioNuevoForm Nuevo { get; set; } = new();

    public IReadOnlyList<UsuarioFila> Usuarios { get; private set; } = [];

    /// <summary>Usuario de la sesion: su propia fila se trata distinto.</summary>
    public string Yo => _usuario.Nombre;

    /// <summary>Si no hay otro admin activo, perder esta clave deja al sistema sin acceso.</summary>
    public bool UnicoAdmin =>
        Usuarios.Count(u => u.Rol == "admin" && u.Activo) <= 1;

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }

    /// <summary>Contrasena temporal recien generada, para mostrarla una sola vez.</summary>
    [TempData] public string? ClaveGenerada { get; set; }

    [TempData] public string? ClaveDe { get; set; }

    public async Task OnGetAsync(CancellationToken ct) => await CargarAsync(ct);

    public async Task<IActionResult> OnPostCrearAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            await CargarAsync(ct);
            return Page();
        }

        var temporal = ClaveTemporal.Generar();

        return await EjecutarAsync(
            () => _repositorio.CrearUsuarioAsync(Nuevo, temporal, _usuario.Nombre, ct),
            $"Usuario {Nuevo.Username} creado.",
            temporal, Nuevo.Username, ct);
    }

    public async Task<IActionResult> OnPostReiniciarAsync(string username, CancellationToken ct)
    {
        var temporal = ClaveTemporal.Generar();

        return await EjecutarAsync(
            () => _repositorio.ReiniciarPasswordAsync(username, temporal, _usuario.Nombre, ct),
            $"Contraseña temporal asignada a {username}.",
            temporal, username, ct);
    }

    public async Task<IActionResult> OnPostRolAsync(string username, string rol, CancellationToken ct) =>
        await EjecutarAsync(
            () => _repositorio.CambiarRolAsync(username, rol, _usuario.Nombre, ct),
            $"{username} ahora es {rol}. El cambio toma efecto en su próximo ingreso.",
            null, null, ct);

    public async Task<IActionResult> OnPostEstadoAsync(string username, bool activo, CancellationToken ct) =>
        await EjecutarAsync(
            () => _repositorio.CambiarEstadoAsync(username, activo, _usuario.Nombre, ct),
            activo ? $"{username} quedó activo." : $"{username} quedó inactivo.",
            null, null, ct);

    /// <summary>Corre la operacion y traduce el rechazo de la base si lo hay.</summary>
    private async Task<IActionResult> EjecutarAsync(
        Func<Task> operacion, string mensajeExito,
        string? claveGenerada, string? claveDe, CancellationToken ct)
    {
        try
        {
            await operacion();
            Exito = mensajeExito;
            ClaveGenerada = claveGenerada;
            ClaveDe = claveDe;
            return RedirectToPage();
        }
        catch (MySqlException ex)
        {
            ErrorBase = ErroresMySql.Traducir(ex);
            await CargarAsync(ct);
            return Page();
        }
    }

    private async Task CargarAsync(CancellationToken ct)
    {
        Usuarios = await _repositorio.ListarUsuariosAsync(ct);
    }
}
