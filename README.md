# CaféTrack

Sistema web de **trazabilidad y control de existencias de café** para cooperativas de
Alta Verapaz, Guatemala. Proyecto académico del curso **Base de Datos I**,
Universidad Mariano Gálvez de Guatemala.

El sistema sigue cada lote desde el corte en la parcela hasta el pago al productor:
cosecha → acopio → beneficiado → catación → bodega → venta → pago.

---

## Estado del proyecto

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Entorno: SDK de .NET, MySQL Server, Git, base cargada | Listo |
| **1** | **Estructura, conexión, datos semilla y pantallas de consulta** | **En curso (rama `fase-1-estructura`)** |
| 2 | Función `fn_existencia_lote`, 2 procedimientos y 4 triggers | Pendiente |
| 3 | Login contra `Usuarios` (SHA2 + salt), un usuario MySQL por rol, bitácora | Pendiente |
| 4 | Las 11 consultas como reportes; mensajes de `SIGNAL`, CHECK y ERROR 1142 | Pendiente |
| 5 | Pulido, capturas y guion del video | Pendiente |

La Fase 1 es **solo lectura**: no hay formularios de registro, login, triggers ni
procedimientos almacenados.

---

## Tecnología

- ASP.NET Core **Razor Pages**, C#, `nullable` habilitado.
- **MySQL Server** local (`localhost:3306`), base `trazabilidad_cafe`, **18 tablas**.
- Acceso a datos con **Dapper + MySqlConnector**. Sin Entity Framework, sin migraciones:
  el esquema lo define únicamente el script SQL.
- CSS propio en `wwwroot/css/cafetrack.css`. Sin Bootstrap, sin jQuery, sin frameworks JS.
- Tipografías de Google Fonts: Fraunces, Source Sans 3, IBM Plex Mono.
- Iconos de [Lucide](https://lucide.dev) (licencia ISC), copiados al proyecto y escritos
  en línea; ver `CafeTrack.Web/wwwroot/img/ICONOS.md`.
- Formato guatemalteco (`es-GT`): fechas `dd/MM/yyyy`, moneda `Q` con dos decimales.

> **Versión del SDK.** El proyecto apunta a `net9.0`, que es el SDK instalado en el
> equipo de desarrollo. Para compilarlo con .NET 10 basta con cambiar
> `<TargetFramework>` en `CafeTrack.Web/CafeTrack.Web.csproj`; no hay más dependencias
> de versión.

---

## Estructura del repositorio

```
CafeTrack/
├── .gitignore
├── CafeTrack.sln
├── README.md
├── sql/
│   ├── 01_estructura.sql        18 tablas (script original, sin cambios)
│   ├── 02_datos_prueba.sql      datos ficticios de Alta Verapaz
│   └── 03_usuario_app.sql       CREATE USER + GRANT para cafetrack_dev
└── CafeTrack.Web/
    ├── Program.cs
    ├── appsettings.json                     sin credenciales
    ├── appsettings.Development.json.example plantilla de referencia
    ├── Models/         POCOs de cada tabla + ViewModels
    ├── Data/           IDbConnectionFactory, MySqlConnectionFactory, repositorios Dapper
    ├── Helpers/        formato de ENUM, moneda, fechas
    ├── Pages/          Index, Catalogo, Productores, Parcelas, Lotes, Lotes/Detalle, Existencias, Error
    └── wwwroot/        css/cafetrack.css e img/ (logo e iconos SVG)
```

---

## Montar el proyecto en una PC nueva (Windows)

1. **Instalar** el SDK de .NET (9 o 10), MySQL Server y Git.

2. **Clonar el repositorio**

   ```bash
   git clone https://github.com/eurizar/CafeTrack.git
   cd CafeTrack
   ```

3. **Cargar la base de datos.** En MySQL Workbench o en la línea de comandos, como `root`:

   ```bash
   mysql -u root -p < sql/01_estructura.sql
   mysql -u root -p < sql/02_datos_prueba.sql
   ```

   El primer script crea la base con sus **18 tablas** (incluye `DROP DATABASE IF EXISTS`).
   El segundo carga los datos de prueba y termina mostrando el conteo de cada tabla.

4. **Crear el usuario de la aplicación.** Edite la contraseña dentro de
   `sql/03_usuario_app.sql` y ejecútelo como `root`:

   ```bash
   mysql -u root -p < sql/03_usuario_app.sql
   ```

   El script ejecuta:

   ```sql
   CREATE USER IF NOT EXISTS 'cafetrack_dev'@'localhost' IDENTIFIED BY '...';
   GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON trazabilidad_cafe.* TO 'cafetrack_dev'@'localhost';
   ```

5. **Configurar el secreto** con la contraseña que acaba de asignar:

   ```bash
   cd CafeTrack.Web
   dotnet user-secrets set "ConnectionStrings:CafeTrack" "Server=localhost;Port=3306;Database=trazabilidad_cafe;User=cafetrack_dev;Password=...;"
   ```

   La contraseña **nunca** se guarda en `appsettings.json` ni en ningún archivo del
   repositorio. `appsettings.Development.json.example` sirve solo como plantilla.

6. **Ejecutar**

   ```bash
   dotnet run --project CafeTrack.Web
   ```

   La consola muestra la URL (por ejemplo `https://localhost:7xxx`).

7. **Flujo diario de trabajo**

   ```bash
   git pull            # al empezar
   # ... cambios ...
   git add .
   git commit -m "Mensaje corto en imperativo"
   git push
   ```

---

## Pantallas de la Fase 1

| Ruta | Pantalla |
|---|---|
| `/` | Panel: productores activos, lotes por estado, quintales en bodega y ocupación de cada bodega |
| `/Catalogo` | Café y proceso: variedades, flujograma del proceso, etapas del beneficiado y certificaciones |
| `/Productores` | Listado con búsqueda por nombre o comunidad |
| `/Parcelas` | Productor, variedad, altitud, área y certificación |
| `/Lotes` | Listado con filtros por estado y temporada |
| `/Lotes/Detalle/{codigo}` | Trazabilidad completa del lote, por ejemplo `/Lotes/Detalle/CAF-2026-001` |
| `/Existencias` | Kardex resumido por bodega y lote |

---

## Decisiones de diseño

- **El esquema lo manda el SQL.** La aplicación no crea ni modifica tablas. No hay
  migraciones ni ASP.NET Identity.
- **La existencia no se almacena.** Se calcula desde `MovimientosBodega`: los movimientos
  de tipo `'Entrada'` suman y todos los demás restan.
- **Columnas GENERATED de solo lectura.** `peso_bruto_kg`, `total_venta` y `monto_neto`
  nunca aparecen en un `INSERT` ni en un `UPDATE`.
- **`documento_identidad` no se consulta.** Ninguna consulta de la aplicación selecciona
  esa columna, y el POCO `Productor` ni siquiera la mapea.
- **Valores ENUM sin tildes.** La base conserva `'Organico'` y `'Credito 30 dias'` tal
  como los define el script. La tilde se agrega solo al mostrarlos, con `Helpers/Formato.Enum`.
- **Una fábrica de conexiones.** `IDbConnectionFactory` ya acepta un rol, para que en la
  Fase 3 cada rol (admin, gerente, acopiador, catador, auditor) use un usuario MySQL distinto.
- **Errores amables.** Si MySQL no responde, la aplicación muestra una página explicativa,
  nunca la excepción cruda ni la cadena de conexión.

---

## Datos de prueba

Todos los datos de `sql/02_datos_prueba.sql` son **ficticios**. Los nombres, teléfonos y
documentos no corresponden a personas reales; las comunidades de Cobán, San Pedro Carchá,
Senahú y San Cristóbal Verapaz se usan solo como ambientación.

Contiene 5 variedades, 7 etapas de beneficiado, 2 temporadas, 8 productores, 10 parcelas,
2 bodegas, 3 compradores, 12 cosechas con sus 12 lotes, 12 acopios (uno con 20 % de merma
por una volcadura), procesos con tiempos realistas, 7 evaluaciones de calidad (una
rechazada), 10 movimientos de bodega, 3 ventas y 3 pagos.

Como los triggers se crean hasta la Fase 2, `peso_actual_quintales` y `estado_lote` vienen
cargados a mano y coherentes con cada caso. La tabla `Usuarios` se llena en la Fase 3.

---

## Control de versiones

- Rama de trabajo de esta fase: **`fase-1-estructura`**, creada desde `main`.
  `main` recibe solo cambios terminados y probados.
- Ningún archivo versionado contiene credenciales: `.gitignore` excluye `bin/`, `obj/`,
  `.vs/` y `*.user`, y la contraseña de MySQL vive únicamente en User Secrets
  (`%APPDATA%\Microsoft\UserSecrets\`, fuera del repositorio).
