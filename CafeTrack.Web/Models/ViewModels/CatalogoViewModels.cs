namespace CafeTrack.Web.Models.ViewModels;

/// <summary>Ficha de una variedad de cafe con sus cifras derivadas de la base.</summary>
public class VariedadFicha
{
    public int IdVariedad { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public bool Activa { get; set; }

    public int Parcelas { get; set; }
    public int Productores { get; set; }
    public decimal AreaManzanas { get; set; }
    public int? AltitudMin { get; set; }
    public int? AltitudMax { get; set; }
    public int Lotes { get; set; }
    public decimal Quintales { get; set; }
    public decimal? ScaPromedio { get; set; }

    /// <summary>Rango de altitud en metros, o null si la variedad no tiene parcelas.</summary>
    public string RangoAltitud =>
        AltitudMin is null || AltitudMax is null
            ? "—"
            : AltitudMin == AltitudMax
                ? $"{AltitudMin} m"
                : $"{AltitudMin}–{AltitudMax} m";
}

/// <summary>Etapa del beneficiado con el tiempo real observado en los lotes cargados.</summary>
public class EtapaFicha
{
    public int IdEtapa { get; set; }
    public int Orden { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string? Descripcion { get; set; }
    public decimal? DuracionMinHoras { get; set; }
    public decimal? DuracionMaxHoras { get; set; }
    public int ProcesosRegistrados { get; set; }
    public decimal? HorasPromedio { get; set; }

    /// <summary>Rango de duracion esperado segun el catalogo.</summary>
    public string RangoEsperado =>
        DuracionMinHoras is null && DuracionMaxHoras is null
            ? "—"
            : $"{DuracionMinHoras ?? 0:0}–{DuracionMaxHoras ?? 0:0} h";
}

/// <summary>Cuantas parcelas y lotes hay por cada certificacion.</summary>
public class CertificacionResumen
{
    public string Certificacion { get; set; } = "Ninguna";
    public int Parcelas { get; set; }
    public int Lotes { get; set; }
    public decimal AreaManzanas { get; set; }
}

/// <summary>Datos de la pantalla de catalogo: variedades, etapas y certificaciones.</summary>
public class CatalogoViewModel
{
    public IReadOnlyList<VariedadFicha> Variedades { get; set; } = [];
    public IReadOnlyList<EtapaFicha> Etapas { get; set; } = [];
    public IReadOnlyList<CertificacionResumen> Certificaciones { get; set; } = [];
}
