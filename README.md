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
| 1 | Estructura, conexión, datos semilla y pantallas de consulta | Listo |
| 2 | Función `fn_existencia_lote`, 2 procedimientos, 4 triggers y los formularios que los llaman | Listo |
| **3** | **Login contra `Usuarios` (SHA2 + salt), un usuario MySQL por rol, bitácora** | **Listo** |
| 4 | Las 11 consultas como reportes; mensajes de `SIGNAL`, CHECK y ERROR 1142 | Pendiente |
| 5 | Pulido, capturas y guion del video | Pendiente |

La aplicación **escribe** siempre a través de procedimientos almacenados: las reglas
de negocio viven en MySQL, no en C#. Desde la Fase 3 el acceso exige sesión y cada rol
se conecta con su propio usuario de MySQL, así que los permisos los hace cumplir el
motor y no solo la interfaz.

---

## Tecnología

- ASP.NET Core **Razor Pages**, C#, `nullable` habilitado.
- **MySQL Server** local (`localhost:3306`), base `trazabilidad_cafe`, **18 tablas**.
- Acceso a datos con **Dapper + MySqlConnector**. Sin Entity Framework, sin migraciones:
  el esquema lo define únicamente el script SQL.
- CSS propio en `wwwroot/css/cafetrack.css`. Sin Bootstrap, sin jQuery, sin frameworks JS.
  El único JavaScript es `wwwroot/js/barra.js` (27 líneas, sin librerías): contrae la barra
  lateral y recuerda la preferencia en `localStorage`.
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
│   ├── 03_usuario_app.sql       CREATE USER + GRANT para cafetrack_dev
│   ├── 04_rutinas.sql           función, 2 procedimientos y 4 triggers
│   ├── 05_datos_demo.sql        (opcional) un lote sin acopio para la demo
│   ├── 06_seguridad.sql         usuarios de la app, sp_login y un usuario MySQL por rol
│   └── 07_vistas.sql            las 11 consultas del proyecto, como vistas
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
   mysql -u root -p < sql/04_rutinas.sql
   mysql -u root -p < sql/05_datos_demo.sql   # opcional, para la demostración
   mysql -u root -p < sql/06_seguridad.sql
   mysql -u root -p < sql/07_vistas.sql
   ```

   El primero crea la base con sus **18 tablas** (incluye `DROP DATABASE IF EXISTS`).
   El segundo carga los datos de prueba y termina mostrando el conteo de cada tabla.
   El tercero crea la función, los procedimientos y los triggers; el esquema no cambia.
   El cuarto es opcional: agrega un lote recién cosechado para poder mostrar en vivo
   el formulario de acopio.

   > Si MySQL responde `ERROR 1418` al crear la función, ejecute una sola vez como root:
   > `SET GLOBAL log_bin_trust_function_creators = 1;`

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
| `/Acopios/Registrar` | Formulario de recepción en acopio; llama a `sp_registrar_acopio` |
| `/Ventas/Registrar` | Formulario de venta; llama a `sp_registrar_venta` |
| `/Reportes` | Las 11 consultas del proyecto, una por vista |
| `/Bitacora` | Auditoría: lo que escriben los triggers y los procedimientos |
| `/Pruebas/Errores` | Demuestra `SIGNAL`, `CHECK` y `ERROR 1142` en vivo |
| `/Cuenta/Ingresar` | Inicio de sesión |

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
- **Una fábrica de conexiones por rol.** `IDbConnectionFactory` abre la conexión con el
  usuario de MySQL que corresponde al rol de la sesión (admin, gerente, acopiador,
  catador o auditor).
- **Errores amables.** Si MySQL no responde, la aplicación muestra una página explicativa,
  nunca la excepción cruda ni la cadena de conexión.

---

## Lógica en la base de datos (Fase 2)

`sql/04_rutinas.sql` crea, sin tocar el esquema:

**Función**

- `fn_existencia_lote(id_lote)` — quintales en bodega: suma las `'Entrada'` y resta el resto.

**Procedimientos**

- `sp_registrar_acopio` — valida el peso contra lo cosechado, inserta el acopio, registra
  sola la merma de transporte, actualiza el peso del lote y deja rastro en la bitácora.
- `sp_registrar_venta` — comprueba la existencia con `fn_existencia_lote`, exige catación
  aprobada, inserta la venta y genera la salida de bodega, todo en una transacción.

**Triggers**

| Trigger | Momento | Qué hace |
|---|---|---|
| `trg_movimientos_validar` | BEFORE INSERT en `MovimientosBodega` | Impide sacar más de lo que hay, que entre un lote sin catación aprobada y que se exceda la capacidad de la bodega |
| `trg_movimientos_estado` | AFTER INSERT en `MovimientosBodega` | Pone el lote en `'En bodega'` o `'Vendido'` y escribe en la bitácora |
| `trg_mermas_descuento` | AFTER INSERT en `Mermas` | Descuenta el peso del lote y registra `ALERTA_MERMA_ALTA` si supera el 15 % |
| `trg_ventas_precio` | AFTER INSERT en `VentasLotes` | Registra `ALERTA_PRECIO_BAJO` si el precio queda bajo el precio base de la temporada |

Los errores se levantan con `SIGNAL SQLSTATE '45000'` y llegan a la pantalla como un
aviso en español; `Helpers/ErroresMySql.cs` traduce además las violaciones de `CHECK`
y el `ERROR 1142` de permisos.

**Recarga de datos.** `02_datos_prueba.sql` trae los pesos y estados ya calculados, así
que levanta la bandera `@cafetrack_carga` mientras inserta y los triggers se saltan el
cuerpo. Por eso los scripts se pueden volver a ejecutar en cualquier orden.

## Reportes y errores (Fase 4)

**Las 11 consultas son vistas.** `sql/07_vistas.sql` las crea; el SQL vive en la base y
la aplicación solo hace `SELECT` sobre ellas. La base sigue teniendo **18 tablas**: una
vista no es una tabla y el motor las cuenta aparte.

| Vista | Responde |
|---|---|
| `vw_existencias_bodega` | ¿Cuánto café hay hoy en cada bodega, lote por lote? |
| `vw_trazabilidad_lote` | La historia completa de cada lote, de la parcela al estado actual |
| `vw_produccion_productor` | ¿Cuánto entregó cada socio y cuánto se le ha pagado? |
| `vw_mermas_lote` | ¿Dónde se está perdiendo el café y cuánto? |
| `vw_calidad_lotes` | Puntajes SCA, altura de taza y resultado de cada catación |
| `vw_ventas_detalle` | Cada venta con su comprador y cómo quedó frente al precio base |
| `vw_ventas_temporada` | ¿Cómo le fue a la cooperativa en cada ciclo? |
| `vw_pagos_productor` | Cuánto recibió cada socio y qué parte del ingreso representa |
| `vw_rendimiento_variedad` | ¿Qué variedad rinde mejor y cuál se cotiza más alto? |
| `vw_tiempos_beneficiado` | ¿Cada etapa se cumplió dentro del rango esperado? |
| `vw_alertas_auditoria` | Las alertas que levantan los triggers, con el JSON desplegado |

La pantalla `/Reportes` las lista y `/Reportes/Ver/{clave}` muestra cada una. El nombre
de la vista **nunca** llega desde la URL: viaja solo la clave y se resuelve contra el
catálogo de `Helpers/CatalogoReportes.cs`.

**Los errores de la base, como mensajes.** `/Pruebas/Errores` provoca los tres rechazos
a propósito, dentro de una transacción que siempre se deshace:

| Caso | Qué responde MySQL |
|---|---|
| Vender un lote rechazado en catación | `ERROR 1644` con el texto del `SIGNAL` |
| Registrar un acopio de −5 qq saltándose el procedimiento | `ERROR 3819`, restricción `chk_aco_peso` |
| Insertar un comprador con el usuario del rol | `ERROR 1142` con auditor, catador o acopiador; permitido con admin |

Con un rol que no tiene `EXECUTE` sobre el procedimiento, el primer caso responde antes
con `ERROR 1370`. `Helpers/ErroresMySql.cs` traduce los cuatro a lenguaje llano.

## Seguridad (Fase 3)

**Contraseñas.** La tabla `Usuarios` no tiene columna de salt, así que el salt viaja
dentro de `password_hash` con el formato `<salt>:SHA2(salt + contraseña, 256)`. El salt
es distinto por usuario y se genera con `RANDOM_BYTES(16)`. La comparación ocurre dentro
de `sp_login`: la contraseña en claro nunca sale de la base ni se guarda en ningún lado.
`sp_cambiar_password` genera un salt nuevo en cada cambio.

**Usuarios de prueba.** Los crea `sql/06_seguridad.sql`, todos con la contraseña
`Cafe2026!` (cámbiela antes de cualquier uso real):

| Usuario | Rol | Qué puede hacer |
|---|---|---|
| `admin` | admin | Todo |
| `gerente` | gerente | Consultar todo y registrar ventas |
| `acopiador` | acopiador | Consultar todo y registrar acopios |
| `catador` | catador | Consultar todo; en la base, escribir en `Calidad` |
| `auditor` | auditor | Solo lectura, incluida la bitácora |

**Un usuario de MySQL por rol.** Al iniciar sesión, la aplicación busca la cadena
`ConnectionStrings:CafeTrack:<rol>` en User Secrets y abre la conexión con
`cafetrack_<rol>`, cada uno con sus propios `GRANT`. Si una cadena no está configurada,
cae a la de desarrollo. El login mismo usa la cadena por omisión, porque todavía no se
conoce el rol.

```bash
dotnet user-secrets set "ConnectionStrings:CafeTrack:acopiador" "Server=localhost;Port=3306;Database=trazabilidad_cafe;User=cafetrack_acopiador;Password=...;"
```

Así la restricción es doble: la interfaz esconde lo que no corresponde al rol y, si
alguien llega igual, MySQL responde `ERROR 1142` y la aplicación lo muestra como mensaje.

**Bitácora.** `BitacoraAuditoria` se llena sola desde los triggers y los procedimientos:
ingresos y salidas de bodega, ventas, acopios, inicios de sesión y los intentos fallidos.
La aplicación no inserta ahí por su cuenta. La pantalla `/Bitacora` la ven `admin` y
`auditor`.

## Datos de prueba

Todos los datos de `sql/02_datos_prueba.sql` son **ficticios**. Los nombres, teléfonos y
documentos no corresponden a personas reales; las comunidades de Cobán, San Pedro Carchá,
Senahú y San Cristóbal Verapaz se usan solo como ambientación.

Contiene 5 variedades, 7 etapas de beneficiado, 2 temporadas, 8 productores, 10 parcelas,
2 bodegas, 3 compradores, 12 cosechas con sus 12 lotes, 12 acopios (uno con 20 % de merma
por una volcadura), procesos con tiempos realistas, 7 evaluaciones de calidad (una
rechazada), 10 movimientos de bodega, 3 ventas y 3 pagos.

`peso_actual_quintales` y `estado_lote` vienen cargados a mano y coherentes con cada caso:
son el punto de partida sobre el que después trabajan los triggers. La tabla `Usuarios`
la llena `06_seguridad.sql`.

---

## Control de versiones

- Rama de trabajo de esta fase: **`fase-1-estructura`**, creada desde `main`.
  `main` recibe solo cambios terminados y probados.
- Ningún archivo versionado contiene credenciales: `.gitignore` excluye `bin/`, `obj/`,
  `.vs/` y `*.user`, y la contraseña de MySQL vive únicamente en User Secrets
  (`%APPDATA%\Microsoft\UserSecrets\`, fuera del repositorio).
