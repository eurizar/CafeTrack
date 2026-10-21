using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Procesos;

/// <summary>
/// Registro de una etapa del beneficiado. El procedimiento no deja saltarse
/// etapas ni sacar mas cafe del que entro, y registra sola la perdida.
/// </summary>
public class RegistrarModel : PageModel
{
    private readonly IOperacionesRepository _repositorio;
    private readonly IUsuarioActual _usuario;
    private readonly Ajustes _ajustes;

    public RegistrarModel(
        IOperacionesRepository repositorio, IUsuarioActual usuario, Ajustes ajustes)
    {
        _repositorio = repositorio;
        _usuario = usuario;
        _ajustes = ajustes;
    }

    /// <summary>En modo demostracion el formulario acepta fechas futuras.</summary>
    public bool PermiteFuturas => _ajustes.PermitirFechasFuturas;

    [BindProperty]
    public ProcesoForm Datos { get; set; } = new();

    public IReadOnlyList<LoteEnProceso> Lotes { get; private set; } = [];

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }
    [TempData] public string? ExitoDetalle { get; set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        // El formulario arranca vacio: al elegir el lote, la pantalla llena
        // sola la etapa que toca, el peso de entrada y la hora.
        await CargarAsync(ct);
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            await CargarAsync(ct);
            return Page();
        }

        // Se carga antes de guardar para poder redactar el aviso con el
        // codigo del lote y el nombre de la etapa.
        await CargarAsync(ct);
        var elegido = Lotes.FirstOrDefault(l => l.IdLote == Datos.IdLote);

        try
        {
            await _repositorio.RegistrarProcesoAsync(Datos, _usuario.Nombre, ct);

            var lote = elegido?.CodigoLote ?? "seleccionado";
            var etapa = Formato.Enum(elegido?.Etapa ?? "la etapa").ToLower(Formato.CulturaGt);

            Exito = Datos.FechaFin is null
                ? $"Se abrió la etapa de {etapa} del lote {lote}. Queda en curso: vuelva a esta " +
                  "pantalla cuando termine para anotar la hora de cierre y el peso final."
                : $"Terminó la etapa de {etapa} del lote {lote}.";

            if (Datos.FechaFin is not null && Datos.PesoSalida is { } salida &&
                Datos.PesoEntrada is { } entrada && entrada > salida)
            {
                var perdida = entrada - salida;
                var pct = entrada > 0 ? Math.Round(perdida / entrada * 100, 2) : 0;

                ExitoDetalle =
                    $"Entraron {Formato.Quintales(entrada)} qq y salieron {Formato.Quintales(salida)} qq. " +
                    $"Esa diferencia de {Formato.Quintales(perdida)} qq ({Formato.Porcentaje(pct, 2)}) " +
                    "es café que se pierde normalmente en el proceso, y el sistema ya la anotó " +
                    "en el historial del lote para que no quede sin explicación.";
            }

            return RedirectToPage();
        }
        catch (MySqlException ex)
        {
            ErrorBase = ErroresMySql.Traducir(ex);
            return Page();
        }
    }

    private async Task CargarAsync(CancellationToken ct)
    {
        Lotes = await _repositorio.ListarLotesEnProcesoAsync(ct);
    }
}
