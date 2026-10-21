using CafeTrack.Web.Data;
using CafeTrack.Web.Helpers;
using CafeTrack.Web.Models.ViewModels;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MySqlConnector;

namespace CafeTrack.Web.Pages.Calidad;

/// <summary>
/// Registro de la catacion. Solo aparecen los lotes que terminaron el
/// beneficiado; si el catador no aprueba, el lote queda rechazado.
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

    /// <summary>ENUM altura_taza, tal como esta en la base.</summary>
    public static readonly string[] Alturas =
        ["Estrictamente Altura", "Altura", "Central", "Baja"];

    /// <summary>
    /// Escala SCA: que significa cada rango de puntaje. Se muestra en la
    /// ventana de ayuda del formulario.
    /// </summary>
    public static readonly (string Rango, string Nombre, string Significa)[] EscalaSca =
    [
        ("90 – 100", "Excepcional",
         "Taza extraordinaria. Muy poco café del mundo llega aquí."),
        ("85 – 89.99", "Excelente",
         "Café de especialidad de alta gama; se cotiza con premio sobre el precio base."),
        ("80 – 84.99", "Muy bueno",
         "Mínimo para considerarse café de especialidad. Es el piso de la cooperativa."),
        ("Menos de 80", "Fuera de especialidad",
         "Se vende como café comercial. El sistema no deja aprobarlo para venta.")
    ];

    /// <summary>Los diez atributos que suma una catacion SCA.</summary>
    public static readonly string[] AtributosSca =
    [
        "Fragancia y aroma", "Sabor", "Sabor residual", "Acidez", "Cuerpo",
        "Balance", "Uniformidad", "Taza limpia", "Dulzor", "Puntaje del catador"
    ];

    /// <summary>
    /// Clasificacion guatemalteca por altura de siembra. Decide la dureza
    /// del grano: mientras mas alto, mas lento madura y mas denso queda.
    /// </summary>
    public static readonly (string Clave, string Altitud, string Significa)[] EscalaAltura =
    [
        ("Estrictamente Altura", "1,350 m o más",
         "Grano muy duro (SHB). Acidez marcada y taza compleja."),
        ("Altura", "1,200 – 1,350 m",
         "Grano duro (HB). Buen cuerpo y acidez equilibrada."),
        ("Central", "900 – 1,200 m",
         "Grano semiduro. Taza suave, menos acidez."),
        ("Baja", "Menos de 900 m",
         "Grano blando. Cuerpo liviano, madura rápido.")
    ];

    /// <summary>
    /// Notas de la rueda de sabores, agrupadas por familia. Son atajos para
    /// escribir el perfil; el texto sigue siendo libre.
    /// </summary>
    public static readonly Dictionary<string, string[]> Notas = new()
    {
        ["Frutal"] = ["cereza", "naranja", "mandarina", "manzana verde", "durazno", "mora"],
        ["Dulce"] = ["panela", "caramelo", "miel", "vainilla", "melaza"],
        ["Cacao"] = ["chocolate oscuro", "chocolate con leche", "cacao"],
        ["Floral"] = ["jazmín", "bergamota", "flor de café"],
        ["Nuez y cereal"] = ["nuez", "almendra", "cereal tostado", "pan horneado"],
        ["Especias"] = ["canela", "clavo", "pimienta"],
        ["Defectos"] = ["fermento", "vinoso", "astringente", "moho", "sabor a mojado"]
    };

    [BindProperty]
    public CalidadForm Datos { get; set; } = new();

    public IReadOnlyList<LoteParaCatar> Lotes { get; private set; } = [];

    public string? ErrorBase { get; private set; }

    [TempData] public string? Exito { get; set; }
    [TempData] public string? ExitoDetalle { get; set; }

    public async Task OnGetAsync(CancellationToken ct)
    {
        await CargarAsync(ct);
        Datos.Evaluador = _usuario.NombreCompleto;
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken ct)
    {
        if (!ModelState.IsValid)
        {
            await CargarAsync(ct);
            return Page();
        }

        await CargarAsync(ct);
        var elegido = Lotes.FirstOrDefault(l => l.IdLote == Datos.IdLote);

        // Lo marcado en el panel y la nota libre se juntan en un solo texto.
        Datos.Perfil = ComponerPerfil(Datos.Notas, Datos.Perfil);

        try
        {
            await _repositorio.RegistrarCalidadAsync(Datos, _usuario.Nombre, ct);

            var lote = elegido?.CodigoLote ?? "seleccionado";
            var puntos = Formato.Numero(Datos.Puntaje);

            if (Datos.Aprobado == true)
            {
                Exito = $"El lote {lote} obtuvo {puntos} puntos y fue aprobado.";
                ExitoDetalle = "Ya puede ingresar a bodega y venderse. " +
                               "El acopiador lo verá en la pantalla de ingreso a bodega.";
            }
            else
            {
                Exito = $"El lote {lote} obtuvo {puntos} puntos y no fue aprobado.";
                ExitoDetalle = "Queda marcado como rechazado: el sistema ya no deja " +
                               "ingresarlo a bodega ni venderlo.";
            }

            return RedirectToPage();
        }
        catch (MySqlException ex)
        {
            ErrorBase = ErroresMySql.Traducir(ex);
            await CargarAsync(ct);
            return Page();
        }
    }

    /// <summary>
    /// Arma el perfil sensorial que se guarda: las notas marcadas agrupadas
    /// por familia y, al final, la nota libre. Queda asi:
    /// "Frutal: cereza, naranja · Dulce: caramelo · Nota: taza limpia".
    /// </summary>
    public static string? ComponerPerfil(string? marcadas, string? libre)
    {
        var elegidas = (marcadas ?? "")
            .Split('|', StringSplitOptions.RemoveEmptyEntries)
            .Select(t => t.Split('>', 2))
            .Where(t => t.Length == 2)
            .ToList();

        var partes = new List<string>();

        // Se recorre el diccionario para respetar el orden del panel y
        // descartar cualquier nota que no venga de el.
        foreach (var (familia, catalogo) in Notas)
        {
            var notas = catalogo
                .Where(n => elegidas.Any(e =>
                    e[0] == familia &&
                    string.Equals(e[1], n, StringComparison.OrdinalIgnoreCase)))
                .ToList();

            if (notas.Count > 0)
            {
                partes.Add($"{familia}: {string.Join(", ", notas)}");
            }
        }

        var nota = (libre ?? "").Trim();
        if (nota.Length > 0) { partes.Add($"Nota: {nota}"); }

        return partes.Count == 0 ? null : string.Join(" · ", partes);
    }

    private async Task CargarAsync(CancellationToken ct)
    {
        Lotes = await _repositorio.ListarLotesParaCatarAsync(ct);
    }
}
