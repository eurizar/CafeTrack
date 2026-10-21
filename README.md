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
│   ├── 07_vistas.sql            las 11 consultas del proyecto, como vistas
│   ├── 08_usuarios.sql          gestión de usuarios y contraseñas temporales
│   ├── 09_recuperar_acceso.sql  recuperación cuando nadie puede entrar
│   ├── 10_operacion.sql         beneficiado, catación, bodega y pagos por rol
│   ├── 11_ventas_pagos.sql      existencia por bodega, venta corregida, compradores
│   └── 12_traslados.sql         traslado de café entre bodegas
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
   mysql -u root -p < sql/08_usuarios.sql
   mysql -u root -p < sql/10_operacion.sql
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
| `/Acopios/Registrar` | Recepción en acopio (acopiador) |
| `/Procesos/Registrar` | Etapa del beneficiado (acopiador) |
| `/Calidad/Registrar` | Catación (catador) |
| `/Bodegas/Ingresar` | Ingreso a bodega (acopiador) |
| `/Bodegas/Trasladar` | Traslado entre bodegas (acopiador) |
| `/Compradores` | Compradores y altas (gerente) |
| `/Pagos` | Pendientes de pago y pagos hechos (gerente) |
| `/Ventas/Registrar` | Venta (gerente) |
| `/Pagos/Registrar` | Pago al productor (gerente) |
| `/Reportes` | Las 11 consultas del proyecto, una por vista |
| `/Bitacora` | Auditoría: lo que escriben los triggers y los procedimientos |
| `/Bitacora/Detalle/{id}` | Desglose de un registro: estado anterior, nuevo y el JSON crudo |
| `/Pruebas/Errores` | Demuestra `SIGNAL`, `CHECK` y `ERROR 1142` en vivo |
| `/Usuarios` | Gestión de usuarios y roles (solo `admin`) |
| `/Cuenta/CambiarClave` | Cambio de contraseña del propio usuario |
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

## La cadena completa, rol por rol

Cada paso del proceso tiene su pantalla y su procedimiento, y cada rol solo ve —y solo
puede ejecutar— lo que le toca:

| Paso | Rol | Pantalla | Procedimiento |
|---|---|---|---|
| Acopio | acopiador | `/Acopios/Registrar` | `sp_registrar_acopio` |
| Beneficiado | acopiador | `/Procesos/Registrar` | `sp_registrar_proceso` |
| Catación | catador | `/Calidad/Registrar` | `sp_registrar_calidad` |
| Ingreso a bodega | acopiador | `/Bodegas/Ingresar` | `sp_registrar_ingreso_bodega` |
| Traslado entre bodegas | acopiador | `/Bodegas/Trasladar` | `sp_trasladar_lote` |
| Venta | gerente | `/Ventas/Registrar` | `sp_registrar_venta` |
| Alta de compradores | gerente | `/Compradores` | `sp_crear_comprador` |
| Pago | gerente | `/Pagos/Registrar` | `sp_registrar_pago` |

### Por qué no hay un rol "vendedor"

`Usuarios.rol` es un `ENUM('admin','gerente','acopiador','catador','auditor')`: agregar
un rol sería alterar la tabla, y el esquema sale solo del script. En esta cooperativa
**el gerente es el vendedor**, que además liquida al productor. Queda dicho que concentrar
venta y pago en un mismo rol es una debilidad de control: quien fija el precio de venta
también fija lo que se le paga al productor. Separarlo no exige un rol nuevo —basta mover
`/Pagos` a `admin`— y se deja anotado como decisión consciente, no como olvido.

### Traslado entre bodegas

`MovimientosBodega.tipo_movimiento` no tiene un valor `'Traslado'`, y la tabla no se toca.
`sp_trasladar_lote` (sql/12_traslados.sql) escribe **dos movimientos en una transacción**:
un `'Ajuste'` que resta en la bodega de origen y una `'Entrada'` que suma en la de destino.
Si la bodega de destino no tiene capacidad, el trigger rechaza la entrada y no queda
ninguno de los dos. **Traslada quien custodia el café**: acopiador y admin. El gerente
vende, pero no mueve existencias.

### La existencia se mide por bodega

`fn_existencia_lote_bodega(lote, bodega)` (sql/11_ventas_pagos.sql) corrigió un hueco de
la primera versión: la salida por venta se validaba contra la existencia del lote en toda
la cooperativa, así que se podía despachar desde una bodega café guardado en otra —la
bodega de salida quedaba en negativo y la otra con café que ya no existía. Hoy lo revisan
tanto `sp_registrar_venta` como el trigger `trg_movimientos_validar`, y la pantalla solo
ofrece las bodegas que tienen ese lote.

**El lote avanza solo cuando corresponde.** Las reglas están en `sql/10_operacion.sql`:

- No se puede saltar una etapa del beneficiado: la anterior tiene que estar cerrada.
- **Las fechas solo avanzan**: una etapa no puede empezar antes de que cierre la anterior,
  ni antes de que el lote llegara al centro de acopio, ni en el futuro. Sin esto se podía
  registrar un secado el 21 de junio cuando el lavado cerró el 23.

### Modo demostración

Un secado dura entre 100 y 240 horas: para mostrarlo en una presentación hay que poder
cerrar la etapa con una fecha que todavía no llega. Ese tope —y solo ese— se levanta con:

```bash
dotnet user-secrets set "CafeTrack:PermitirFechasFuturas" "true"
```

Con el ajuste encendido, `sp_registrar_proceso` recibe `p_permitir_futuras = TRUE` y acepta
fechas futuras; la pantalla lo avisa en un recuadro para que nadie crea que es el
comportamiento normal. **El orden entre etapas se sigue exigiendo igual**: eso no se apaga.
Sin el ajuste (lo que viene en el repositorio), rige la regla estricta.
- De una etapa no sale más café del que entró, y la diferencia se anota sola como merma.
- Si una etapa quedó abierta, la misma pantalla la cierra en lugar de duplicarla.
- Solo se cata lo que terminó las siete etapas, una sola vez por lote, y no se puede
  aprobar con menos de 80 puntos SCA. Si no aprueba, el lote queda `'Rechazado'`.
- A bodega entra solo lo aprobado, nunca más de lo que el lote tiene ni más de lo que
  cabe en la bodega.
- Una venta se paga una sola vez, y las deducciones no pueden superar el monto.

**La separación la hace MySQL, no la interfaz.** Si un rol intenta un procedimiento
ajeno, el motor responde `ERROR 1370`; si intenta escribir en una tabla que no le
corresponde, `ERROR 1142`. La pantalla solo traduce el mensaje.

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

La pantalla `/Reportes` las lista y `/Reportes/Ver/{clave}` muestra cada una, con
encabezado fijo al desplazar, filtro en vivo, numeración de filas y una fila de totales
para las columnas que tiene sentido sumar. El nombre de la vista **nunca** llega desde
la URL: viaja solo la clave y se resuelve contra el catálogo de
`Helpers/CatalogoReportes.cs`.

**Descarga a Excel.** Cada reporte trae su botón: genera un `.xlsx` real, con los
encabezados en negrita, las fechas como fechas y el dinero con formato de quetzales.
`Helpers/ExportadorExcel.cs` arma el archivo a mano con `ZipArchive` —un `.xlsx` es un
ZIP con unos XML adentro—, así que **no hace falta ninguna librería externa**.

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
`auditor`; cada fila abre su **desglose completo**, donde se comparan `datos_anteriores`
y `datos_nuevos` lado a lado y se puede ver el JSON tal como lo guardó la base. Cuando el
registro menciona un lote, el desglose enlaza a su trazabilidad.

## Gestión de usuarios

La pantalla `/Usuarios`, solo para `admin`, permite crear usuarios, cambiar su rol,
activarlos o desactivarlos y entregarles una contraseña temporal. Todo pasa por los
procedimientos de `sql/08_usuarios.sql`, que validan con `SIGNAL` y escriben en la
bitácora. Dos reglas que hace cumplir la base: no se puede dejar al sistema sin
administrador activo y no se puede repetir un nombre de usuario.

**Contraseñas temporales sin tocar el esquema.** La tabla `Usuarios` no tiene una
columna para marcar "debe cambiarla", y el esquema no se modifica. La marca viaja dentro
del propio hash con un prefijo:

```
TMP:<salt>:<hash>      contraseña temporal, hay que cambiarla
<salt>:<hash>          contraseña que el usuario eligió
```

`sp_login` detecta el prefijo y lo informa; mientras esté, la aplicación devuelve al
usuario a `/Cuenta/CambiarClave` en cualquier ruta que intente abrir. Al registrar su
contraseña, `sp_cambiar_password` genera un salt nuevo y guarda el hash sin prefijo.

La clave temporal la genera el sistema en bloques legibles (`Cafe-7K3M-R9TX`, sin
caracteres que se confundan) y se muestra **una sola vez**, para dictarla o entregarla.

### Si nadie puede entrar

La contraseña no se recupera: solo está guardado su hash. Lo que se hace es reemplazarla.

1. **Lo normal:** otro usuario con rol `admin` entra a `/Usuarios` y le asigna una
   contraseña temporal. Por eso conviene tener **dos administradores**; la propia
   pantalla lo advierte cuando solo hay uno.
2. **Si no queda ningún administrador con acceso:** se ejecuta
   `sql/09_recuperar_acceso.sql` en MySQL con una cuenta con privilegios (normalmente
   `root`). Edite el usuario y la clave temporal en el archivo y córralo:

   ```bash
   mysql -u root -p < sql/09_recuperar_acceso.sql
   ```

   Al entrar con esa clave, el sistema exige registrar una propia. El script también
   sirve para reactivar un usuario o devolverle el rol `admin`, y todo queda en la bitácora.

Para que el caso no se dé por accidente, un administrador **no puede reiniciarse a sí
mismo** desde `/Usuarios`: en su propia fila la aplicación ofrece *Cambiar mi clave*, que
exige conocer la actual. Reiniciar la de otro usuario o desactivarlo pide confirmación.

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
