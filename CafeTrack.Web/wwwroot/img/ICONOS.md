# Iconos e ilustraciones

## Iconos de interfaz — Lucide

La interfaz usa **[Lucide](https://lucide.dev)**, un paquete de iconos de código abierto
con licencia **ISC** (fork comunitario de Feather Icons).

- Versión utilizada: `lucide-static@1.47.0`.
- Los trazos se copiaron al proyecto en `Pages/Shared/_Icono.cshtml` y se escriben en
  línea dentro del HTML: no hay CDN, ni JavaScript, ni dependencias de NuGet o npm.
- Cada icono lleva un comentario con su nombre original (`// lucide: nombre`) para poder
  actualizarlo o reemplazarlo.

Texto de la licencia ISC: <https://github.com/lucide-icons/lucide/blob/main/LICENSE>

## Ilustraciones de café — propias

`plantas/planta1.svg` … `plantas/planta6.svg` son ilustraciones propias del proyecto
(granos, hojas, planta de café y rama con cerezas).

**Origen y corrección.** Los dibujos vienen de un trazado con *potrace* que quedó **en
negativo**: un cuadro negro de 512 × 512 con la figura recortada como hueco. Los archivos
de `plantas/` corrigen eso con una **máscara interna** —cuadro blanco menos los trazos
originales— sin modificar ni una coordenada del dibujo: los trazos originales siguen
dentro de cada archivo.

**Cómo se usan.** Se pintan como máscara CSS, no como `<img>`, para que tomen el color
del texto (`currentColor`) y el mismo archivo sirva sobre la barra oscura y sobre las
tarjetas claras. El ayudante es `Pages/Shared/_Planta.cshtml`:

```razor
@await Html.PartialAsync("_Planta", "3:40")   @* ilustración 3, 40 px *@
```

**Dónde aparecen**

| Archivo | Uso |
|---|---|
| `planta1` | Logotipo de la barra lateral, `grano.svg` (favicon) y `logo-cafetrack.svg` |
| `planta2` | Tarjeta de la variedad Pache |
| `planta3` | Tarjeta de la variedad Bourbon |
| `planta4` | Tarjeta de la variedad Caturra |
| `planta5` | Tarjeta de la variedad Catuaí |
| `planta6` | Tarjeta de la variedad Typica y marca de agua del encabezado de `/Catalogo` |
