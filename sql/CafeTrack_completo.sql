-- =====================================================================
-- CafeTrack - Script completo de la base de datos
--
-- Crea la base trazabilidad_cafe desde cero: 18 tablas, relaciones,
-- 14 procedimientos, 2 funciones, 4 triggers, 11 vistas, usuarios por
-- rol y datos de ejemplo.
--
-- Ejecutar como root:
--   mysql -u root -p < CafeTrack_completo.sql
--
-- ADVERTENCIA: borra la base trazabilidad_cafe si ya existe.
--
-- No incluye (son opcionales):
--   05_datos_demo.sql        un lote recien cosechado, sin acopio
--   09_recuperar_acceso.sql  recuperacion de acceso del administrador;
--                            se ejecuta solo si se pierde esa contrasena
--
-- Despues de ejecutarlo, cambie las contrasenas CAMBIAR_ESTA_CLAVE de los
-- usuarios de MySQL (ver README.md, seccion Instalacion).
-- =====================================================================


-- =====================================================================
-- 01_estructura.sql: Estructura: 18 tablas
-- =====================================================================
-- =====================================================================
-- ESTRUCTURA -- 18 tablas, sin datos, sin rutinas, sin triggers
-- =====================================================================
 
DROP DATABASE IF EXISTS trazabilidad_cafe;
CREATE DATABASE trazabilidad_cafe
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE trazabilidad_cafe;
 
 
-- ---------------------------------------------------------------------
-- 1.1 Catalogos base (no dependen de nadie)
-- ---------------------------------------------------------------------
 
CREATE TABLE Variedades (
  id_variedad INT AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(50)  NOT NULL UNIQUE,
  descripcion VARCHAR(200) NULL,
  activa      BOOLEAN      DEFAULT TRUE
) ENGINE=InnoDB;
 
CREATE TABLE Productores (
  id_productor        INT AUTO_INCREMENT PRIMARY KEY,
  nombre              VARCHAR(100) NOT NULL,
  documento_identidad VARCHAR(20)  NOT NULL UNIQUE,
  telefono            VARCHAR(20)  NULL,
  comunidad           VARCHAR(100) NULL,
  fecha_ingreso_coop  DATE         NOT NULL,
  activo              BOOLEAN      DEFAULT TRUE
) ENGINE=InnoDB;
 
CREATE TABLE Temporadas (
  id_temporada        INT AUTO_INCREMENT PRIMARY KEY,
  anio                INT  NOT NULL UNIQUE,
  fecha_inicio        DATE NOT NULL,
  fecha_cierre        DATE NULL,
  estado              ENUM('Planificada','En curso','Cerrada') DEFAULT 'Planificada',
  precio_base_quintal DECIMAL(10,2) NULL,
  CONSTRAINT chk_temp_fechas CHECK (fecha_cierre IS NULL OR fecha_cierre > fecha_inicio),
  CONSTRAINT chk_temp_precio CHECK (precio_base_quintal IS NULL OR precio_base_quintal >= 0)
) ENGINE=InnoDB;
 
CREATE TABLE EtapasProceso (
  id_etapa           INT AUTO_INCREMENT PRIMARY KEY,
  nombre             VARCHAR(50) NOT NULL UNIQUE,
  orden              INT NOT NULL UNIQUE,
  duracion_min_horas DECIMAL(6,2) NULL,
  duracion_max_horas DECIMAL(6,2) NULL,
  descripcion        VARCHAR(200) NULL,
  CONSTRAINT chk_etapa_orden CHECK (orden > 0),
  CONSTRAINT chk_etapa_dur   CHECK (duracion_max_horas IS NULL
                                    OR duracion_min_horas IS NULL
                                    OR duracion_max_horas >= duracion_min_horas)
) ENGINE=InnoDB;
 
CREATE TABLE Bodegas (
  id_bodega           INT AUTO_INCREMENT PRIMARY KEY,
  nombre              VARCHAR(100) NOT NULL UNIQUE,
  ubicacion           VARCHAR(200) NULL,
  capacidad_quintales DECIMAL(10,2) NULL,
  responsable         VARCHAR(100) NULL,
  activa              BOOLEAN DEFAULT TRUE,
  CONSTRAINT chk_bod_capacidad CHECK (capacidad_quintales IS NULL OR capacidad_quintales > 0)
) ENGINE=InnoDB;
 
CREATE TABLE Compradores (
  id_comprador INT AUTO_INCREMENT PRIMARY KEY,
  nombre       VARCHAR(100) NOT NULL,
  tipo         ENUM('Exportador','Tostador','Intermediario','Cooperativa') NOT NULL,
  pais_destino VARCHAR(50)  NULL,
  contacto     VARCHAR(100) NULL,
  telefono     VARCHAR(20)  NULL,
  activo       BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;
 
-- ---------------------------------------------------------------------
-- 1.2 Cadena productiva
-- ---------------------------------------------------------------------
 
CREATE TABLE Parcelas (
  id_parcela     INT AUTO_INCREMENT PRIMARY KEY,
  id_productor   INT NOT NULL,
  id_variedad    INT NOT NULL,
  nombre         VARCHAR(100) NOT NULL,
  ubicacion      VARCHAR(200) NULL,
  area_manzanas  DECIMAL(8,2) NULL,
  altitud_metros INT NULL,
  certificacion  ENUM('Ninguna','Organico','Fair Trade','Rainforest','UTZ') DEFAULT 'Ninguna',
  activa         BOOLEAN DEFAULT TRUE,
  CONSTRAINT chk_par_area    CHECK (area_manzanas IS NULL OR area_manzanas > 0),
  CONSTRAINT chk_par_altitud CHECK (altitud_metros IS NULL OR altitud_metros BETWEEN 0 AND 4300),
  CONSTRAINT fk_par_productor FOREIGN KEY (id_productor)
    REFERENCES Productores(id_productor) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_par_variedad FOREIGN KEY (id_variedad)
    REFERENCES Variedades(id_variedad) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE Cosechas (
  id_cosecha           INT AUTO_INCREMENT PRIMARY KEY,
  id_parcela           INT NOT NULL,
  id_temporada         INT NOT NULL,
  fecha_recoleccion    DATE NOT NULL,
  peso_bruto_quintales DECIMAL(10,2) NOT NULL,
  peso_bruto_kg        DECIMAL(10,2)
                       GENERATED ALWAYS AS (peso_bruto_quintales * 45.36) STORED,
  humedad_porcentaje   DECIMAL(5,2) NULL,
  recolector           VARCHAR(100) NULL,
  observaciones        TEXT NULL,
  CONSTRAINT chk_cos_peso    CHECK (peso_bruto_quintales > 0),
  CONSTRAINT chk_cos_humedad CHECK (humedad_porcentaje IS NULL
                                    OR humedad_porcentaje BETWEEN 0 AND 100),
  CONSTRAINT fk_cos_parcela FOREIGN KEY (id_parcela)
    REFERENCES Parcelas(id_parcela) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cos_temporada FOREIGN KEY (id_temporada)
    REFERENCES Temporadas(id_temporada) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE Lotes (
  id_lote                 INT AUTO_INCREMENT PRIMARY KEY,
  id_cosecha              INT NOT NULL,
  codigo_lote             VARCHAR(20) NOT NULL UNIQUE,
  fecha_creacion          DATETIME DEFAULT CURRENT_TIMESTAMP,
  peso_inicial_quintales  DECIMAL(10,2) NOT NULL,
  peso_actual_quintales   DECIMAL(10,2) NOT NULL,
  estado_lote             ENUM('En acopio','En proceso','En bodega','Vendido','Rechazado')
                          DEFAULT 'En acopio',
  certificacion_aplicable ENUM('Ninguna','Organico','Fair Trade','Rainforest','UTZ')
                          DEFAULT 'Ninguna',
  CONSTRAINT chk_lot_peso CHECK (peso_inicial_quintales > 0),
  CONSTRAINT fk_lot_cosecha FOREIGN KEY (id_cosecha)
    REFERENCES Cosechas(id_cosecha) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE Acopios (
  id_acopio               INT AUTO_INCREMENT PRIMARY KEY,
  id_lote                 INT NOT NULL,
  fecha_recepcion         DATETIME DEFAULT CURRENT_TIMESTAMP,
  peso_recibido_quintales DECIMAL(10,2) NOT NULL,
  responsable_recepcion   VARCHAR(100) NOT NULL,
  condicion_transporte    ENUM('Buena','Regular','Mala') DEFAULT 'Buena',
  observaciones           TEXT NULL,
  CONSTRAINT chk_aco_peso CHECK (peso_recibido_quintales > 0),
  CONSTRAINT fk_aco_lote FOREIGN KEY (id_lote)
    REFERENCES Lotes(id_lote) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE Procesos (
  id_proceso             INT AUTO_INCREMENT PRIMARY KEY,
  id_lote                INT NOT NULL,
  id_etapa               INT NOT NULL,
  fecha_inicio           DATETIME NOT NULL,
  fecha_fin              DATETIME NULL,
  peso_entrada_quintales DECIMAL(10,2) NOT NULL,
  peso_salida_quintales  DECIMAL(10,2) NULL,
  responsable            VARCHAR(100) NOT NULL,
  CONSTRAINT chk_pro_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
  CONSTRAINT chk_pro_entrada CHECK (peso_entrada_quintales > 0),
  CONSTRAINT chk_pro_salida CHECK (peso_salida_quintales IS NULL
                                   OR peso_salida_quintales <= peso_entrada_quintales),
  CONSTRAINT fk_pro_lote FOREIGN KEY (id_lote)
    REFERENCES Lotes(id_lote) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pro_etapa FOREIGN KEY (id_etapa)
    REFERENCES EtapasProceso(id_etapa) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE Calidad (
  id_calidad           INT AUTO_INCREMENT PRIMARY KEY,
  id_lote              INT NOT NULL,
  fecha_evaluacion     DATETIME DEFAULT CURRENT_TIMESTAMP,
  evaluador            VARCHAR(100) NOT NULL,
  puntaje_sca          DECIMAL(4,2) NULL,
  altura_taza          ENUM('Estrictamente Altura','Altura','Central','Baja') NULL,
  defectos_principales VARCHAR(200) NULL,
  perfil_sensorial     TEXT NULL,
  aprobado_venta       BOOLEAN DEFAULT FALSE,
  CONSTRAINT chk_cal_sca CHECK (puntaje_sca IS NULL OR puntaje_sca BETWEEN 0 AND 100),
  CONSTRAINT fk_cal_lote FOREIGN KEY (id_lote)
    REFERENCES Lotes(id_lote) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE Mermas (
  id_merma               INT AUTO_INCREMENT PRIMARY KEY,
  id_lote                INT NOT NULL,
  tipo_merma             ENUM('Natural','Transporte','Proceso','Almacenamiento','Otra') NOT NULL,
  etapa_origen           ENUM('Cosecha','Acopio','Proceso','Bodega') NOT NULL,
  peso_perdido_quintales DECIMAL(10,2) NOT NULL,
  porcentaje_merma       DECIMAL(5,2) NULL,
  fecha_registro         DATETIME DEFAULT CURRENT_TIMESTAMP,
  responsable            VARCHAR(100) NOT NULL,
  justificacion          TEXT NULL,
  CONSTRAINT chk_mer_peso CHECK (peso_perdido_quintales > 0),
  CONSTRAINT chk_mer_pct  CHECK (porcentaje_merma IS NULL
                                 OR porcentaje_merma BETWEEN 0 AND 100),
  CONSTRAINT fk_mer_lote FOREIGN KEY (id_lote)
    REFERENCES Lotes(id_lote) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE VentasLotes (
  id_venta               INT AUTO_INCREMENT PRIMARY KEY,
  id_lote                INT NOT NULL,
  id_comprador           INT NOT NULL,
  fecha_venta            DATETIME DEFAULT CURRENT_TIMESTAMP,
  peso_vendido_quintales DECIMAL(10,2) NOT NULL,
  precio_quintal         DECIMAL(10,2) NOT NULL,
  total_venta            DECIMAL(12,2)
                         GENERATED ALWAYS AS (peso_vendido_quintales * precio_quintal) STORED,
  forma_pago             ENUM('Contado','Credito 30 dias','Credito 60 dias') DEFAULT 'Contado',
  estado_pago            ENUM('Pendiente','Parcial','Pagado') DEFAULT 'Pendiente',
  usuario_registro       VARCHAR(50) NOT NULL,
  CONSTRAINT chk_ven_peso   CHECK (peso_vendido_quintales > 0),
  CONSTRAINT chk_ven_precio CHECK (precio_quintal > 0),
  CONSTRAINT fk_ven_lote FOREIGN KEY (id_lote)
    REFERENCES Lotes(id_lote) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ven_comprador FOREIGN KEY (id_comprador)
    REFERENCES Compradores(id_comprador) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE MovimientosBodega (
  id_movimiento      INT AUTO_INCREMENT PRIMARY KEY,
  id_bodega          INT NOT NULL,
  id_lote            INT NOT NULL,
  tipo_movimiento    ENUM('Entrada','Salida por venta','Salida por merma','Ajuste') NOT NULL,
  fecha_movimiento   DATETIME DEFAULT CURRENT_TIMESTAMP,
  cantidad_quintales DECIMAL(10,2) NOT NULL,
  id_venta           INT NULL,
  responsable        VARCHAR(100) NOT NULL,
  usuario_registro   VARCHAR(50) NOT NULL,
  observaciones      TEXT NULL,
  CONSTRAINT chk_mov_cantidad CHECK (cantidad_quintales > 0),
  CONSTRAINT fk_mov_bodega FOREIGN KEY (id_bodega)
    REFERENCES Bodegas(id_bodega) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_mov_lote FOREIGN KEY (id_lote)
    REFERENCES Lotes(id_lote) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_mov_venta FOREIGN KEY (id_venta)
    REFERENCES VentasLotes(id_venta) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
CREATE TABLE Pagos (
  id_pago               INT AUTO_INCREMENT PRIMARY KEY,
  id_productor          INT NOT NULL,
  id_venta              INT NOT NULL,
  fecha_pago            DATETIME DEFAULT CURRENT_TIMESTAMP,
  monto_pagado          DECIMAL(12,2) NOT NULL,
  precio_pagado_quintal DECIMAL(10,2) NOT NULL,
  deducciones           DECIMAL(10,2) DEFAULT 0,
  monto_neto            DECIMAL(12,2)
                        GENERATED ALWAYS AS (monto_pagado - deducciones) STORED,
  metodo_pago           ENUM('Efectivo','Transferencia','Cheque') NOT NULL,
  comprobante           VARCHAR(50) NULL,
  usuario_registro      VARCHAR(50) NOT NULL,
  CONSTRAINT chk_pag_monto  CHECK (monto_pagado > 0),
  CONSTRAINT chk_pag_precio CHECK (precio_pagado_quintal > 0),
  CONSTRAINT chk_pag_deduc  CHECK (deducciones >= 0 AND deducciones <= monto_pagado),
  CONSTRAINT fk_pag_productor FOREIGN KEY (id_productor)
    REFERENCES Productores(id_productor) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pag_venta FOREIGN KEY (id_venta)
    REFERENCES VentasLotes(id_venta) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
 
-- ---------------------------------------------------------------------
-- 1.3 Seguridad
-- ---------------------------------------------------------------------
 
CREATE TABLE BitacoraAuditoria (
  id_bitacora          INT AUTO_INCREMENT PRIMARY KEY,
  tabla_afectada       VARCHAR(50) NOT NULL,
  operacion            ENUM('INSERT','UPDATE','DELETE',
                            'ALERTA_PRECIO_BAJO','ALERTA_MERMA_ALTA') NOT NULL,
  id_registro_afectado INT NULL,
  usuario              VARCHAR(50) NOT NULL,
  fecha_hora           DATETIME DEFAULT CURRENT_TIMESTAMP,
  datos_anteriores     JSON NULL,
  datos_nuevos         JSON NULL
) ENGINE=InnoDB;
 
CREATE TABLE Usuarios (
  id_usuario      INT AUTO_INCREMENT PRIMARY KEY,
  username        VARCHAR(50)  NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  nombre_completo VARCHAR(100) NOT NULL,
  rol             ENUM('admin','gerente','acopiador','catador','auditor') NOT NULL,
  activo          BOOLEAN DEFAULT TRUE,
  ultimo_acceso   DATETIME NULL
) ENGINE=InnoDB;
 
-- =====================================================================
-- FIN 
-- =====================================================================

-- =====================================================================
-- 02_datos_prueba.sql: Datos de prueba
-- =====================================================================
-- =====================================================================
-- CafeTrack - DATOS DE PRUEBA
-- Ejecutar DESPUES de sql/01_estructura.sql
--
-- Todos los datos son FICTICIOS. Los nombres, telefonos y documentos no
-- corresponden a personas reales; el contexto geografico (Coban, San Pedro
-- Carcha, Senahu, San Cristobal Verapaz) se usa solo como ambientacion.
--
-- Los valores ENUM se escriben EXACTAMENTE como los define el script de
-- estructura, sin tildes ('Organico', 'Credito 30 dias').
-- Las columnas GENERATED (peso_bruto_kg, total_venta, monto_neto) nunca se
-- incluyen en los INSERT.
-- peso_actual_quintales y estado_lote se cargan ya calculados, coherentes
-- con cada caso.
-- =====================================================================

USE trazabilidad_cafe;

-- Los pesos y estados de este archivo ya vienen calculados. Esta bandera le
-- avisa a los triggers (sql/04_rutinas.sql) que no vuelvan a
-- descontar ni a recalcular nada mientras dura la carga; asi el script se
-- puede volver a ejecutar aunque las rutinas ya esten creadas.
SET @cafetrack_carga = 1;

-- El script es re-ejecutable: vacia las tablas respetando las FK.
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Pagos;
TRUNCATE TABLE MovimientosBodega;
TRUNCATE TABLE VentasLotes;
TRUNCATE TABLE Mermas;
TRUNCATE TABLE Calidad;
TRUNCATE TABLE Procesos;
TRUNCATE TABLE Acopios;
TRUNCATE TABLE Lotes;
TRUNCATE TABLE Cosechas;
TRUNCATE TABLE Parcelas;
TRUNCATE TABLE Compradores;
TRUNCATE TABLE Bodegas;
TRUNCATE TABLE EtapasProceso;
TRUNCATE TABLE Temporadas;
TRUNCATE TABLE Productores;
TRUNCATE TABLE Variedades;
TRUNCATE TABLE BitacoraAuditoria;
SET FOREIGN_KEY_CHECKS = 1;


-- ---------------------------------------------------------------------
-- 1. Variedades (5)
-- ---------------------------------------------------------------------
INSERT INTO Variedades (id_variedad, nombre, descripcion, activa) VALUES
 (1, 'Bourbon', 'Variedad tradicional de taza dulce, buen cuerpo; rinde bien sobre 1300 m.', TRUE),
 (2, 'Caturra', 'Mutacion de Bourbon, porte bajo y maduracion temprana.',                    TRUE),
 (3, 'Catuai',  'Cruce de Mundo Novo y Caturra; resistente al viento y a la lluvia.',        TRUE),
 (4, 'Typica',  'Variedad antigua, taza limpia y delicada, rendimiento bajo.',               TRUE),
 (5, 'Pache',   'Porte muy bajo, adaptada a alturas medias de las Verapaces.',               TRUE);


-- ---------------------------------------------------------------------
-- 2. Productores (8) - datos ficticios
-- ---------------------------------------------------------------------
INSERT INTO Productores
 (id_productor, nombre, documento_identidad, telefono, comunidad, fecha_ingreso_coop, activo) VALUES
 (1, 'Marcos Ba Caal',      '9000 00001 1601', '5512 0011', 'Chirrepeco, Coban',         '2016-03-14', TRUE),
 (2, 'Lucia Cac Pop',       '9000 00002 1601', '5512 0022', 'Santa Cruz, Coban',         '2017-06-02', TRUE),
 (3, 'Esteban Coc Chub',    '9000 00003 1602', '5512 0033', 'Sacsuha, San Pedro Carcha', '2015-11-20', TRUE),
 (4, 'Ana Xol Tiul',        '9000 00004 1602', '5512 0044', 'Chicoj, San Pedro Carcha',  '2018-01-15', TRUE),
 (5, 'Domingo Pop Ical',    '9000 00005 1609', '5512 0055', 'Sepacuite, Senahu',         '2014-08-09', TRUE),
 (6, 'Rosa Caal Mo',        '9000 00006 1609', '5512 0066', 'Chicanuz, Senahu',          '2019-02-25', TRUE),
 (7, 'Vicente Tzalam Chen', '9000 00007 1604', '5512 0077', 'Chiyuc, San Cristobal V.',  '2020-09-30', TRUE),
 (8, 'Petrona Choc Rax',    '9000 00008 1604', '5512 0088', 'Najquitob, San Cristobal V.','2013-04-11', FALSE);


-- ---------------------------------------------------------------------
-- 3. Temporadas (2)
-- ---------------------------------------------------------------------
INSERT INTO Temporadas
 (id_temporada, anio, fecha_inicio, fecha_cierre, estado, precio_base_quintal) VALUES
 (1, 2025, '2024-11-01', '2025-04-30', 'Cerrada',  1150.00),
 (2, 2026, '2025-11-01', NULL,         'En curso', 1285.00);


-- ---------------------------------------------------------------------
-- 4. Etapas del beneficiado (7, en orden)
-- ---------------------------------------------------------------------
INSERT INTO EtapasProceso
 (id_etapa, nombre, orden, duracion_min_horas, duracion_max_horas, descripcion) VALUES
 (1, 'Despulpado',    1,   0.00,  10.00, 'Retiro de la pulpa del cafe maduro el mismo dia del corte.'),
 (2, 'Fermentacion',  2,   6.00,  48.00, 'Fermentado en pila para desprender el mucilago.'),
 (3, 'Lavado',        3,   1.00,   4.00, 'Lavado en canal de correteo; separa el grano vano.'),
 (4, 'Secado',        4, 100.00, 240.00, 'Secado en patio o secadora hasta 11-12 % de humedad.'),
 (5, 'Trillado',      5,   2.00,   8.00, 'Retiro del pergamino para obtener cafe oro.'),
 (6, 'Clasificacion', 6,   2.00,   8.00, 'Clasificacion por tamano, densidad y color.'),
 (7, 'Empaque',       7,   1.00,   6.00, 'Empaque en sacos de yute con marca del lote.');


-- ---------------------------------------------------------------------
-- 5. Bodegas (2)
-- ---------------------------------------------------------------------
INSERT INTO Bodegas
 (id_bodega, nombre, ubicacion, capacidad_quintales, responsable, activa) VALUES
 (1, 'Bodega Central Coban', 'Km 212 ruta a Coban, zona 4', 160.00, 'Julio Rax Sierra',   TRUE),
 (2, 'Bodega Senahu',        'Aldea Sepacuite, Senahu',      60.00, 'Marta Quim Cholom', TRUE);


-- ---------------------------------------------------------------------
-- 6. Compradores (3)
-- ---------------------------------------------------------------------
INSERT INTO Compradores
 (id_comprador, nombre, tipo, pais_destino, contacto, telefono, activo) VALUES
 (1, 'Cafe de Altura Export, S.A.', 'Exportador',    'Alemania',  'Gerencia de compras', '2233 4455', TRUE),
 (2, 'Tostaduria Quetzal',          'Tostador',      'Guatemala', 'Mesa de compras',     '2233 6677', TRUE),
 (3, 'Acopiadora Las Verapaces',    'Intermediario', 'Guatemala', 'Oficina Coban',       '7951 8899', TRUE);


-- ---------------------------------------------------------------------
-- 7. Parcelas (10) - altitudes de 900 a 1700 m
-- ---------------------------------------------------------------------
INSERT INTO Parcelas
 (id_parcela, id_productor, id_variedad, nombre, ubicacion, area_manzanas, altitud_metros, certificacion, activa) VALUES
 ( 1, 1, 1, 'El Manantial',  'Chirrepeco, Coban',          3.50, 1450, 'Organico',    TRUE),
 ( 2, 1, 2, 'La Cumbre',     'Chirrepeco alto, Coban',     2.25, 1550, 'Organico',    TRUE),
 ( 3, 2, 2, 'Santa Elena',   'Santa Cruz, Coban',          4.00, 1200, 'Ninguna',     TRUE),
 ( 4, 3, 4, 'Los Encinos',   'Sacsuha, San Pedro Carcha',  2.75, 1350, 'Fair Trade',  TRUE),
 ( 5, 4, 3, 'El Cafetal',    'Chicoj, San Pedro Carcha',   5.50, 1600, 'Rainforest',  TRUE),
 ( 6, 4, 5, 'Las Nubes',     'Chicoj bajo, San Pedro C.',  1.75, 1050, 'Ninguna',     TRUE),
 ( 7, 5, 1, 'San Jose',      'Sepacuite, Senahu',          3.00, 1300, 'UTZ',         TRUE),
 ( 8, 6, 2, 'El Volcancito', 'Chicanuz, Senahu',           4.25, 1700, 'Organico',    TRUE),
 ( 9, 7, 4, 'Buena Vista',   'Chiyuc, San Cristobal V.',   2.00,  950, 'Fair Trade',  TRUE),
 (10, 8, 5, 'La Esperanza',  'Najquitob, San Cristobal V.',1.50,  900, 'Ninguna',     FALSE);


-- ---------------------------------------------------------------------
-- 8. Cosechas (12) - peso_bruto_kg es GENERATED, no se inserta
-- ---------------------------------------------------------------------
INSERT INTO Cosechas
 (id_cosecha, id_parcela, id_temporada, fecha_recoleccion, peso_bruto_quintales,
  humedad_porcentaje, recolector, observaciones) VALUES
 ( 1,  1, 1, '2024-12-10', 42.00, 53.20, 'Cuadrilla Ba Caal',    'Corte selectivo de cereza madura.'),
 ( 2,  3, 1, '2025-01-08', 35.50, 54.80, 'Cuadrilla Cac',        'Segundo pase de corte.'),
 ( 3,  4, 1, '2025-01-20', 28.00, 55.10, 'Cuadrilla Coc',        'Lluvia fuerte durante la recoleccion.'),
 ( 4,  5, 1, '2025-02-02', 51.00, 52.40, 'Cuadrilla Xol',        'Lote parejo, cereza uniforme.'),
 ( 5,  7, 1, '2025-02-14', 33.00, 56.00, 'Cuadrilla Pop',        'Se corto con exceso de cereza sobremadura.'),
 ( 6,  8, 1, '2025-03-01', 45.00, 51.80, 'Cuadrilla Caal',       'Ultimo pase de la temporada 2025.'),
 ( 7,  2, 2, '2025-12-15', 47.50, 52.90, 'Cuadrilla Ba Caal',    'Primer corte de la temporada 2026.'),
 ( 8,  4, 2, '2026-01-05', 30.00, 54.30, 'Cuadrilla Coc',        'Corte manual, cereza madura.'),
 ( 9,  6, 2, '2026-01-18', 26.50, 55.60, 'Cuadrilla Xol',        'Parcela baja, maduracion despareja.'),
 (10,  7, 2, '2026-02-01', 38.00, 53.70, 'Cuadrilla Pop',        'Pendiente de ingresar a beneficiado.'),
 (11,  8, 2, '2026-02-12', 22.00, 52.10, 'Cuadrilla Caal',       'Corte pequeno de altura.'),
 (12,  9, 2, '2026-02-20', 19.50, 56.40, 'Cuadrilla Tzalam',     'Parcela nueva en produccion.');


-- ---------------------------------------------------------------------
-- 9. Lotes (12) - peso_actual_quintales y estado_lote puestos a mano,
--    ya calculados (los triggers no corren durante la carga).
-- ---------------------------------------------------------------------
INSERT INTO Lotes
 (id_lote, id_cosecha, codigo_lote, fecha_creacion, peso_inicial_quintales,
  peso_actual_quintales, estado_lote, certificacion_aplicable) VALUES
 ( 1,  1, 'CAF-2025-001', '2024-12-10 17:30:00', 42.00, 38.50, 'Vendido',    'Organico'),
 ( 2,  2, 'CAF-2025-002', '2025-01-08 16:45:00', 35.50, 32.00, 'En bodega',  'Ninguna'),
 ( 3,  3, 'CAF-2025-003', '2025-01-20 17:10:00', 28.00, 20.10, 'En bodega',  'Fair Trade'),
 ( 4,  4, 'CAF-2025-004', '2025-02-02 16:20:00', 51.00, 46.20, 'Vendido',    'Rainforest'),
 ( 5,  5, 'CAF-2025-005', '2025-02-14 17:55:00', 33.00, 29.80, 'Rechazado',  'UTZ'),
 ( 6,  6, 'CAF-2025-006', '2025-03-01 16:05:00', 45.00, 41.30, 'En bodega',  'Organico'),
 ( 7,  7, 'CAF-2026-001', '2025-12-15 17:40:00', 47.50, 43.20, 'Vendido',    'Organico'),
 ( 8,  8, 'CAF-2026-002', '2026-01-05 16:30:00', 30.00, 27.30, 'En proceso', 'Fair Trade'),
 ( 9,  9, 'CAF-2026-003', '2026-01-18 17:15:00', 26.50, 24.80, 'En proceso', 'Ninguna'),
 (10, 10, 'CAF-2026-004', '2026-02-01 16:50:00', 38.00, 37.24, 'En acopio',  'UTZ'),
 (11, 11, 'CAF-2026-005', '2026-02-12 17:25:00', 22.00, 21.70, 'En acopio',  'Organico'),
 (12, 12, 'CAF-2026-006', '2026-02-20 16:35:00', 19.50, 18.60, 'En proceso', 'Fair Trade');


-- ---------------------------------------------------------------------
-- 10. Acopios (12) - merma de transporte de 1 a 3 %,
--     salvo el lote CAF-2025-003 que llega con 20 % de perdida.
-- ---------------------------------------------------------------------
INSERT INTO Acopios
 (id_acopio, id_lote, fecha_recepcion, peso_recibido_quintales,
  responsable_recepcion, condicion_transporte, observaciones) VALUES
 ( 1,  1, '2024-12-10 18:40:00', 41.10, 'Julio Rax Sierra',   'Buena',   'Merma 2.14 % por transporte, dentro de lo normal.'),
 ( 2,  2, '2025-01-08 18:05:00', 34.80, 'Julio Rax Sierra',   'Buena',   'Merma 1.97 %.'),
 ( 3,  3, '2025-01-20 19:20:00', 22.40, 'Julio Rax Sierra',   'Mala',    'Volcadura del pick-up en el camino de terraceria: se perdio 20 % de la carga.'),
 ( 4,  4, '2025-02-02 17:50:00', 50.20, 'Julio Rax Sierra',   'Buena',   'Merma 1.57 %.'),
 ( 5,  5, '2025-02-14 19:05:00', 32.20, 'Marta Quim Cholom',  'Regular', 'Merma 2.42 %; cereza sobremadura.'),
 ( 6,  6, '2025-03-01 17:30:00', 44.10, 'Marta Quim Cholom',  'Buena',   'Merma 2.00 %.'),
 ( 7,  7, '2025-12-15 18:55:00', 46.55, 'Julio Rax Sierra',   'Buena',   'Merma 2.00 %; cereza en buen estado.'),
 ( 8,  8, '2026-01-05 18:10:00', 29.10, 'Julio Rax Sierra',   'Regular', 'Merma 3.00 % por demora en el traslado.'),
 ( 9,  9, '2026-01-18 18:45:00', 25.97, 'Julio Rax Sierra',   'Buena',   'Merma 2.00 %.'),
 (10, 10, '2026-02-01 18:20:00', 37.24, 'Marta Quim Cholom',  'Buena',   'Merma 2.00 %; pendiente de despulpar.'),
 (11, 11, '2026-02-12 18:35:00', 21.70, 'Marta Quim Cholom',  'Buena',   'Merma 1.36 %.'),
 (12, 12, '2026-02-20 18:15:00', 19.11, 'Julio Rax Sierra',   'Buena',   'Merma 2.00 %.');


-- ---------------------------------------------------------------------
-- 11. Procesos - beneficiado por etapas, con tiempos realistas.
--     Lotes 1-7: las 7 etapas completas.
--     Lote 8: hasta Trillado. Lote 9: Secado en curso (sin fecha_fin).
--     Lotes 10 y 11: todavia sin procesar. Lote 12: dos etapas.
-- ---------------------------------------------------------------------

-- Lote 1 (CAF-2025-001): 41.10 -> 38.50
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (1, 1, '2024-12-10 19:00:00', '2024-12-11 01:00:00', 41.10, 40.20, 'Julio Rax Sierra'),
 (1, 2, '2024-12-11 01:00:00', '2024-12-11 19:00:00', 40.20, 39.80, 'Julio Rax Sierra'),
 (1, 3, '2024-12-11 19:00:00', '2024-12-11 22:00:00', 39.80, 39.60, 'Elmer Chub Bol'),
 (1, 4, '2024-12-12 06:00:00', '2024-12-18 16:00:00', 39.60, 39.00, 'Elmer Chub Bol'),
 (1, 5, '2024-12-20 08:00:00', '2024-12-20 14:00:00', 39.00, 38.80, 'Elmer Chub Bol'),
 (1, 6, '2024-12-20 14:30:00', '2024-12-20 18:30:00', 38.80, 38.60, 'Sonia Tec Maas'),
 (1, 7, '2024-12-21 08:00:00', '2024-12-21 11:00:00', 38.60, 38.50, 'Sonia Tec Maas');

-- Lote 2 (CAF-2025-002): 34.80 -> 32.40
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (2, 1, '2025-01-08 19:00:00', '2025-01-09 02:00:00', 34.80, 34.00, 'Julio Rax Sierra'),
 (2, 2, '2025-01-09 02:00:00', '2025-01-09 22:00:00', 34.00, 33.60, 'Julio Rax Sierra'),
 (2, 3, '2025-01-09 22:00:00', '2025-01-10 01:00:00', 33.60, 33.40, 'Elmer Chub Bol'),
 (2, 4, '2025-01-10 06:00:00', '2025-01-17 10:00:00', 33.40, 32.90, 'Elmer Chub Bol'),
 (2, 5, '2025-01-19 08:00:00', '2025-01-19 13:00:00', 32.90, 32.70, 'Elmer Chub Bol'),
 (2, 6, '2025-01-19 13:30:00', '2025-01-19 17:30:00', 32.70, 32.50, 'Sonia Tec Maas'),
 (2, 7, '2025-01-20 08:00:00', '2025-01-20 10:30:00', 32.50, 32.40, 'Sonia Tec Maas');

-- Lote 3 (CAF-2025-003): 22.40 -> 20.10
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (3, 1, '2025-01-20 20:00:00', '2025-01-21 03:00:00', 22.40, 21.80, 'Julio Rax Sierra'),
 (3, 2, '2025-01-21 03:00:00', '2025-01-22 00:00:00', 21.80, 21.40, 'Julio Rax Sierra'),
 (3, 3, '2025-01-22 00:00:00', '2025-01-22 03:00:00', 21.40, 21.20, 'Elmer Chub Bol'),
 (3, 4, '2025-01-22 07:00:00', '2025-01-29 12:00:00', 21.20, 20.60, 'Elmer Chub Bol'),
 (3, 5, '2025-01-31 08:00:00', '2025-01-31 12:00:00', 20.60, 20.40, 'Elmer Chub Bol'),
 (3, 6, '2025-01-31 13:00:00', '2025-01-31 16:00:00', 20.40, 20.20, 'Sonia Tec Maas'),
 (3, 7, '2025-02-03 08:00:00', '2025-02-03 10:00:00', 20.20, 20.10, 'Sonia Tec Maas');

-- Lote 4 (CAF-2025-004): 50.20 -> 46.20
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (4, 1, '2025-02-02 18:30:00', '2025-02-03 02:30:00', 50.20, 49.10, 'Julio Rax Sierra'),
 (4, 2, '2025-02-03 02:30:00', '2025-02-04 00:30:00', 49.10, 48.40, 'Julio Rax Sierra'),
 (4, 3, '2025-02-04 00:30:00', '2025-02-04 04:00:00', 48.40, 48.10, 'Elmer Chub Bol'),
 (4, 4, '2025-02-04 07:00:00', '2025-02-12 15:00:00', 48.10, 47.10, 'Elmer Chub Bol'),
 (4, 5, '2025-02-14 08:00:00', '2025-02-14 15:00:00', 47.10, 46.70, 'Elmer Chub Bol'),
 (4, 6, '2025-02-14 15:30:00', '2025-02-14 20:30:00', 46.70, 46.40, 'Sonia Tec Maas'),
 (4, 7, '2025-02-15 08:00:00', '2025-02-15 11:30:00', 46.40, 46.20, 'Sonia Tec Maas');

-- Lote 5 (CAF-2025-005): 32.20 -> 29.80  (sera rechazado en catacion)
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (5, 1, '2025-02-14 19:30:00', '2025-02-15 03:30:00', 32.20, 31.50, 'Marta Quim Cholom'),
 (5, 2, '2025-02-15 03:30:00', '2025-02-17 03:30:00', 31.50, 30.90, 'Marta Quim Cholom'),
 (5, 3, '2025-02-17 03:30:00', '2025-02-17 07:00:00', 30.90, 30.70, 'Marta Quim Cholom'),
 (5, 4, '2025-02-17 08:00:00', '2025-02-24 12:00:00', 30.70, 30.20, 'Elmer Chub Bol'),
 (5, 5, '2025-02-26 08:00:00', '2025-02-26 13:00:00', 30.20, 30.00, 'Elmer Chub Bol'),
 (5, 6, '2025-02-26 13:30:00', '2025-02-26 17:00:00', 30.00, 29.90, 'Sonia Tec Maas'),
 (5, 7, '2025-02-27 08:00:00', '2025-02-27 10:00:00', 29.90, 29.80, 'Sonia Tec Maas');

-- Lote 6 (CAF-2025-006): 44.10 -> 41.30
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (6, 1, '2025-03-01 18:00:00', '2025-03-02 01:00:00', 44.10, 43.20, 'Marta Quim Cholom'),
 (6, 2, '2025-03-02 01:00:00', '2025-03-02 21:00:00', 43.20, 42.70, 'Marta Quim Cholom'),
 (6, 3, '2025-03-02 21:00:00', '2025-03-03 00:30:00', 42.70, 42.50, 'Marta Quim Cholom'),
 (6, 4, '2025-03-03 06:00:00', '2025-03-10 14:00:00', 42.50, 41.80, 'Elmer Chub Bol'),
 (6, 5, '2025-03-12 08:00:00', '2025-03-12 14:00:00', 41.80, 41.55, 'Elmer Chub Bol'),
 (6, 6, '2025-03-12 14:30:00', '2025-03-12 18:30:00', 41.55, 41.40, 'Sonia Tec Maas'),
 (6, 7, '2025-03-13 08:00:00', '2025-03-13 11:00:00', 41.40, 41.30, 'Sonia Tec Maas');

-- Lote 7 (CAF-2026-001): 46.55 -> 43.20  (lote de demostracion, cadena completa)
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (7, 1, '2025-12-15 19:10:00', '2025-12-16 02:10:00', 46.55, 45.60, 'Julio Rax Sierra'),
 (7, 2, '2025-12-16 02:10:00', '2025-12-16 22:10:00', 45.60, 45.00, 'Julio Rax Sierra'),
 (7, 3, '2025-12-16 22:10:00', '2025-12-17 01:40:00', 45.00, 44.70, 'Elmer Chub Bol'),
 (7, 4, '2025-12-17 06:00:00', '2025-12-25 16:00:00', 44.70, 43.90, 'Elmer Chub Bol'),
 (7, 5, '2025-12-29 08:00:00', '2025-12-29 14:00:00', 43.90, 43.55, 'Elmer Chub Bol'),
 (7, 6, '2025-12-29 14:30:00', '2025-12-29 19:00:00', 43.55, 43.35, 'Sonia Tec Maas'),
 (7, 7, '2026-01-05 08:00:00', '2026-01-05 11:30:00', 43.35, 43.20, 'Sonia Tec Maas');

-- Lote 8 (CAF-2026-002): 29.10 -> 27.30, avanzado hasta Trillado
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (8, 1, '2026-01-05 19:00:00', '2026-01-06 01:00:00', 29.10, 28.50, 'Julio Rax Sierra'),
 (8, 2, '2026-01-06 01:00:00', '2026-01-06 20:00:00', 28.50, 28.10, 'Julio Rax Sierra'),
 (8, 3, '2026-01-06 20:00:00', '2026-01-06 23:00:00', 28.10, 27.90, 'Elmer Chub Bol'),
 (8, 4, '2026-01-07 06:00:00', '2026-01-14 12:00:00', 27.90, 27.50, 'Elmer Chub Bol'),
 (8, 5, '2026-01-16 08:00:00', '2026-01-16 13:00:00', 27.50, 27.30, 'Elmer Chub Bol');

-- Lote 9 (CAF-2026-003): 25.97 -> 24.80, Secado todavia en curso
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (9, 1, '2026-01-18 19:00:00', '2026-01-19 01:30:00', 25.97, 25.30, 'Julio Rax Sierra'),
 (9, 2, '2026-01-19 01:30:00', '2026-01-19 21:30:00', 25.30, 25.00, 'Julio Rax Sierra'),
 (9, 3, '2026-01-19 21:30:00', '2026-01-20 00:30:00', 25.00, 24.80, 'Elmer Chub Bol'),
 (9, 4, '2026-01-20 06:00:00', NULL,                  24.80, NULL,  'Elmer Chub Bol');

-- Lote 12 (CAF-2026-006): 19.11 -> 18.60, despulpado y fermentacion
INSERT INTO Procesos
 (id_lote, id_etapa, fecha_inicio, fecha_fin, peso_entrada_quintales, peso_salida_quintales, responsable) VALUES
 (12, 1, '2026-02-20 19:00:00', '2026-02-21 00:30:00', 19.11, 18.80, 'Julio Rax Sierra'),
 (12, 2, '2026-02-21 00:30:00', '2026-02-21 18:30:00', 18.80, 18.60, 'Julio Rax Sierra');


-- ---------------------------------------------------------------------
-- 12. Calidad - solo los lotes que terminaron el beneficiado.
--     Seis aprobados (SCA 80-88) y uno rechazado.
-- ---------------------------------------------------------------------
INSERT INTO Calidad
 (id_calidad, id_lote, fecha_evaluacion, evaluador, puntaje_sca, altura_taza,
  defectos_principales, perfil_sensorial, aprobado_venta) VALUES
 (1, 1, '2024-12-21 15:00:00', 'Karla Siquic Pacay', 86.25, 'Estrictamente Altura',
     'Ninguno relevante', 'Chocolate oscuro, panela y naranja; acidez citrica media-alta, cuerpo sedoso.', TRUE),
 (2, 2, '2025-01-20 14:30:00', 'Karla Siquic Pacay', 84.00, 'Altura',
     'Dos granos negros por libra', 'Nuez, caramelo y manzana verde; acidez media, cuerpo redondo.', TRUE),
 (3, 3, '2025-02-03 15:15:00', 'Karla Siquic Pacay', 81.50, 'Altura',
     'Leve sabor a mojado por la volcadura', 'Cacao y cereal; acidez baja, final corto.', TRUE),
 (4, 4, '2025-02-15 14:00:00', 'Byron Macz Tzul',    88.00, 'Estrictamente Altura',
     'Ninguno', 'Jazmin, durazno y miel; acidez brillante, cuerpo jugoso. Lote de microlote.', TRUE),
 (5, 5, '2025-02-27 14:45:00', 'Byron Macz Tzul',    79.00, 'Central',
     'Fermento excesivo, sobremaduro, 8 defectos primarios', 'Sabor vinoso y astringente; no cumple el minimo de la cooperativa.', FALSE),
 (6, 6, '2025-03-13 15:30:00', 'Karla Siquic Pacay', 85.25, 'Estrictamente Altura',
     'Ninguno relevante', 'Chocolate con leche, ciruela y vainilla; acidez malica, cuerpo cremoso.', TRUE),
 (7, 7, '2026-01-05 15:00:00', 'Byron Macz Tzul',    87.50, 'Estrictamente Altura',
     'Ninguno', 'Bergamota, cacao y mandarina; acidez citrica limpia, cuerpo aterciopelado.', TRUE);


-- ---------------------------------------------------------------------
-- 13. Mermas registradas (las relevantes; las de transporte menores
--     quedan documentadas en las observaciones del acopio)
-- ---------------------------------------------------------------------
INSERT INTO Mermas
 (id_merma, id_lote, tipo_merma, etapa_origen, peso_perdido_quintales, porcentaje_merma,
  fecha_registro, responsable, justificacion) VALUES
 (1, 3, 'Transporte',     'Acopio',  5.60, 20.00, '2025-01-20 19:30:00', 'Julio Rax Sierra',
     'Volcadura del vehiculo en el camino de terraceria; se perdio y contamino parte de la cereza.'),
 (2, 1, 'Proceso',        'Proceso', 2.60,  6.33, '2024-12-21 12:00:00', 'Elmer Chub Bol',
     'Perdida acumulada normal de despulpado, secado y trillado.'),
 (3, 2, 'Almacenamiento', 'Bodega',  0.40,  1.23, '2025-03-18 11:00:00', 'Julio Rax Sierra',
     'Saco danado por humedad en la bodega central; se descarto el grano afectado.'),
 (4, 5, 'Proceso',        'Proceso', 2.40,  7.45, '2025-02-27 11:00:00', 'Elmer Chub Bol',
     'Perdida por exceso de fermentacion y descarte de grano sobremaduro.'),
 (5, 7, 'Proceso',        'Proceso', 3.35,  7.20, '2026-01-05 12:00:00', 'Elmer Chub Bol',
     'Perdida acumulada normal del beneficiado humedo y seco.'),
 (6, 9, 'Natural',        'Cosecha', 0.53,  2.00, '2026-01-18 18:50:00', 'Ana Xol Tiul',
     'Cereza vana y deshidratada separada antes del despulpado.');


-- ---------------------------------------------------------------------
-- 14. Ventas (3) - total_venta es GENERATED, no se inserta
-- ---------------------------------------------------------------------
INSERT INTO VentasLotes
 (id_venta, id_lote, id_comprador, fecha_venta, peso_vendido_quintales, precio_quintal,
  forma_pago, estado_pago, usuario_registro) VALUES
 (1, 1, 1, '2025-01-15 10:00:00', 38.50, 1250.00, 'Contado',         'Pagado', 'gerente1'),
 (2, 4, 1, '2025-03-20 14:00:00', 46.20, 1410.00, 'Credito 30 dias', 'Pagado', 'gerente1'),
 (3, 7, 2, '2026-03-10 15:30:00', 43.20, 1320.00, 'Contado',         'Pagado', 'gerente1');


-- ---------------------------------------------------------------------
-- 15. Movimientos de bodega
--     Solo ingresan lotes aprobados en catacion y nunca sale mas de lo
--     que hay. La existencia se calcula con estos movimientos:
--       Bodega Central Coban -> 32.00 + 20.10 = 52.10 qq
--       Bodega Senahu        -> 41.30 qq
-- ---------------------------------------------------------------------
INSERT INTO MovimientosBodega
 (id_movimiento, id_bodega, id_lote, tipo_movimiento, fecha_movimiento, cantidad_quintales,
  id_venta, responsable, usuario_registro, observaciones) VALUES
 ( 1, 1,  1, 'Entrada',          '2024-12-22 09:00:00', 38.50, NULL, 'Julio Rax Sierra',  'acopiador1', 'Ingreso de lote aprobado (SCA 86.25).'),
 ( 2, 1,  1, 'Salida por venta', '2025-01-15 10:30:00', 38.50,    1, 'Julio Rax Sierra',  'gerente1',   'Despacho a Cafe de Altura Export.'),
 ( 3, 1,  2, 'Entrada',          '2025-01-22 09:30:00', 32.40, NULL, 'Julio Rax Sierra',  'acopiador1', 'Ingreso de lote aprobado (SCA 84.00).'),
 ( 4, 1,  3, 'Entrada',          '2025-02-05 08:45:00', 20.10, NULL, 'Julio Rax Sierra',  'acopiador1', 'Ingreso de lote aprobado (SCA 81.50).'),
 ( 5, 1,  4, 'Entrada',          '2025-02-18 09:15:00', 46.20, NULL, 'Julio Rax Sierra',  'acopiador1', 'Ingreso de microlote aprobado (SCA 88.00).'),
 ( 6, 1,  4, 'Salida por venta', '2025-03-20 14:30:00', 46.20,    2, 'Julio Rax Sierra',  'gerente1',   'Despacho a Cafe de Altura Export.'),
 ( 7, 2,  6, 'Entrada',          '2025-03-14 10:20:00', 41.30, NULL, 'Marta Quim Cholom', 'acopiador1', 'Ingreso de lote aprobado (SCA 85.25).'),
 ( 8, 1,  2, 'Salida por merma', '2025-03-18 11:00:00',  0.40, NULL, 'Julio Rax Sierra',  'acopiador1', 'Saco danado por humedad; ver merma 3.'),
 ( 9, 1,  7, 'Entrada',          '2026-01-08 09:00:00', 43.20, NULL, 'Julio Rax Sierra',  'acopiador1', 'Ingreso de lote aprobado (SCA 87.50).'),
 (10, 1,  7, 'Salida por venta', '2026-03-10 16:00:00', 43.20,    3, 'Julio Rax Sierra',  'gerente1',   'Despacho a Tostaduria Quetzal.');


-- ---------------------------------------------------------------------
-- 16. Pagos a productores (3) - monto_neto es GENERATED, no se inserta
-- ---------------------------------------------------------------------
INSERT INTO Pagos
 (id_pago, id_productor, id_venta, fecha_pago, monto_pagado, precio_pagado_quintal,
  deducciones, metodo_pago, comprobante, usuario_registro) VALUES
 (1, 1, 1, '2025-01-20 11:00:00', 44275.00, 1150.00, 1200.00, 'Transferencia', 'TRF-2025-0012', 'gerente1'),
 (2, 4, 2, '2025-03-28 10:30:00', 60060.00, 1300.00, 1500.00, 'Cheque',        'CHQ-2025-0087', 'gerente1'),
 (3, 1, 3, '2026-03-14 11:15:00', 52704.00, 1220.00,  900.00, 'Transferencia', 'TRF-2026-0034', 'gerente1');


-- Fin de la carga: los triggers vuelven a actuar con normalidad.
SET @cafetrack_carga = NULL;


-- =====================================================================
-- Verificacion: conteo por tabla
-- =====================================================================
SELECT 'Variedades'        AS tabla, COUNT(*) AS registros FROM Variedades
UNION ALL SELECT 'Productores',       COUNT(*) FROM Productores
UNION ALL SELECT 'Temporadas',        COUNT(*) FROM Temporadas
UNION ALL SELECT 'EtapasProceso',     COUNT(*) FROM EtapasProceso
UNION ALL SELECT 'Bodegas',           COUNT(*) FROM Bodegas
UNION ALL SELECT 'Compradores',       COUNT(*) FROM Compradores
UNION ALL SELECT 'Parcelas',          COUNT(*) FROM Parcelas
UNION ALL SELECT 'Cosechas',          COUNT(*) FROM Cosechas
UNION ALL SELECT 'Lotes',             COUNT(*) FROM Lotes
UNION ALL SELECT 'Acopios',           COUNT(*) FROM Acopios
UNION ALL SELECT 'Procesos',          COUNT(*) FROM Procesos
UNION ALL SELECT 'Calidad',           COUNT(*) FROM Calidad
UNION ALL SELECT 'Mermas',            COUNT(*) FROM Mermas
UNION ALL SELECT 'VentasLotes',       COUNT(*) FROM VentasLotes
UNION ALL SELECT 'MovimientosBodega', COUNT(*) FROM MovimientosBodega
UNION ALL SELECT 'Pagos',             COUNT(*) FROM Pagos
UNION ALL SELECT 'BitacoraAuditoria', COUNT(*) FROM BitacoraAuditoria
UNION ALL SELECT 'Usuarios',          COUNT(*) FROM Usuarios;

-- Comprobacion de la existencia calculada (no almacenada) por bodega:
SELECT b.nombre AS bodega,
       COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                         THEN mb.cantidad_quintales
                         ELSE -mb.cantidad_quintales END), 0) AS existencia_quintales,
       b.capacidad_quintales
  FROM Bodegas b
  LEFT JOIN MovimientosBodega mb ON mb.id_bodega = b.id_bodega
 GROUP BY b.id_bodega, b.nombre, b.capacidad_quintales
 ORDER BY b.nombre;

-- =====================================================================
-- 03_usuario_app.sql: Usuario de aplicacion
-- =====================================================================
-- =====================================================================
-- CafeTrack - Usuario de aplicacion para MySQL
-- Ejecutar como root, DESPUES de 01_estructura.sql
--
-- IMPORTANTE: cambie la contrasena antes de ejecutarlo y no la guarde en
-- ningun archivo versionado. La contrasena real vive solo en User Secrets:
--   dotnet user-secrets set "ConnectionStrings:CafeTrack" ^
--     "Server=localhost;Port=3306;Database=trazabilidad_cafe;User=cafetrack_dev;Password=...;"
-- =====================================================================

CREATE USER IF NOT EXISTS 'cafetrack_dev'@'localhost'
  IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';

GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
  ON trazabilidad_cafe.*
  TO 'cafetrack_dev'@'localhost';

FLUSH PRIVILEGES;

-- Verificacion de los permisos otorgados:
SHOW GRANTS FOR 'cafetrack_dev'@'localhost';

-- ---------------------------------------------------------------------
-- Cada rol de la aplicacion tiene su propio usuario de MySQL con permisos
-- distintos. Los crea sql/06_seguridad.sql; este es el resumen:
--
--   cafetrack_admin      -> todo sobre trazabilidad_cafe
--   cafetrack_gerente    -> SELECT en todo; INSERT/UPDATE en VentasLotes y Pagos
--   cafetrack_acopiador  -> SELECT + INSERT en Acopios, Lotes, MovimientosBodega
--   cafetrack_catador    -> SELECT + INSERT/UPDATE en Calidad
--   cafetrack_auditor    -> solo SELECT (incluida BitacoraAuditoria)
-- ---------------------------------------------------------------------

-- =====================================================================
-- 04_rutinas.sql: Funcion de existencia, procedimientos y triggers
-- =====================================================================
-- =====================================================================
-- CafeTrack - Funcion, procedimientos y triggers
-- Ejecutar DESPUES de 01_estructura.sql y 02_datos_prueba.sql
--
-- El esquema no cambia: no se crea ni se altera ninguna tabla.
-- La base conserva sus 18 tablas.
--
-- Reglas de negocio que viven aqui:
--   * La existencia en bodega NO se almacena: fn_existencia_lote la calcula.
--   * Nunca puede salir de bodega mas de lo que hay.
--   * Solo ingresan a bodega los lotes aprobados en catacion.
--   * Toda merma descuenta el peso actual del lote.
--   * Las mermas altas y los precios por debajo del precio base de la
--     temporada quedan registrados como alertas en BitacoraAuditoria.
--
-- NOTA sobre la carga de datos: 02_datos_prueba.sql trae los pesos y los
-- estados ya calculados. Para que al recargarlo los triggers no vuelvan a
-- descontar lo mismo, ese script levanta la bandera @cafetrack_carga y los
-- triggers se saltan el cuerpo mientras este activa.
-- =====================================================================

USE trazabilidad_cafe;

-- Si el binlog esta activo y la cuenta no tiene SUPER, MySQL rechaza crear
-- funciones con ERROR 1418. En ese caso ejecute como root, una sola vez:
--   SET GLOBAL log_bin_trust_function_creators = 1;

DROP FUNCTION IF EXISTS fn_existencia_lote;
DROP PROCEDURE IF EXISTS sp_registrar_acopio;
DROP PROCEDURE IF EXISTS sp_registrar_venta;
DROP TRIGGER IF EXISTS trg_movimientos_validar;
DROP TRIGGER IF EXISTS trg_movimientos_estado;
DROP TRIGGER IF EXISTS trg_mermas_descuento;
DROP TRIGGER IF EXISTS trg_ventas_precio;

DELIMITER $$

-- ---------------------------------------------------------------------
-- FUNCION: existencia de un lote en bodega
-- 'Entrada' suma; 'Salida por venta', 'Salida por merma' y 'Ajuste' restan.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_existencia_lote(p_id_lote INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_existencia DECIMAL(10,2);

    SELECT COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                             THEN mb.cantidad_quintales
                             ELSE -mb.cantidad_quintales END), 0)
      INTO v_existencia
      FROM MovimientosBodega mb
     WHERE mb.id_lote = p_id_lote;

    RETURN v_existencia;
END$$

-- ---------------------------------------------------------------------
-- PROCEDIMIENTO 1: registrar el acopio de un lote
-- Valida el peso contra lo cosechado, registra la merma de transporte y
-- deja el lote en 'En acopio' con su peso real.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_acopio(
    IN  p_id_lote       INT,
    IN  p_peso_recibido DECIMAL(10,2),
    IN  p_responsable   VARCHAR(100),
    IN  p_condicion     VARCHAR(10),
    IN  p_observaciones TEXT,
    IN  p_usuario       VARCHAR(50),
    OUT p_id_acopio     INT
)
sp: BEGIN
    DECLARE v_peso_cosechado DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_codigo         VARCHAR(20);
    DECLARE v_merma          DECIMAL(10,2);
    DECLARE v_porcentaje     DECIMAL(5,2);

    -- Cualquier error deshace el registro completo y lo vuelve a lanzar
    -- para que la aplicacion muestre el mensaje.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_peso_recibido IS NULL OR p_peso_recibido <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El peso recibido debe ser mayor que cero.';
    END IF;

    IF p_responsable IS NULL OR TRIM(p_responsable) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Debe indicar quien recibe el lote en el centro de acopio.';
    END IF;

    SELECT c.peso_bruto_quintales, l.codigo_lote
      INTO v_peso_cosechado, v_codigo
      FROM Lotes l
      JOIN Cosechas c ON c.id_cosecha = l.id_cosecha
     WHERE l.id_lote = p_id_lote;

    IF v_peso_cosechado IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote indicado no existe.';
    END IF;

    IF EXISTS (SELECT 1 FROM Acopios a WHERE a.id_lote = p_id_lote) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote ya tiene un acopio registrado.';
    END IF;

    IF p_peso_recibido > v_peso_cosechado THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El peso recibido no puede superar el peso cosechado del lote.';
    END IF;

    START TRANSACTION;

    INSERT INTO Acopios (id_lote, peso_recibido_quintales, responsable_recepcion,
                         condicion_transporte, observaciones)
    VALUES (p_id_lote, p_peso_recibido, p_responsable,
            COALESCE(NULLIF(p_condicion, ''), 'Buena'), NULLIF(p_observaciones, ''));

    SET p_id_acopio = LAST_INSERT_ID();

    -- La diferencia contra el peso cosechado se documenta como merma de transporte.
    SET v_merma = v_peso_cosechado - p_peso_recibido;
    IF v_merma > 0 THEN
        SET v_porcentaje = ROUND(v_merma / v_peso_cosechado * 100, 2);
        INSERT INTO Mermas (id_lote, tipo_merma, etapa_origen, peso_perdido_quintales,
                            porcentaje_merma, responsable, justificacion)
        VALUES (p_id_lote, 'Transporte', 'Acopio', v_merma, v_porcentaje, p_responsable,
                CONCAT('Diferencia entre el peso cosechado y el recibido en acopio del lote ',
                       v_codigo, '.'));
    END IF;

    -- El peso real del lote pasa a ser el recibido en acopio.
    UPDATE Lotes
       SET peso_actual_quintales = p_peso_recibido,
           estado_lote = 'En acopio'
     WHERE id_lote = p_id_lote;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Acopios', 'INSERT', p_id_acopio, COALESCE(p_usuario, USER()),
            JSON_OBJECT('id_lote', p_id_lote,
                        'codigo_lote', v_codigo,
                        'peso_recibido_quintales', p_peso_recibido,
                        'merma_quintales', v_merma));

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- PROCEDIMIENTO 2: registrar la venta de un lote
-- Comprueba la existencia con fn_existencia_lote, exige catacion aprobada,
-- inserta la venta y genera la salida de bodega.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_venta(
    IN  p_id_lote      INT,
    IN  p_id_comprador INT,
    IN  p_id_bodega    INT,
    IN  p_peso         DECIMAL(10,2),
    IN  p_precio       DECIMAL(10,2),
    IN  p_forma_pago   VARCHAR(20),
    IN  p_responsable  VARCHAR(100),
    IN  p_usuario      VARCHAR(50),
    OUT p_id_venta     INT
)
sp: BEGIN
    DECLARE v_codigo     VARCHAR(20);
    DECLARE v_existencia DECIMAL(10,2);
    DECLARE v_aprobado   INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_peso IS NULL OR p_peso <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cantidad vendida debe ser mayor que cero.';
    END IF;

    IF p_precio IS NULL OR p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio por quintal debe ser mayor que cero.';
    END IF;

    SELECT l.codigo_lote INTO v_codigo FROM Lotes l WHERE l.id_lote = p_id_lote;

    IF v_codigo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote indicado no existe.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Compradores c
                    WHERE c.id_comprador = p_id_comprador AND c.activo = TRUE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El comprador no existe o esta inactivo.';
    END IF;

    SELECT COUNT(*) INTO v_aprobado
      FROM Calidad ca
     WHERE ca.id_lote = p_id_lote AND ca.aprobado_venta = TRUE;

    IF v_aprobado = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote no tiene una catacion aprobada: no se puede vender.';
    END IF;

    SET v_existencia = fn_existencia_lote(p_id_lote);

    IF v_existencia <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote no tiene existencia en bodega.';
    END IF;

    IF p_peso > v_existencia THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede vender mas de lo que hay en bodega.';
    END IF;

    START TRANSACTION;

    INSERT INTO VentasLotes (id_lote, id_comprador, peso_vendido_quintales, precio_quintal,
                             forma_pago, estado_pago, usuario_registro)
    VALUES (p_id_lote, p_id_comprador, p_peso, p_precio,
            COALESCE(NULLIF(p_forma_pago, ''), 'Contado'), 'Pendiente',
            COALESCE(p_usuario, 'sistema'));

    SET p_id_venta = LAST_INSERT_ID();

    -- La salida de bodega dispara los triggers que validan y actualizan el estado.
    INSERT INTO MovimientosBodega (id_bodega, id_lote, tipo_movimiento, cantidad_quintales,
                                   id_venta, responsable, usuario_registro, observaciones)
    VALUES (p_id_bodega, p_id_lote, 'Salida por venta', p_peso, p_id_venta,
            COALESCE(NULLIF(p_responsable, ''), 'Sin indicar'),
            COALESCE(p_usuario, 'sistema'),
            CONCAT('Despacho de la venta ', p_id_venta, ' del lote ', v_codigo, '.'));

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('VentasLotes', 'INSERT', p_id_venta, COALESCE(p_usuario, USER()),
            JSON_OBJECT('id_lote', p_id_lote,
                        'codigo_lote', v_codigo,
                        'peso_vendido_quintales', p_peso,
                        'precio_quintal', p_precio,
                        'total_venta', p_peso * p_precio));

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 1: valida cada movimiento antes de guardarlo
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_movimientos_validar
BEFORE INSERT ON MovimientosBodega
FOR EACH ROW
cuerpo: BEGIN
    DECLARE v_existencia  DECIMAL(10,2);
    DECLARE v_aprobado    INT DEFAULT 0;
    DECLARE v_capacidad   DECIMAL(10,2);
    DECLARE v_en_bodega   DECIMAL(10,2);

    -- Durante la carga de datos de prueba las cifras ya vienen validadas.
    IF COALESCE(@cafetrack_carga, 0) = 1 THEN
        LEAVE cuerpo;
    END IF;

    IF NEW.tipo_movimiento = 'Entrada' THEN

        SELECT COUNT(*) INTO v_aprobado
          FROM Calidad ca
         WHERE ca.id_lote = NEW.id_lote AND ca.aprobado_venta = TRUE;

        IF v_aprobado = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Solo ingresan a bodega los lotes aprobados en catacion.';
        END IF;

        -- La bodega no puede recibir mas de su capacidad declarada.
        SELECT b.capacidad_quintales INTO v_capacidad
          FROM Bodegas b WHERE b.id_bodega = NEW.id_bodega;

        SELECT COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                                 THEN mb.cantidad_quintales
                                 ELSE -mb.cantidad_quintales END), 0)
          INTO v_en_bodega
          FROM MovimientosBodega mb
         WHERE mb.id_bodega = NEW.id_bodega;

        IF v_capacidad IS NOT NULL AND v_en_bodega + NEW.cantidad_quintales > v_capacidad THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La bodega no tiene capacidad suficiente para ese ingreso.';
        END IF;

    ELSE

        SET v_existencia = fn_existencia_lote(NEW.id_lote);

        IF NEW.cantidad_quintales > v_existencia THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No se puede sacar de bodega mas de lo que hay del lote.';
        END IF;

    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 2: el movimiento define el estado del lote y queda en bitacora
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_movimientos_estado
AFTER INSERT ON MovimientosBodega
FOR EACH ROW
cuerpo: BEGIN
    IF COALESCE(@cafetrack_carga, 0) = 1 THEN
        LEAVE cuerpo;
    END IF;

    IF NEW.tipo_movimiento = 'Entrada' THEN
        UPDATE Lotes
           SET estado_lote = 'En bodega'
         WHERE id_lote = NEW.id_lote
           AND estado_lote NOT IN ('Vendido', 'Rechazado');

    ELSEIF NEW.tipo_movimiento = 'Salida por venta'
           AND fn_existencia_lote(NEW.id_lote) <= 0 THEN
        UPDATE Lotes
           SET estado_lote = 'Vendido'
         WHERE id_lote = NEW.id_lote;
    END IF;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('MovimientosBodega', 'INSERT', NEW.id_movimiento, NEW.usuario_registro,
            JSON_OBJECT('id_lote', NEW.id_lote,
                        'id_bodega', NEW.id_bodega,
                        'tipo_movimiento', NEW.tipo_movimiento,
                        'cantidad_quintales', NEW.cantidad_quintales,
                        'existencia_resultante', fn_existencia_lote(NEW.id_lote)));
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 3: la merma descuenta el peso del lote y avisa si es alta
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_mermas_descuento
AFTER INSERT ON Mermas
FOR EACH ROW
cuerpo: BEGIN
    DECLARE v_peso_inicial DECIMAL(10,2);
    DECLARE v_porcentaje   DECIMAL(6,2);
    DECLARE v_codigo       VARCHAR(20);

    IF COALESCE(@cafetrack_carga, 0) = 1 THEN
        LEAVE cuerpo;
    END IF;

    SELECT l.peso_inicial_quintales, l.codigo_lote
      INTO v_peso_inicial, v_codigo
      FROM Lotes l WHERE l.id_lote = NEW.id_lote;

    UPDATE Lotes
       SET peso_actual_quintales = GREATEST(peso_actual_quintales - NEW.peso_perdido_quintales, 0)
     WHERE id_lote = NEW.id_lote;

    SET v_porcentaje = COALESCE(NEW.porcentaje_merma,
                                ROUND(NEW.peso_perdido_quintales / NULLIF(v_peso_inicial, 0) * 100, 2));

    -- Umbral de la cooperativa: una merma mayor al 15 % se revisa.
    IF v_porcentaje > 15 THEN
        INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                       usuario, datos_nuevos)
        VALUES ('Mermas', 'ALERTA_MERMA_ALTA', NEW.id_merma, NEW.responsable,
                JSON_OBJECT('codigo_lote', v_codigo,
                            'tipo_merma', NEW.tipo_merma,
                            'etapa_origen', NEW.etapa_origen,
                            'peso_perdido_quintales', NEW.peso_perdido_quintales,
                            'porcentaje_merma', v_porcentaje));
    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 4: avisa si la venta quedo por debajo del precio base
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_ventas_precio
AFTER INSERT ON VentasLotes
FOR EACH ROW
cuerpo: BEGIN
    DECLARE v_precio_base DECIMAL(10,2);
    DECLARE v_anio        INT;
    DECLARE v_codigo      VARCHAR(20);

    IF COALESCE(@cafetrack_carga, 0) = 1 THEN
        LEAVE cuerpo;
    END IF;

    SELECT t.precio_base_quintal, t.anio, l.codigo_lote
      INTO v_precio_base, v_anio, v_codigo
      FROM Lotes      l
      JOIN Cosechas   c ON c.id_cosecha   = l.id_cosecha
      JOIN Temporadas t ON t.id_temporada = c.id_temporada
     WHERE l.id_lote = NEW.id_lote;

    IF v_precio_base IS NOT NULL AND NEW.precio_quintal < v_precio_base THEN
        INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                       usuario, datos_nuevos)
        VALUES ('VentasLotes', 'ALERTA_PRECIO_BAJO', NEW.id_venta, NEW.usuario_registro,
                JSON_OBJECT('codigo_lote', v_codigo,
                            'temporada', v_anio,
                            'precio_quintal', NEW.precio_quintal,
                            'precio_base_quintal', v_precio_base,
                            'diferencia', v_precio_base - NEW.precio_quintal));
    END IF;
END$$

DELIMITER ;

-- =====================================================================
-- Verificacion
-- =====================================================================
SELECT ROUTINE_TYPE AS tipo, ROUTINE_NAME AS nombre
  FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'trazabilidad_cafe'
 ORDER BY ROUTINE_TYPE, ROUTINE_NAME;

SELECT TRIGGER_NAME AS trigger_name, EVENT_MANIPULATION AS evento,
       ACTION_TIMING AS momento, EVENT_OBJECT_TABLE AS tabla
  FROM information_schema.TRIGGERS
 WHERE TRIGGER_SCHEMA = 'trazabilidad_cafe'
 ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING;

-- La existencia calculada por la funcion debe coincidir con la suma manual:
SELECT l.codigo_lote,
       fn_existencia_lote(l.id_lote) AS por_funcion,
       COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                         THEN mb.cantidad_quintales
                         ELSE -mb.cantidad_quintales END), 0) AS por_consulta
  FROM Lotes l
  LEFT JOIN MovimientosBodega mb ON mb.id_lote = l.id_lote
 GROUP BY l.id_lote, l.codigo_lote
 ORDER BY l.codigo_lote;

-- =====================================================================
-- 06_seguridad.sql: Usuarios de la app, sp_login y permisos por rol
-- =====================================================================
-- =====================================================================
-- CafeTrack - Seguridad
--   * Usuarios de la aplicacion en la tabla Usuarios (SHA2 + salt)
--   * sp_login para validar las credenciales dentro de la base
--   * Un usuario de MySQL por rol, cada uno con sus propios GRANT
--
-- Ejecutar como root, DESPUES de 04_rutinas.sql.
-- El esquema no cambia: la base conserva sus 18 tablas.
--
-- ALMACENAMIENTO DE LA CONTRASENA
-- La tabla Usuarios no tiene columna de salt, asi que el salt viaja dentro
-- de password_hash con el formato:
--       <salt en hexadecimal> : SHA2(CONCAT(salt, contrasena), 256)
-- El salt es distinto por usuario, de modo que dos personas con la misma
-- contrasena no comparten hash. La contrasena en claro nunca se guarda ni
-- viaja a la aplicacion: la comparacion ocurre dentro de sp_login.
--
-- CONTRASENA TEMPORAL
-- Cuando el administrador asigna una clave temporal, el hash se guarda con
-- el prefijo 'TMP:'  ->  TMP:<salt>:<hash>
-- Asi se marca "debe cambiarla" sin agregar ninguna columna: el esquema
-- sigue intacto con sus 18 tablas. sp_login devuelve esa marca y la
-- aplicacion obliga a cambiarla antes de dejar entrar a ningun lado.
-- =====================================================================

USE trazabilidad_cafe;

-- ---------------------------------------------------------------------
-- 1. Usuarios de la aplicacion (uno por rol)
--    Contrasena de todos en este juego de prueba: Cafe2026!
--    Cambiela antes de cualquier uso real con sp_cambiar_password.
-- ---------------------------------------------------------------------

DELETE FROM Usuarios;

SET @clave = 'Cafe2026!';

SET @salt = HEX(RANDOM_BYTES(16));
INSERT INTO Usuarios (username, password_hash, nombre_completo, rol, activo)
VALUES ('admin', CONCAT(@salt, ':', SHA2(CONCAT(@salt, @clave), 256)),
        'Administrador CafeTrack', 'admin', TRUE);

SET @salt = HEX(RANDOM_BYTES(16));
INSERT INTO Usuarios (username, password_hash, nombre_completo, rol, activo)
VALUES ('gerente', CONCAT(@salt, ':', SHA2(CONCAT(@salt, @clave), 256)),
        'Rosa Ical Chub', 'gerente', TRUE);

SET @salt = HEX(RANDOM_BYTES(16));
INSERT INTO Usuarios (username, password_hash, nombre_completo, rol, activo)
VALUES ('acopiador', CONCAT(@salt, ':', SHA2(CONCAT(@salt, @clave), 256)),
        'Julio Rax Sierra', 'acopiador', TRUE);

SET @salt = HEX(RANDOM_BYTES(16));
INSERT INTO Usuarios (username, password_hash, nombre_completo, rol, activo)
VALUES ('catador', CONCAT(@salt, ':', SHA2(CONCAT(@salt, @clave), 256)),
        'Karla Siquic Pacay', 'catador', TRUE);

SET @salt = HEX(RANDOM_BYTES(16));
INSERT INTO Usuarios (username, password_hash, nombre_completo, rol, activo)
VALUES ('auditor', CONCAT(@salt, ':', SHA2(CONCAT(@salt, @clave), 256)),
        'Hugo Tiul Pop', 'auditor', TRUE);

SET @clave = NULL;
SET @salt = NULL;


-- ---------------------------------------------------------------------
-- 2. Rutinas de autenticacion
-- ---------------------------------------------------------------------

DROP PROCEDURE IF EXISTS sp_login;
DROP PROCEDURE IF EXISTS sp_cambiar_password;

DELIMITER $$

-- Valida las credenciales. Si son correctas actualiza ultimo_acceso, deja
-- rastro en la bitacora y devuelve los datos del usuario; si no, lanza un
-- SIGNAL con el mismo mensaje para usuario inexistente y clave equivocada,
-- para no revelar cual de los dos fallo.
CREATE PROCEDURE sp_login(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE v_id       INT DEFAULT NULL;
    DECLARE v_hash     VARCHAR(255);
    DECLARE v_activo   BOOLEAN;
    DECLARE v_salt     VARCHAR(64);
    DECLARE v_temporal TINYINT DEFAULT 0;

    SELECT u.id_usuario, u.password_hash, u.activo
      INTO v_id, v_hash, v_activo
      FROM Usuarios u
     WHERE u.username = p_username;

    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuario o contrasena incorrectos.';
    END IF;

    IF NOT v_activo THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El usuario esta inactivo. Consulte al administrador.';
    END IF;

    -- El prefijo TMP: marca una clave temporal puesta por el administrador.
    IF LEFT(v_hash, 4) = 'TMP:' THEN
        SET v_temporal = 1;
        SET v_hash = SUBSTRING(v_hash, 5);
    END IF;

    SET v_salt = SUBSTRING_INDEX(v_hash, ':', 1);

    IF SHA2(CONCAT(v_salt, p_password), 256) <> SUBSTRING_INDEX(v_hash, ':', -1) THEN
        -- El intento fallido queda registrado antes de rechazar.
        INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                       usuario, datos_nuevos)
        VALUES ('Usuarios', 'UPDATE', v_id, p_username,
                JSON_OBJECT('evento', 'intento de sesion fallido'));

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuario o contrasena incorrectos.';
    END IF;

    UPDATE Usuarios SET ultimo_acceso = NOW() WHERE id_usuario = v_id;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Usuarios', 'UPDATE', v_id, p_username,
            JSON_OBJECT('evento', 'inicio de sesion'));

    SELECT u.id_usuario, u.username, u.nombre_completo, u.rol, u.activo, u.ultimo_acceso,
           v_temporal AS debe_cambiar
      FROM Usuarios u
     WHERE u.id_usuario = v_id;
END$$

-- Cambia la contrasena generando un salt nuevo. La clave actual se verifica
-- dentro de la base; la aplicacion nunca manipula el hash.
CREATE PROCEDURE sp_cambiar_password(
    IN p_username     VARCHAR(50),
    IN p_password_act VARCHAR(255),
    IN p_password_new VARCHAR(255)
)
BEGIN
    DECLARE v_id   INT DEFAULT NULL;
    DECLARE v_hash VARCHAR(255);
    DECLARE v_salt VARCHAR(64);

    IF p_password_new IS NULL OR CHAR_LENGTH(p_password_new) < 8 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La contrasena nueva debe tener al menos 8 caracteres.';
    END IF;

    SELECT u.id_usuario, u.password_hash INTO v_id, v_hash
      FROM Usuarios u WHERE u.username = p_username;

    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    -- Si la clave vigente es temporal, se le quita el prefijo para compararla.
    IF LEFT(v_hash, 4) = 'TMP:' THEN
        SET v_hash = SUBSTRING(v_hash, 5);
    END IF;

    SET v_salt = SUBSTRING_INDEX(v_hash, ':', 1);

    IF SHA2(CONCAT(v_salt, p_password_act), 256) <> SUBSTRING_INDEX(v_hash, ':', -1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La contrasena actual no es correcta.';
    END IF;

    IF p_password_new = p_password_act THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La contrasena nueva debe ser distinta de la actual.';
    END IF;

    SET v_salt = HEX(RANDOM_BYTES(16));

    UPDATE Usuarios
       SET password_hash = CONCAT(v_salt, ':', SHA2(CONCAT(v_salt, p_password_new), 256))
     WHERE id_usuario = v_id;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Usuarios', 'UPDATE', v_id, p_username,
            JSON_OBJECT('evento', 'cambio de contrasena'));
END$$

DELIMITER ;


-- ---------------------------------------------------------------------
-- 3. Un usuario de MySQL por rol
--
-- La aplicacion abre la conexion con el usuario que corresponde al rol de
-- quien inicio sesion, de modo que los permisos los decide el motor y no
-- solamente la interfaz. Si alguien llega a una pantalla que no le toca,
-- MySQL responde ERROR 1142 y la aplicacion lo muestra como mensaje.
--
-- CAMBIE LAS CONTRASENAS antes de ejecutar. Viven solo en User Secrets.
-- ---------------------------------------------------------------------

CREATE USER IF NOT EXISTS 'cafetrack_admin'@'localhost'     IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';
CREATE USER IF NOT EXISTS 'cafetrack_gerente'@'localhost'   IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';
CREATE USER IF NOT EXISTS 'cafetrack_acopiador'@'localhost' IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';
CREATE USER IF NOT EXISTS 'cafetrack_catador'@'localhost'   IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';
CREATE USER IF NOT EXISTS 'cafetrack_auditor'@'localhost'   IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';

-- admin: todo el esquema
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON trazabilidad_cafe.*
   TO 'cafetrack_admin'@'localhost';

-- gerente: consulta todo; vende y paga
GRANT SELECT ON trazabilidad_cafe.* TO 'cafetrack_gerente'@'localhost';
GRANT INSERT, UPDATE ON trazabilidad_cafe.VentasLotes       TO 'cafetrack_gerente'@'localhost';
GRANT INSERT, UPDATE ON trazabilidad_cafe.Pagos             TO 'cafetrack_gerente'@'localhost';
GRANT INSERT         ON trazabilidad_cafe.MovimientosBodega TO 'cafetrack_gerente'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_registrar_venta TO 'cafetrack_gerente'@'localhost';
GRANT EXECUTE ON FUNCTION  trazabilidad_cafe.fn_existencia_lote TO 'cafetrack_gerente'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_login            TO 'cafetrack_gerente'@'localhost';

-- acopiador: consulta todo; recibe lotes y mueve bodega
GRANT SELECT ON trazabilidad_cafe.* TO 'cafetrack_acopiador'@'localhost';
GRANT INSERT         ON trazabilidad_cafe.Acopios            TO 'cafetrack_acopiador'@'localhost';
GRANT INSERT         ON trazabilidad_cafe.Mermas             TO 'cafetrack_acopiador'@'localhost';
GRANT INSERT         ON trazabilidad_cafe.MovimientosBodega  TO 'cafetrack_acopiador'@'localhost';
GRANT INSERT, UPDATE ON trazabilidad_cafe.Lotes              TO 'cafetrack_acopiador'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_registrar_acopio TO 'cafetrack_acopiador'@'localhost';
GRANT EXECUTE ON FUNCTION  trazabilidad_cafe.fn_existencia_lote  TO 'cafetrack_acopiador'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_login             TO 'cafetrack_acopiador'@'localhost';

-- catador: consulta todo; registra evaluaciones de calidad
GRANT SELECT ON trazabilidad_cafe.* TO 'cafetrack_catador'@'localhost';
GRANT INSERT, UPDATE ON trazabilidad_cafe.Calidad TO 'cafetrack_catador'@'localhost';
GRANT EXECUTE ON FUNCTION  trazabilidad_cafe.fn_existencia_lote TO 'cafetrack_catador'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_login           TO 'cafetrack_catador'@'localhost';

-- auditor: solo lectura, incluida la bitacora
GRANT SELECT ON trazabilidad_cafe.* TO 'cafetrack_auditor'@'localhost';
GRANT EXECUTE ON FUNCTION  trazabilidad_cafe.fn_existencia_lote TO 'cafetrack_auditor'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_login           TO 'cafetrack_auditor'@'localhost';

-- cafetrack_dev sigue siendo la cuenta de desarrollo y la que valida el login
-- cuando todavia no se conoce el rol.
GRANT EXECUTE ON trazabilidad_cafe.* TO 'cafetrack_dev'@'localhost';

FLUSH PRIVILEGES;


-- =====================================================================
-- Verificacion
-- =====================================================================
SELECT username, nombre_completo, rol, activo,
       SUBSTRING_INDEX(password_hash, ':', 1) AS salt,
       CHAR_LENGTH(SUBSTRING_INDEX(password_hash, ':', -1)) AS largo_hash
  FROM Usuarios ORDER BY rol;

SELECT GRANTEE, PRIVILEGE_TYPE
  FROM information_schema.SCHEMA_PRIVILEGES
 WHERE TABLE_SCHEMA = 'trazabilidad_cafe'
 ORDER BY GRANTEE, PRIVILEGE_TYPE;

-- =====================================================================
-- 07_vistas.sql: Once vistas de reporte
-- =====================================================================
-- =====================================================================
-- CafeTrack - Las 11 consultas de reporte, como VISTAS
-- Ejecutar DESPUES de 04_rutinas.sql.
--
-- El esquema no cambia: una vista no es una tabla, asi que la base
-- conserva sus 18 tablas (SHOW TABLES las lista aparte como VIEW).
--
-- Cada vista responde una pregunta del negocio y la aplicacion solo hace
-- SELECT sobre ella: el SQL de los reportes vive en la base, no en C#.
-- Los permisos por rol siguen aplicando, porque las vistas pertenecen al
-- mismo esquema que ya tiene GRANT SELECT.
-- =====================================================================

USE trazabilidad_cafe;


-- ---------------------------------------------------------------------
-- 1. Existencias en bodega
--    ¿Cuanto cafe hay hoy en cada bodega, lote por lote?
--    La existencia no se almacena: se calcula con los movimientos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_existencias_bodega AS
SELECT b.nombre                                              AS bodega,
       b.capacidad_quintales                                 AS capacidad_quintales,
       l.codigo_lote                                         AS codigo_lote,
       p.nombre                                              AS productor,
       l.estado_lote                                         AS estado_lote,
       SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                THEN mb.cantidad_quintales ELSE 0 END)       AS entradas_quintales,
       SUM(CASE WHEN mb.tipo_movimiento <> 'Entrada'
                THEN mb.cantidad_quintales ELSE 0 END)       AS salidas_quintales,
       SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                THEN mb.cantidad_quintales
                ELSE -mb.cantidad_quintales END)             AS existencia_quintales,
       MAX(mb.fecha_movimiento)                              AS ultimo_movimiento
  FROM MovimientosBodega mb
  JOIN Bodegas     b  ON b.id_bodega    = mb.id_bodega
  JOIN Lotes       l  ON l.id_lote      = mb.id_lote
  JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
  JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
  JOIN Productores p  ON p.id_productor = pa.id_productor
 GROUP BY b.id_bodega, b.nombre, b.capacidad_quintales,
          l.id_lote, l.codigo_lote, p.nombre, l.estado_lote
 ORDER BY b.nombre, l.codigo_lote;


-- ---------------------------------------------------------------------
-- 2. Trazabilidad por lote
--    La historia completa de cada lote en una sola fila: de la parcela
--    al estado actual. Es la consulta que sostiene el sistema.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_trazabilidad_lote AS
SELECT l.codigo_lote                     AS codigo_lote,
       p.nombre                          AS productor,
       p.comunidad                       AS comunidad,
       pa.nombre                         AS parcela,
       v.nombre                          AS variedad,
       pa.altitud_metros                 AS altitud_metros,
       pa.certificacion                  AS certificacion,
       t.anio                            AS temporada,
       c.fecha_recoleccion               AS fecha_cosecha,
       c.peso_bruto_quintales            AS cosechado_quintales,
       (SELECT a.fecha_recepcion FROM Acopios a
         WHERE a.id_lote = l.id_lote
         ORDER BY a.fecha_recepcion LIMIT 1)              AS fecha_acopio,
       (SELECT a.peso_recibido_quintales FROM Acopios a
         WHERE a.id_lote = l.id_lote
         ORDER BY a.fecha_recepcion LIMIT 1)              AS recibido_quintales,
       (SELECT COUNT(*) FROM Procesos pr
         WHERE pr.id_lote = l.id_lote)                    AS etapas_registradas,
       (SELECT ca.puntaje_sca FROM Calidad ca
         WHERE ca.id_lote = l.id_lote
         ORDER BY ca.fecha_evaluacion DESC LIMIT 1)       AS puntaje_sca,
       (SELECT CASE WHEN ca.aprobado_venta THEN 'Aprobado' ELSE 'Rechazado' END
          FROM Calidad ca WHERE ca.id_lote = l.id_lote
         ORDER BY ca.fecha_evaluacion DESC LIMIT 1)       AS resultado_catacion,
       l.peso_inicial_quintales          AS peso_inicial_quintales,
       l.peso_actual_quintales           AS peso_actual_quintales,
       ROUND(l.peso_inicial_quintales - l.peso_actual_quintales, 2)
                                         AS merma_acumulada_quintales,
       fn_existencia_lote(l.id_lote)     AS existencia_quintales,
       (SELECT COALESCE(SUM(ve.total_venta), 0) FROM VentasLotes ve
         WHERE ve.id_lote = l.id_lote)                    AS ingreso_venta,
       l.estado_lote                     AS estado_lote
  FROM Lotes       l
  JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
  JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
  JOIN Productores p  ON p.id_productor = pa.id_productor
  JOIN Variedades  v  ON v.id_variedad  = pa.id_variedad
  JOIN Temporadas  t  ON t.id_temporada = c.id_temporada
 ORDER BY l.codigo_lote;


-- ---------------------------------------------------------------------
-- 3. Produccion por productor
--    ¿Cuanto entrego cada socio y cuanto se le ha pagado?
--    Se usan subconsultas escalares para que los conteos no se inflen
--    al cruzar parcelas con lotes.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_produccion_productor AS
SELECT p.nombre        AS productor,
       p.comunidad     AS comunidad,
       CASE WHEN p.activo THEN 'Activo' ELSE 'Inactivo' END AS estado,
       p.fecha_ingreso_coop AS ingreso_cooperativa,
       (SELECT COUNT(*) FROM Parcelas pa
         WHERE pa.id_productor = p.id_productor)                      AS parcelas,
       (SELECT COALESCE(SUM(pa.area_manzanas), 0) FROM Parcelas pa
         WHERE pa.id_productor = p.id_productor)                      AS area_manzanas,
       (SELECT COUNT(*) FROM Lotes l
          JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_productor = p.id_productor)                      AS lotes,
       (SELECT COALESCE(SUM(c.peso_bruto_quintales), 0) FROM Cosechas c
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_productor = p.id_productor)                      AS cosechado_quintales,
       (SELECT COALESCE(SUM(a.peso_recibido_quintales), 0) FROM Acopios a
          JOIN Lotes    l  ON l.id_lote     = a.id_lote
          JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_productor = p.id_productor)                      AS entregado_quintales,
       (SELECT COALESCE(SUM(ve.peso_vendido_quintales), 0) FROM VentasLotes ve
          JOIN Lotes    l  ON l.id_lote     = ve.id_lote
          JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_productor = p.id_productor)                      AS vendido_quintales,
       (SELECT COALESCE(SUM(ve.total_venta), 0) FROM VentasLotes ve
          JOIN Lotes    l  ON l.id_lote     = ve.id_lote
          JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_productor = p.id_productor)                      AS ingreso_generado,
       (SELECT COALESCE(SUM(pg.monto_neto), 0) FROM Pagos pg
         WHERE pg.id_productor = p.id_productor)                      AS pagado_neto
  FROM Productores p
 ORDER BY cosechado_quintales DESC, p.nombre;


-- ---------------------------------------------------------------------
-- 4. Mermas por lote y etapa
--    ¿Donde se esta perdiendo el cafe y cuanto?
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_mermas_lote AS
SELECT m.fecha_registro          AS fecha_registro,
       l.codigo_lote             AS codigo_lote,
       p.nombre                  AS productor,
       m.tipo_merma              AS tipo_merma,
       m.etapa_origen            AS etapa_origen,
       m.peso_perdido_quintales  AS peso_perdido_quintales,
       COALESCE(m.porcentaje_merma,
                ROUND(m.peso_perdido_quintales /
                      NULLIF(l.peso_inicial_quintales, 0) * 100, 2))  AS porcentaje_merma,
       CASE
           WHEN COALESCE(m.porcentaje_merma,
                         m.peso_perdido_quintales /
                         NULLIF(l.peso_inicial_quintales, 0) * 100) > 15 THEN 'Alta'
           WHEN COALESCE(m.porcentaje_merma,
                         m.peso_perdido_quintales /
                         NULLIF(l.peso_inicial_quintales, 0) * 100) > 5  THEN 'Media'
           ELSE 'Normal'
       END                       AS clasificacion,
       m.responsable             AS responsable,
       m.justificacion           AS justificacion
  FROM Mermas      m
  JOIN Lotes       l  ON l.id_lote      = m.id_lote
  JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
  JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
  JOIN Productores p  ON p.id_productor = pa.id_productor
 ORDER BY porcentaje_merma DESC, m.fecha_registro DESC;


-- ---------------------------------------------------------------------
-- 5. Calidad de los lotes catados
--    Puntajes SCA, altura de taza y el resultado de cada catacion.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_calidad_lotes AS
SELECT ca.fecha_evaluacion       AS fecha_evaluacion,
       l.codigo_lote             AS codigo_lote,
       p.nombre                  AS productor,
       v.nombre                  AS variedad,
       pa.altitud_metros         AS altitud_metros,
       ca.evaluador              AS catador,
       ca.puntaje_sca            AS puntaje_sca,
       ca.altura_taza            AS altura_taza,
       CASE WHEN ca.aprobado_venta THEN 'Aprobado' ELSE 'Rechazado' END AS resultado,
       CASE
           WHEN ca.puntaje_sca >= 85 THEN 'Especial'
           WHEN ca.puntaje_sca >= 80 THEN 'Comercial alto'
           ELSE 'Bajo el minimo'
       END                       AS categoria,
       ca.defectos_principales   AS defectos_principales
  FROM Calidad     ca
  JOIN Lotes       l  ON l.id_lote      = ca.id_lote
  JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
  JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
  JOIN Productores p  ON p.id_productor = pa.id_productor
  JOIN Variedades  v  ON v.id_variedad  = pa.id_variedad
 ORDER BY ca.puntaje_sca DESC;


-- ---------------------------------------------------------------------
-- 6. Detalle de ventas
--    Cada venta con su comprador y como quedo frente al precio base.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ventas_detalle AS
SELECT ve.fecha_venta             AS fecha_venta,
       l.codigo_lote              AS codigo_lote,
       p.nombre                   AS productor,
       co.nombre                  AS comprador,
       co.tipo                    AS tipo_comprador,
       co.pais_destino            AS pais_destino,
       ve.peso_vendido_quintales  AS peso_vendido_quintales,
       ve.precio_quintal          AS precio_quintal,
       t.precio_base_quintal      AS precio_base_quintal,
       ROUND(ve.precio_quintal - t.precio_base_quintal, 2) AS diferencia_vs_base,
       ve.total_venta             AS total_venta,
       ve.forma_pago              AS forma_pago,
       ve.estado_pago             AS estado_pago,
       ve.usuario_registro        AS registrado_por
  FROM VentasLotes ve
  JOIN Lotes       l  ON l.id_lote      = ve.id_lote
  JOIN Compradores co ON co.id_comprador = ve.id_comprador
  JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
  JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
  JOIN Productores p  ON p.id_productor = pa.id_productor
  JOIN Temporadas  t  ON t.id_temporada = c.id_temporada
 ORDER BY ve.fecha_venta DESC;


-- ---------------------------------------------------------------------
-- 7. Resumen de ventas por temporada
--    ¿Como le fue a la cooperativa cada ciclo?
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ventas_temporada AS
SELECT t.anio                                         AS temporada,
       t.estado                                       AS estado_temporada,
       t.precio_base_quintal                          AS precio_base_quintal,
       COUNT(DISTINCT l.id_lote)                      AS lotes_de_la_temporada,
       COUNT(ve.id_venta)                             AS ventas,
       COALESCE(SUM(ve.peso_vendido_quintales), 0)    AS quintales_vendidos,
       COALESCE(SUM(ve.total_venta), 0)               AS ingreso_total,
       ROUND(AVG(ve.precio_quintal), 2)               AS precio_promedio,
       ROUND(AVG(ve.precio_quintal) - t.precio_base_quintal, 2) AS diferencia_vs_base
  FROM Temporadas  t
  LEFT JOIN Cosechas    c  ON c.id_temporada = t.id_temporada
  LEFT JOIN Lotes       l  ON l.id_cosecha   = c.id_cosecha
  LEFT JOIN VentasLotes ve ON ve.id_lote     = l.id_lote
 GROUP BY t.id_temporada, t.anio, t.estado, t.precio_base_quintal
 ORDER BY t.anio DESC;


-- ---------------------------------------------------------------------
-- 8. Pagos a productores
--    Cuanto recibio cada socio por cada venta y que parte del ingreso
--    representa.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_pagos_productor AS
SELECT pg.fecha_pago             AS fecha_pago,
       p.nombre                  AS productor,
       l.codigo_lote             AS codigo_lote,
       ve.total_venta            AS ingreso_de_la_venta,
       pg.precio_pagado_quintal  AS precio_pagado_quintal,
       ve.precio_quintal         AS precio_de_venta,
       pg.monto_pagado           AS monto_pagado,
       pg.deducciones            AS deducciones,
       pg.monto_neto             AS monto_neto,
       ROUND(pg.monto_pagado / NULLIF(ve.total_venta, 0) * 100, 2) AS porcentaje_del_ingreso,
       pg.metodo_pago            AS metodo_pago,
       pg.comprobante            AS comprobante
  FROM Pagos       pg
  JOIN Productores p  ON p.id_productor = pg.id_productor
  JOIN VentasLotes ve ON ve.id_venta    = pg.id_venta
  JOIN Lotes       l  ON l.id_lote      = ve.id_lote
 ORDER BY pg.fecha_pago DESC;


-- ---------------------------------------------------------------------
-- 9. Rendimiento por variedad
--    ¿Que variedad rinde mejor y cual se cotiza mas alto?
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_rendimiento_variedad AS
SELECT v.nombre AS variedad,
       (SELECT COUNT(*) FROM Parcelas pa
         WHERE pa.id_variedad = v.id_variedad)                        AS parcelas,
       (SELECT COALESCE(SUM(pa.area_manzanas), 0) FROM Parcelas pa
         WHERE pa.id_variedad = v.id_variedad)                        AS area_manzanas,
       (SELECT MIN(pa.altitud_metros) FROM Parcelas pa
         WHERE pa.id_variedad = v.id_variedad)                        AS altitud_minima,
       (SELECT MAX(pa.altitud_metros) FROM Parcelas pa
         WHERE pa.id_variedad = v.id_variedad)                        AS altitud_maxima,
       (SELECT COUNT(*) FROM Lotes l
          JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_variedad = v.id_variedad)                        AS lotes,
       (SELECT COALESCE(SUM(c.peso_bruto_quintales), 0) FROM Cosechas c
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_variedad = v.id_variedad)                        AS cosechado_quintales,
       (SELECT ROUND(AVG(ca.puntaje_sca), 2) FROM Calidad ca
          JOIN Lotes    l  ON l.id_lote     = ca.id_lote
          JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_variedad = v.id_variedad)                        AS sca_promedio,
       (SELECT ROUND(AVG(ve.precio_quintal), 2) FROM VentasLotes ve
          JOIN Lotes    l  ON l.id_lote     = ve.id_lote
          JOIN Cosechas c  ON c.id_cosecha  = l.id_cosecha
          JOIN Parcelas pa ON pa.id_parcela = c.id_parcela
         WHERE pa.id_variedad = v.id_variedad)                        AS precio_promedio
  FROM Variedades v
 ORDER BY sca_promedio DESC, v.nombre;


-- ---------------------------------------------------------------------
-- 10. Tiempos del beneficiado
--     ¿Cada etapa se cumplio dentro del rango esperado?
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_tiempos_beneficiado AS
SELECT l.codigo_lote              AS codigo_lote,
       e.orden                    AS orden,
       e.nombre                   AS etapa,
       pr.fecha_inicio            AS fecha_inicio,
       pr.fecha_fin               AS fecha_fin,
       ROUND(TIMESTAMPDIFF(MINUTE, pr.fecha_inicio, pr.fecha_fin) / 60, 1) AS horas_reales,
       e.duracion_min_horas       AS minimo_esperado,
       e.duracion_max_horas       AS maximo_esperado,
       CASE
           WHEN pr.fecha_fin IS NULL THEN 'En curso'
           WHEN TIMESTAMPDIFF(MINUTE, pr.fecha_inicio, pr.fecha_fin) / 60
                < e.duracion_min_horas THEN 'Bajo el rango'
           WHEN TIMESTAMPDIFF(MINUTE, pr.fecha_inicio, pr.fecha_fin) / 60
                > e.duracion_max_horas THEN 'Sobre el rango'
           ELSE 'Dentro del rango'
       END                        AS cumplimiento,
       pr.peso_entrada_quintales  AS peso_entrada_quintales,
       pr.peso_salida_quintales   AS peso_salida_quintales,
       ROUND(pr.peso_entrada_quintales - pr.peso_salida_quintales, 2) AS merma_etapa_quintales,
       pr.responsable             AS responsable
  FROM Procesos      pr
  JOIN Lotes         l ON l.id_lote  = pr.id_lote
  JOIN EtapasProceso e ON e.id_etapa = pr.id_etapa
 ORDER BY l.codigo_lote, e.orden;


-- ---------------------------------------------------------------------
-- 11. Alertas de auditoria
--     Las alertas que levantan los triggers, con el JSON desplegado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_alertas_auditoria AS
SELECT b.fecha_hora       AS fecha_hora,
       b.operacion        AS alerta,
       b.tabla_afectada   AS tabla_afectada,
       b.usuario          AS usuario,
       JSON_UNQUOTE(JSON_EXTRACT(b.datos_nuevos, '$.codigo_lote'))        AS codigo_lote,
       CASE b.operacion
           WHEN 'ALERTA_MERMA_ALTA'
                THEN JSON_UNQUOTE(JSON_EXTRACT(b.datos_nuevos, '$.porcentaje_merma'))
           WHEN 'ALERTA_PRECIO_BAJO'
                THEN JSON_UNQUOTE(JSON_EXTRACT(b.datos_nuevos, '$.diferencia'))
       END                AS valor,
       CASE b.operacion
           WHEN 'ALERTA_MERMA_ALTA'  THEN 'Porcentaje de merma'
           WHEN 'ALERTA_PRECIO_BAJO' THEN 'Quetzales bajo el precio base'
       END                AS que_significa,
       b.datos_nuevos     AS detalle
  FROM BitacoraAuditoria b
 WHERE b.operacion IN ('ALERTA_MERMA_ALTA', 'ALERTA_PRECIO_BAJO')
 ORDER BY b.fecha_hora DESC;


-- =====================================================================
-- Verificacion
-- =====================================================================
SELECT TABLE_NAME AS vista
  FROM information_schema.VIEWS
 WHERE TABLE_SCHEMA = 'trazabilidad_cafe'
 ORDER BY TABLE_NAME;

-- La base sigue teniendo 18 tablas; las vistas se cuentan aparte.
SELECT TABLE_TYPE AS tipo, COUNT(*) AS cuantas
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA = 'trazabilidad_cafe'
 GROUP BY TABLE_TYPE;

-- =====================================================================
-- 08_usuarios.sql: Administracion de usuarios
-- =====================================================================
-- =====================================================================
-- CafeTrack - Gestion de usuarios (administrador)
-- Ejecutar DESPUES de 06_seguridad.sql.
--
-- Cuatro procedimientos para que el administrador trabaje desde la
-- aplicacion sin tocar SQL: crear usuarios, cambiar su rol, activarlos o
-- desactivarlos y asignarles una contrasena temporal.
--
-- El esquema no cambia. La marca de "contrasena temporal" viaja dentro de
-- password_hash con el prefijo 'TMP:' (ver 06_seguridad.sql), de modo que
-- no hace falta ninguna columna nueva.
--
-- Todo queda registrado en BitacoraAuditoria.
-- =====================================================================

USE trazabilidad_cafe;

DROP PROCEDURE IF EXISTS sp_crear_usuario;
DROP PROCEDURE IF EXISTS sp_reiniciar_password;
DROP PROCEDURE IF EXISTS sp_cambiar_rol;
DROP PROCEDURE IF EXISTS sp_cambiar_estado_usuario;

DELIMITER $$

-- ---------------------------------------------------------------------
-- Crea un usuario con una contrasena temporal: al entrar por primera vez
-- el sistema le exige cambiarla.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_crear_usuario(
    IN p_username    VARCHAR(50),
    IN p_nombre      VARCHAR(100),
    IN p_rol         VARCHAR(20),
    IN p_temporal    VARCHAR(255),
    IN p_admin       VARCHAR(50)
)
BEGIN
    DECLARE v_salt VARCHAR(64);
    DECLARE v_id   INT;

    IF p_username IS NULL OR TRIM(p_username) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no puede ir vacio.';
    END IF;

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Escriba el nombre completo.';
    END IF;

    IF p_rol NOT IN ('admin', 'gerente', 'acopiador', 'catador', 'auditor') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol indicado no existe.';
    END IF;

    IF p_temporal IS NULL OR CHAR_LENGTH(p_temporal) < 8 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La contrasena temporal debe tener al menos 8 caracteres.';
    END IF;

    IF EXISTS (SELECT 1 FROM Usuarios u WHERE u.username = p_username) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese nombre de usuario ya existe.';
    END IF;

    SET v_salt = HEX(RANDOM_BYTES(16));

    INSERT INTO Usuarios (username, password_hash, nombre_completo, rol, activo)
    VALUES (TRIM(p_username),
            CONCAT('TMP:', v_salt, ':', SHA2(CONCAT(v_salt, p_temporal), 256)),
            TRIM(p_nombre), p_rol, TRUE);

    SET v_id = LAST_INSERT_ID();

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Usuarios', 'INSERT', v_id, COALESCE(p_admin, USER()),
            JSON_OBJECT('evento', 'usuario creado',
                        'username', TRIM(p_username),
                        'rol', p_rol,
                        'password', 'temporal'));
END$$

-- ---------------------------------------------------------------------
-- Asigna una contrasena temporal nueva. La anterior deja de servir y el
-- usuario debera registrar la suya al entrar.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_reiniciar_password(
    IN p_username VARCHAR(50),
    IN p_temporal VARCHAR(255),
    IN p_admin    VARCHAR(50)
)
BEGIN
    DECLARE v_id   INT DEFAULT NULL;
    DECLARE v_salt VARCHAR(64);

    IF p_temporal IS NULL OR CHAR_LENGTH(p_temporal) < 8 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La contrasena temporal debe tener al menos 8 caracteres.';
    END IF;

    SELECT u.id_usuario INTO v_id FROM Usuarios u WHERE u.username = p_username;

    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    SET v_salt = HEX(RANDOM_BYTES(16));

    UPDATE Usuarios
       SET password_hash = CONCAT('TMP:', v_salt, ':',
                                  SHA2(CONCAT(v_salt, p_temporal), 256))
     WHERE id_usuario = v_id;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Usuarios', 'UPDATE', v_id, COALESCE(p_admin, USER()),
            JSON_OBJECT('evento', 'contrasena temporal asignada',
                        'username', p_username));
END$$

-- ---------------------------------------------------------------------
-- Cambia el rol. El rol decide tanto lo que ve en la aplicacion como el
-- usuario de MySQL con el que trabaja, asi que toma efecto en su proximo
-- inicio de sesion.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_cambiar_rol(
    IN p_username VARCHAR(50),
    IN p_rol      VARCHAR(20),
    IN p_admin    VARCHAR(50)
)
BEGIN
    DECLARE v_id       INT DEFAULT NULL;
    DECLARE v_anterior VARCHAR(20);

    IF p_rol NOT IN ('admin', 'gerente', 'acopiador', 'catador', 'auditor') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol indicado no existe.';
    END IF;

    SELECT u.id_usuario, u.rol INTO v_id, v_anterior
      FROM Usuarios u WHERE u.username = p_username;

    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    IF v_anterior = p_rol THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario ya tiene ese rol.';
    END IF;

    -- La cooperativa no puede quedarse sin administrador.
    IF v_anterior = 'admin'
       AND (SELECT COUNT(*) FROM Usuarios u WHERE u.rol = 'admin' AND u.activo) <= 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Debe quedar al menos un administrador activo.';
    END IF;

    UPDATE Usuarios SET rol = p_rol WHERE id_usuario = v_id;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_anteriores, datos_nuevos)
    VALUES ('Usuarios', 'UPDATE', v_id, COALESCE(p_admin, USER()),
            JSON_OBJECT('rol', v_anterior),
            JSON_OBJECT('evento', 'cambio de rol', 'username', p_username, 'rol', p_rol));
END$$

-- ---------------------------------------------------------------------
-- Activa o desactiva un usuario. Un usuario inactivo no puede entrar.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_cambiar_estado_usuario(
    IN p_username VARCHAR(50),
    IN p_activo   BOOLEAN,
    IN p_admin    VARCHAR(50)
)
BEGIN
    DECLARE v_id  INT DEFAULT NULL;
    DECLARE v_rol VARCHAR(20);

    SELECT u.id_usuario, u.rol INTO v_id, v_rol
      FROM Usuarios u WHERE u.username = p_username;

    IF v_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    IF NOT p_activo AND v_rol = 'admin'
       AND (SELECT COUNT(*) FROM Usuarios u WHERE u.rol = 'admin' AND u.activo) <= 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Debe quedar al menos un administrador activo.';
    END IF;

    UPDATE Usuarios SET activo = p_activo WHERE id_usuario = v_id;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Usuarios', 'UPDATE', v_id, COALESCE(p_admin, USER()),
            JSON_OBJECT('evento', IF(p_activo, 'usuario activado', 'usuario desactivado'),
                        'username', p_username));
END$$

DELIMITER ;

-- Solo el administrador gestiona usuarios.
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_crear_usuario           TO 'cafetrack_admin'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_reiniciar_password      TO 'cafetrack_admin'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_cambiar_rol             TO 'cafetrack_admin'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_cambiar_estado_usuario  TO 'cafetrack_admin'@'localhost';

-- Cualquier usuario puede cambiar su propia contrasena.
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_cambiar_password TO 'cafetrack_admin'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_cambiar_password TO 'cafetrack_gerente'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_cambiar_password TO 'cafetrack_acopiador'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_cambiar_password TO 'cafetrack_catador'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_cambiar_password TO 'cafetrack_auditor'@'localhost';

FLUSH PRIVILEGES;

-- =====================================================================
-- Verificacion
-- =====================================================================
SELECT ROUTINE_NAME AS procedimiento
  FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'trazabilidad_cafe' AND ROUTINE_TYPE = 'PROCEDURE'
 ORDER BY ROUTINE_NAME;

SELECT username, rol, activo,
       IF(LEFT(password_hash, 4) = 'TMP:', 'temporal', 'propia') AS tipo_contrasena
  FROM Usuarios ORDER BY rol, username;

-- =====================================================================
-- 10_operacion.sql: Beneficiado, catacion, bodega y pago
-- =====================================================================
-- =====================================================================
-- CafeTrack - Operacion completa por rol
-- Ejecutar DESPUES de 08_usuarios.sql.
--
-- Cierra la cadena del sistema: hasta aqui solo se podian registrar el
-- acopio y la venta. Con estos cuatro procedimientos cada rol opera la
-- parte que le toca y el lote avanza solo cuando corresponde:
--
--   Cosecha -> Acopio ....... acopiador  (sp_registrar_acopio)
--           -> Beneficiado .. acopiador  (sp_registrar_proceso)
--           -> Catacion ..... catador    (sp_registrar_calidad)
--           -> Bodega ....... acopiador  (sp_registrar_ingreso_bodega)
--           -> Venta ........ gerente    (sp_registrar_venta)
--           -> Pago ......... gerente    (sp_registrar_pago)
--
-- El esquema no cambia: la base conserva sus 18 tablas.
-- Las reglas van con SIGNAL, de modo que la pantalla solo las muestra.
-- =====================================================================

USE trazabilidad_cafe;

DROP PROCEDURE IF EXISTS sp_registrar_proceso;
DROP PROCEDURE IF EXISTS sp_registrar_calidad;
DROP PROCEDURE IF EXISTS sp_registrar_ingreso_bodega;
DROP PROCEDURE IF EXISTS sp_registrar_pago;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. Etapa del beneficiado  (rol: acopiador)
--    Solo se puede registrar la etapa que sigue, y solo si la anterior
--    ya se cerro. La diferencia de peso queda como merma de proceso.
--
--    Si la etapa ya esta abierta (se registro el inicio pero no el fin),
--    la misma llamada la cierra en lugar de crear otra.
--
--    Las fechas tienen que ir hacia adelante: una etapa no puede empezar
--    antes de que termine la anterior, ni antes de que el lote llegara al
--    centro de acopio, ni en el futuro.
--
--    El tope de "no futuro" se puede levantar con el parametro
--    p_permitir_futuras, para demostraciones donde hay que simular en
--    minutos un secado que dura dias. La aplicacion lo enciende solo si el
--    ajuste CafeTrack:PermitirFechasFuturas esta activo. El orden entre
--    etapas se sigue exigiendo siempre: eso no se puede apagar.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_proceso(
    IN  p_id_lote      INT,
    IN  p_id_etapa     INT,
    IN  p_fecha_inicio DATETIME,
    IN  p_fecha_fin    DATETIME,
    IN  p_peso_entrada DECIMAL(10,2),
    IN  p_peso_salida  DECIMAL(10,2),
    IN  p_responsable  VARCHAR(100),
    IN  p_usuario      VARCHAR(50),
    IN  p_permitir_futuras BOOLEAN,
    OUT p_id_proceso   INT
)
sp: BEGIN
    DECLARE v_codigo      VARCHAR(20);
    DECLARE v_estado      VARCHAR(20);
    DECLARE v_peso_actual DECIMAL(10,2);
    DECLARE v_orden       INT DEFAULT NULL;
    DECLARE v_etapa       VARCHAR(50);
    DECLARE v_ultima      INT;
    DECLARE v_merma        DECIMAL(10,2);
    DECLARE v_abierto      INT DEFAULT NULL;
    DECLARE v_fin_anterior DATETIME DEFAULT NULL;
    -- MESSAGE_TEXT de SIGNAL admite 128 caracteres como maximo.
    DECLARE v_aviso        VARCHAR(128);
    DECLARE v_inicio_real  DATETIME DEFAULT NULL;
    DECLARE v_recepcion    DATETIME DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT l.codigo_lote, l.estado_lote, l.peso_actual_quintales
      INTO v_codigo, v_estado, v_peso_actual
      FROM Lotes l WHERE l.id_lote = p_id_lote;

    IF v_codigo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El lote indicado no existe.';
    END IF;

    IF v_estado IN ('Rechazado', 'Vendido') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote ya salio del proceso: no admite mas etapas.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Acopios a WHERE a.id_lote = p_id_lote) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote todavia no ha sido recibido en el centro de acopio.';
    END IF;

    SELECT e.orden, e.nombre INTO v_orden, v_etapa
      FROM EtapasProceso e WHERE e.id_etapa = p_id_etapa;

    IF v_orden IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La etapa indicada no existe.';
    END IF;

    -- Si la etapa quedo abierta, esta llamada la cierra.
    SELECT pr.id_proceso INTO v_abierto
      FROM Procesos pr
     WHERE pr.id_lote = p_id_lote AND pr.id_etapa = p_id_etapa AND pr.fecha_fin IS NULL
     ORDER BY pr.id_proceso LIMIT 1;

    IF v_abierto IS NULL AND EXISTS (SELECT 1 FROM Procesos pr
                WHERE pr.id_lote = p_id_lote AND pr.id_etapa = p_id_etapa) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Esa etapa ya fue registrada y cerrada para este lote.';
    END IF;

    IF v_abierto IS NOT NULL AND p_fecha_fin IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La etapa ya esta abierta: indique la fecha de cierre.';
    END IF;

    -- No se puede saltar etapas: la anterior debe existir y estar cerrada.
    IF v_abierto IS NULL AND v_orden > 1 AND NOT EXISTS (
            SELECT 1 FROM Procesos pr
              JOIN EtapasProceso e ON e.id_etapa = pr.id_etapa
             WHERE pr.id_lote = p_id_lote
               AND e.orden = v_orden - 1
               AND pr.fecha_fin IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Debe cerrar la etapa anterior antes de registrar esta.';
    END IF;

    -- ---- Cronologia: las fechas solo avanzan ----

    IF p_fecha_inicio IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Indique cuando empezo la etapa.';
    END IF;

    -- El tope de "no futuro" se levanta solo en modo demostracion.
    IF NOT COALESCE(p_permitir_futuras, FALSE) THEN

        IF p_fecha_inicio > NOW() THEN
            SET v_aviso = CONCAT('La etapa no puede empezar en el futuro. Ahora: ',
                                 DATE_FORMAT(NOW(), '%d/%m/%Y %H:%i'), '.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_aviso;
        END IF;

        IF p_fecha_fin IS NOT NULL AND p_fecha_fin > NOW() THEN
            SET v_aviso = CONCAT('La etapa no puede cerrar en el futuro. Ahora: ',
                                 DATE_FORMAT(NOW(), '%d/%m/%Y %H:%i'),
                                 '. Si no ha terminado, deje el cierre vacio.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_aviso;
        END IF;

    END IF;

    IF v_abierto IS NOT NULL THEN
        -- Al cerrar se compara contra el inicio que ya quedo guardado.
        SELECT pr.fecha_inicio INTO v_inicio_real
          FROM Procesos pr WHERE pr.id_proceso = v_abierto;

        IF p_fecha_fin < v_inicio_real THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La etapa no puede cerrar antes de la hora en que empezo.';
        END IF;
    ELSE
        -- La primera etapa no puede empezar antes de que el lote llegara.
        IF v_orden = 1 THEN
            SELECT MIN(a.fecha_recepcion) INTO v_recepcion
              FROM Acopios a WHERE a.id_lote = p_id_lote;

            IF v_recepcion IS NOT NULL AND p_fecha_inicio < v_recepcion THEN
                SET v_aviso = CONCAT('No puede empezar antes de que el lote llegara al acopio, el ',
                                     DATE_FORMAT(v_recepcion, '%d/%m/%Y %H:%i'), '.');
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_aviso;
            END IF;
        ELSE
            -- Las demas no pueden empezar antes de que cerrara la anterior.
            SELECT pr.fecha_fin INTO v_fin_anterior
              FROM Procesos pr
              JOIN EtapasProceso e ON e.id_etapa = pr.id_etapa
             WHERE pr.id_lote = p_id_lote AND e.orden = v_orden - 1
             ORDER BY pr.id_proceso DESC LIMIT 1;

            IF v_fin_anterior IS NOT NULL AND p_fecha_inicio < v_fin_anterior THEN
                SET v_aviso = CONCAT('No puede empezar antes de que cierre la etapa anterior, el ',
                                     DATE_FORMAT(v_fin_anterior, '%d/%m/%Y %H:%i'), '.');
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_aviso;
            END IF;
        END IF;
    END IF;

    IF p_peso_entrada IS NULL OR p_peso_entrada <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El peso de entrada debe ser mayor que cero.';
    END IF;

    IF p_peso_entrada > v_peso_actual THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El peso de entrada no puede superar el peso actual del lote.';
    END IF;

    IF p_peso_salida IS NOT NULL AND p_peso_salida > p_peso_entrada THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'De una etapa no puede salir mas cafe del que entro.';
    END IF;

    IF p_fecha_fin IS NOT NULL AND p_fecha_fin < p_fecha_inicio THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La fecha de cierre no puede ser anterior a la de inicio.';
    END IF;

    IF p_responsable IS NULL OR TRIM(p_responsable) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Indique quien responde por la etapa.';
    END IF;

    START TRANSACTION;

    IF v_abierto IS NOT NULL THEN
        UPDATE Procesos
           SET fecha_fin = p_fecha_fin,
               peso_salida_quintales = p_peso_salida,
               responsable = TRIM(p_responsable)
         WHERE id_proceso = v_abierto;

        SET p_id_proceso = v_abierto;
    ELSE
        INSERT INTO Procesos (id_lote, id_etapa, fecha_inicio, fecha_fin,
                              peso_entrada_quintales, peso_salida_quintales, responsable)
        VALUES (p_id_lote, p_id_etapa, p_fecha_inicio, p_fecha_fin,
                p_peso_entrada, p_peso_salida, TRIM(p_responsable));

        SET p_id_proceso = LAST_INSERT_ID();
    END IF;

    -- Lo que se perdio en la etapa se documenta como merma de proceso.
    IF p_peso_salida IS NOT NULL THEN
        SET v_merma = p_peso_entrada - p_peso_salida;

        IF v_merma > 0 THEN
            INSERT INTO Mermas (id_lote, tipo_merma, etapa_origen, peso_perdido_quintales,
                                porcentaje_merma, responsable, justificacion)
            VALUES (p_id_lote, 'Proceso', 'Proceso', v_merma,
                    ROUND(v_merma / NULLIF(p_peso_entrada, 0) * 100, 2), TRIM(p_responsable),
                    CONCAT('Perdida de peso en la etapa ', v_etapa, ' del lote ', v_codigo, '.'));
        END IF;

        -- El peso del lote pasa a ser el que salio de la etapa. Se asigna
        -- despues de la merma para no descontar dos veces.
        UPDATE Lotes
           SET peso_actual_quintales = p_peso_salida,
               estado_lote = 'En proceso'
         WHERE id_lote = p_id_lote;
    ELSE
        UPDATE Lotes SET estado_lote = 'En proceso' WHERE id_lote = p_id_lote;
    END IF;

    SELECT MAX(e.orden) INTO v_ultima FROM EtapasProceso e;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Procesos', 'INSERT', p_id_proceso, COALESCE(p_usuario, USER()),
            JSON_OBJECT('codigo_lote', v_codigo,
                        'etapa', v_etapa,
                        'orden', v_orden,
                        'peso_entrada_quintales', p_peso_entrada,
                        'peso_salida_quintales', p_peso_salida,
                        'cerrada', IF(p_fecha_fin IS NULL, 'no', 'si'),
                        'ultima_etapa', IF(v_orden = v_ultima, 'si', 'no')));

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- 2. Catacion  (rol: catador)
--    Solo se cata lo que termino el beneficiado. Si no aprueba, el lote
--    queda rechazado y ya no puede entrar a bodega ni venderse.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_calidad(
    IN  p_id_lote    INT,
    IN  p_evaluador  VARCHAR(100),
    IN  p_puntaje    DECIMAL(4,2),
    IN  p_altura     VARCHAR(30),
    IN  p_defectos   VARCHAR(200),
    IN  p_perfil     TEXT,
    IN  p_aprobado   BOOLEAN,
    IN  p_usuario    VARCHAR(50),
    OUT p_id_calidad INT
)
sp: BEGIN
    DECLARE v_codigo    VARCHAR(20);
    DECLARE v_estado    VARCHAR(20);
    DECLARE v_etapas    INT;
    DECLARE v_cerradas  INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT l.codigo_lote, l.estado_lote INTO v_codigo, v_estado
      FROM Lotes l WHERE l.id_lote = p_id_lote;

    IF v_codigo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El lote indicado no existe.';
    END IF;

    IF EXISTS (SELECT 1 FROM Calidad c WHERE c.id_lote = p_id_lote) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote ya tiene una catacion registrada.';
    END IF;

    SELECT COUNT(*) INTO v_etapas FROM EtapasProceso;

    SELECT COUNT(*) INTO v_cerradas
      FROM Procesos pr
     WHERE pr.id_lote = p_id_lote AND pr.fecha_fin IS NOT NULL;

    IF v_cerradas < v_etapas THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote no ha terminado el beneficiado: faltan etapas por cerrar.';
    END IF;

    IF p_evaluador IS NULL OR TRIM(p_evaluador) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Indique quien cato el lote.';
    END IF;

    IF p_puntaje IS NULL OR p_puntaje < 0 OR p_puntaje > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El puntaje SCA debe estar entre 0 y 100.';
    END IF;

    -- Regla de la cooperativa: por debajo de 80 no se aprueba.
    IF p_aprobado AND p_puntaje < 80 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede aprobar un lote con puntaje menor a 80.';
    END IF;

    START TRANSACTION;

    INSERT INTO Calidad (id_lote, evaluador, puntaje_sca, altura_taza,
                         defectos_principales, perfil_sensorial, aprobado_venta)
    VALUES (p_id_lote, TRIM(p_evaluador), p_puntaje, NULLIF(p_altura, ''),
            NULLIF(p_defectos, ''), NULLIF(p_perfil, ''), p_aprobado);

    SET p_id_calidad = LAST_INSERT_ID();

    IF NOT p_aprobado THEN
        UPDATE Lotes SET estado_lote = 'Rechazado' WHERE id_lote = p_id_lote;
    END IF;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Calidad', 'INSERT', p_id_calidad, COALESCE(p_usuario, USER()),
            JSON_OBJECT('codigo_lote', v_codigo,
                        'puntaje_sca', p_puntaje,
                        'altura_taza', p_altura,
                        'resultado', IF(p_aprobado, 'Aprobado', 'Rechazado')));

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- 3. Ingreso a bodega  (rol: acopiador)
--    El trigger trg_movimientos_validar ya exige catacion aprobada y
--    capacidad disponible; aqui se cuida ademas no ingresar mas cafe del
--    que el lote realmente tiene.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_ingreso_bodega(
    IN  p_id_lote      INT,
    IN  p_id_bodega    INT,
    IN  p_cantidad     DECIMAL(10,2),
    IN  p_responsable  VARCHAR(100),
    IN  p_usuario      VARCHAR(50),
    OUT p_id_movimiento INT
)
sp: BEGIN
    DECLARE v_codigo      VARCHAR(20);
    DECLARE v_peso_actual DECIMAL(10,2);
    DECLARE v_en_bodega   DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT l.codigo_lote, l.peso_actual_quintales INTO v_codigo, v_peso_actual
      FROM Lotes l WHERE l.id_lote = p_id_lote;

    IF v_codigo IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El lote indicado no existe.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Bodegas b
                    WHERE b.id_bodega = p_id_bodega AND b.activa = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La bodega no existe o esta inactiva.';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor que cero.';
    END IF;

    SET v_en_bodega = fn_existencia_lote(p_id_lote);

    IF v_en_bodega + p_cantidad > v_peso_actual THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No puede ingresar mas cafe del que el lote tiene disponible.';
    END IF;

    IF p_responsable IS NULL OR TRIM(p_responsable) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Indique quien recibe en bodega.';
    END IF;

    START TRANSACTION;

    -- Los triggers validan la catacion y la capacidad, actualizan el estado
    -- del lote y escriben en la bitacora.
    INSERT INTO MovimientosBodega (id_bodega, id_lote, tipo_movimiento, cantidad_quintales,
                                   responsable, usuario_registro, observaciones)
    VALUES (p_id_bodega, p_id_lote, 'Entrada', p_cantidad, TRIM(p_responsable),
            COALESCE(p_usuario, 'sistema'),
            CONCAT('Ingreso del lote ', v_codigo, ' aprobado en catacion.'));

    SET p_id_movimiento = LAST_INSERT_ID();

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- 4. Pago al productor  (rol: gerente)
--    Se paga una sola vez por venta. El monto sale del peso vendido por
--    el precio acordado con el productor.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_pago(
    IN  p_id_venta     INT,
    IN  p_precio       DECIMAL(10,2),
    IN  p_deducciones  DECIMAL(10,2),
    IN  p_metodo       VARCHAR(20),
    IN  p_comprobante  VARCHAR(50),
    IN  p_usuario      VARCHAR(50),
    OUT p_id_pago      INT
)
sp: BEGIN
    DECLARE v_id_productor INT DEFAULT NULL;
    DECLARE v_codigo       VARCHAR(20);
    DECLARE v_peso         DECIMAL(10,2);
    DECLARE v_monto        DECIMAL(12,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT p.id_productor, l.codigo_lote, ve.peso_vendido_quintales
      INTO v_id_productor, v_codigo, v_peso
      FROM VentasLotes ve
      JOIN Lotes       l  ON l.id_lote      = ve.id_lote
      JOIN Cosechas    c  ON c.id_cosecha   = l.id_cosecha
      JOIN Parcelas    pa ON pa.id_parcela  = c.id_parcela
      JOIN Productores p  ON p.id_productor = pa.id_productor
     WHERE ve.id_venta = p_id_venta;

    IF v_id_productor IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La venta indicada no existe.';
    END IF;

    IF EXISTS (SELECT 1 FROM Pagos pg WHERE pg.id_venta = p_id_venta) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Esa venta ya tiene su pago registrado.';
    END IF;

    IF p_precio IS NULL OR p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio pagado por quintal debe ser mayor que cero.';
    END IF;

    SET v_monto = ROUND(v_peso * p_precio, 2);
    SET p_deducciones = COALESCE(p_deducciones, 0);

    IF p_deducciones < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Las deducciones no pueden ser negativas.';
    END IF;

    IF p_deducciones > v_monto THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Las deducciones no pueden superar el monto del pago.';
    END IF;

    START TRANSACTION;

    INSERT INTO Pagos (id_productor, id_venta, monto_pagado, precio_pagado_quintal,
                       deducciones, metodo_pago, comprobante, usuario_registro)
    VALUES (v_id_productor, p_id_venta, v_monto, p_precio, p_deducciones,
            COALESCE(NULLIF(p_metodo, ''), 'Transferencia'), NULLIF(p_comprobante, ''),
            COALESCE(p_usuario, 'sistema'));

    SET p_id_pago = LAST_INSERT_ID();

    UPDATE VentasLotes SET estado_pago = 'Pagado' WHERE id_venta = p_id_venta;

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Pagos', 'INSERT', p_id_pago, COALESCE(p_usuario, USER()),
            JSON_OBJECT('codigo_lote', v_codigo,
                        'id_venta', p_id_venta,
                        'monto_pagado', v_monto,
                        'deducciones', p_deducciones,
                        'monto_neto', v_monto - p_deducciones));

    COMMIT;
END$$

DELIMITER ;


-- ---------------------------------------------------------------------
-- Permisos: cada rol ejecuta solo lo suyo
-- ---------------------------------------------------------------------

-- El acopiador tambien mueve el beneficiado.
GRANT INSERT, UPDATE ON trazabilidad_cafe.Procesos TO 'cafetrack_acopiador'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_registrar_proceso
   TO 'cafetrack_acopiador'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_registrar_ingreso_bodega
   TO 'cafetrack_acopiador'@'localhost';

-- El catador registra la catacion.
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_registrar_calidad
   TO 'cafetrack_catador'@'localhost';

-- El gerente paga.
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_registrar_pago
   TO 'cafetrack_gerente'@'localhost';

FLUSH PRIVILEGES;


-- =====================================================================
-- Verificacion
-- =====================================================================
SELECT ROUTINE_NAME AS procedimiento
  FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'trazabilidad_cafe' AND ROUTINE_TYPE = 'PROCEDURE'
 ORDER BY ROUTINE_NAME;

-- Que puede ejecutar cada rol. Los permisos sobre rutinas no estan en
-- information_schema: viven en mysql.procs_priv.
SELECT CONCAT(User, '@', Host) AS usuario,
       Routine_name            AS rutina,
       Proc_priv               AS permiso
  FROM mysql.procs_priv
 WHERE Db = 'trazabilidad_cafe'
 ORDER BY User, Routine_name;

-- =====================================================================
-- 11_ventas_pagos.sql: Existencia por bodega, venta y compradores
-- =====================================================================
-- =====================================================================
-- CafeTrack · Script 11: existencia por bodega, venta y compradores
--
-- Corrige un hueco de la version anterior: la salida por venta se
-- validaba contra la existencia del LOTE en toda la cooperativa, no
-- contra la de la bodega de la que decia salir. Asi se podia despachar
-- de la bodega B un lote guardado en la bodega A: la B quedaba en
-- negativo y la A con cafe que ya no estaba.
--
-- Se vuelven a crear la funcion de existencia, el trigger de
-- movimientos y sp_registrar_venta, y se agrega sp_crear_comprador.
--
-- No se crea ni se altera ninguna tabla: siguen siendo 18.
-- =====================================================================

USE trazabilidad_cafe;

DROP FUNCTION  IF EXISTS fn_existencia_lote_bodega;
DROP PROCEDURE IF EXISTS sp_crear_comprador;
DROP PROCEDURE IF EXISTS sp_registrar_venta;
DROP TRIGGER   IF EXISTS trg_movimientos_validar;

DELIMITER $$

-- ---------------------------------------------------------------------
-- FUNCION: existencia de un lote dentro de una bodega
-- Misma regla que fn_existencia_lote, pero mirando una sola bodega.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_existencia_lote_bodega(p_id_lote INT, p_id_bodega INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
NOT DETERMINISTIC
BEGIN
    DECLARE v_existencia DECIMAL(10,2);

    SELECT COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                             THEN mb.cantidad_quintales
                             ELSE -mb.cantidad_quintales END), 0)
      INTO v_existencia
      FROM MovimientosBodega mb
     WHERE mb.id_lote   = p_id_lote
       AND mb.id_bodega = p_id_bodega;

    RETURN v_existencia;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER: valida cada movimiento de bodega
-- Entradas: catacion aprobada y capacidad de la bodega.
-- Salidas:  que el cafe este EN ESA BODEGA, no solo en la cooperativa.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_movimientos_validar
BEFORE INSERT ON MovimientosBodega
FOR EACH ROW
cuerpo: BEGIN
    DECLARE v_existencia  DECIMAL(10,2);
    DECLARE v_aprobado    INT DEFAULT 0;
    DECLARE v_capacidad   DECIMAL(10,2);
    DECLARE v_en_bodega   DECIMAL(10,2);

    -- Durante la carga de datos de prueba las cifras ya vienen validadas.
    IF COALESCE(@cafetrack_carga, 0) = 1 THEN
        LEAVE cuerpo;
    END IF;

    IF NEW.tipo_movimiento = 'Entrada' THEN

        SELECT COUNT(*) INTO v_aprobado
          FROM Calidad ca
         WHERE ca.id_lote = NEW.id_lote AND ca.aprobado_venta = TRUE;

        IF v_aprobado = 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Solo ingresan a bodega los lotes aprobados en catacion.';
        END IF;

        -- La bodega no puede recibir mas de su capacidad declarada.
        SELECT b.capacidad_quintales INTO v_capacidad
          FROM Bodegas b WHERE b.id_bodega = NEW.id_bodega;

        SELECT COALESCE(SUM(CASE WHEN mb.tipo_movimiento = 'Entrada'
                                 THEN mb.cantidad_quintales
                                 ELSE -mb.cantidad_quintales END), 0)
          INTO v_en_bodega
          FROM MovimientosBodega mb
         WHERE mb.id_bodega = NEW.id_bodega;

        IF v_capacidad IS NOT NULL AND v_en_bodega + NEW.cantidad_quintales > v_capacidad THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'La bodega no tiene capacidad suficiente para ese ingreso.';
        END IF;

    ELSE

        -- El cafe sale de donde esta guardado: se mide esa bodega.
        SET v_existencia = fn_existencia_lote_bodega(NEW.id_lote, NEW.id_bodega);

        IF v_existencia <= 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Ese lote no esta guardado en esa bodega.';
        END IF;

        IF NEW.cantidad_quintales > v_existencia THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Esa bodega no tiene esa cantidad del lote.';
        END IF;

    END IF;
END$$

-- ---------------------------------------------------------------------
-- PROCEDIMIENTO: registrar una venta
-- Igual que antes, pero ahora comprueba tambien la bodega que despacha.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_venta(
    IN  p_id_lote      INT,
    IN  p_id_comprador INT,
    IN  p_id_bodega    INT,
    IN  p_peso         DECIMAL(10,2),
    IN  p_precio       DECIMAL(10,2),
    IN  p_forma_pago   VARCHAR(20),
    IN  p_responsable  VARCHAR(100),
    IN  p_usuario      VARCHAR(50),
    OUT p_id_venta     INT
)
sp: BEGIN
    DECLARE v_codigo     VARCHAR(20);
    DECLARE v_existencia DECIMAL(10,2);
    DECLARE v_en_bodega  DECIMAL(10,2);
    DECLARE v_aprobado   INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_peso IS NULL OR p_peso <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cantidad vendida debe ser mayor que cero.';
    END IF;

    IF p_precio IS NULL OR p_precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El precio por quintal debe ser mayor que cero.';
    END IF;

    SELECT l.codigo_lote INTO v_codigo FROM Lotes l WHERE l.id_lote = p_id_lote;

    IF v_codigo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote indicado no existe.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Compradores c
                    WHERE c.id_comprador = p_id_comprador AND c.activo = TRUE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El comprador no existe o esta inactivo.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Bodegas b
                    WHERE b.id_bodega = p_id_bodega AND b.activa = TRUE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La bodega que despacha no existe o esta inactiva.';
    END IF;

    SELECT COUNT(*) INTO v_aprobado
      FROM Calidad ca
     WHERE ca.id_lote = p_id_lote AND ca.aprobado_venta = TRUE;

    IF v_aprobado = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote no tiene una catacion aprobada: no se puede vender.';
    END IF;

    SET v_existencia = fn_existencia_lote(p_id_lote);

    IF v_existencia <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote no tiene existencia en bodega.';
    END IF;

    -- El cafe sale de una bodega concreta: ahi tiene que estar.
    SET v_en_bodega = fn_existencia_lote_bodega(p_id_lote, p_id_bodega);

    IF v_en_bodega <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ese lote no esta guardado en la bodega indicada.';
    END IF;

    IF p_peso > v_en_bodega THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La bodega indicada no tiene esa cantidad del lote.';
    END IF;

    START TRANSACTION;

    INSERT INTO VentasLotes (id_lote, id_comprador, peso_vendido_quintales, precio_quintal,
                             forma_pago, estado_pago, usuario_registro)
    VALUES (p_id_lote, p_id_comprador, p_peso, p_precio,
            COALESCE(NULLIF(p_forma_pago, ''), 'Contado'), 'Pendiente',
            COALESCE(p_usuario, 'sistema'));

    SET p_id_venta = LAST_INSERT_ID();

    -- La salida de bodega dispara los triggers que validan y actualizan el estado.
    INSERT INTO MovimientosBodega (id_bodega, id_lote, tipo_movimiento, cantidad_quintales,
                                   id_venta, responsable, usuario_registro, observaciones)
    VALUES (p_id_bodega, p_id_lote, 'Salida por venta', p_peso, p_id_venta,
            COALESCE(NULLIF(p_responsable, ''), 'Sin indicar'),
            COALESCE(p_usuario, 'sistema'),
            CONCAT('Despacho de la venta ', p_id_venta, ' del lote ', v_codigo, '.'));

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('VentasLotes', 'INSERT', p_id_venta, COALESCE(p_usuario, USER()),
            JSON_OBJECT('id_lote', p_id_lote,
                        'codigo_lote', v_codigo,
                        'id_bodega', p_id_bodega,
                        'peso_vendido_quintales', p_peso,
                        'precio_quintal', p_precio,
                        'total_venta', p_peso * p_precio));

    COMMIT;
END$$

-- ---------------------------------------------------------------------
-- PROCEDIMIENTO: dar de alta un comprador
-- Lo usa la pantalla de compradores; el gerente y el administrador son
-- los unicos que pueden ejecutarlo.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_crear_comprador(
    IN  p_nombre       VARCHAR(100),
    IN  p_tipo         VARCHAR(20),
    IN  p_pais_destino VARCHAR(50),
    IN  p_contacto     VARCHAR(100),
    IN  p_telefono     VARCHAR(20),
    IN  p_usuario      VARCHAR(50),
    OUT p_id_comprador INT
)
sp: BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El comprador necesita un nombre.';
    END IF;

    IF p_tipo NOT IN ('Exportador', 'Tostador', 'Intermediario', 'Cooperativa') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El tipo de comprador no es uno de los permitidos.';
    END IF;

    IF EXISTS (SELECT 1 FROM Compradores c
                WHERE LOWER(TRIM(c.nombre)) = LOWER(TRIM(p_nombre))) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ya hay un comprador registrado con ese nombre.';
    END IF;

    START TRANSACTION;

    INSERT INTO Compradores (nombre, tipo, pais_destino, contacto, telefono, activo)
    VALUES (TRIM(p_nombre), p_tipo, NULLIF(TRIM(COALESCE(p_pais_destino, '')), ''),
            NULLIF(TRIM(COALESCE(p_contacto, '')), ''),
            NULLIF(TRIM(COALESCE(p_telefono, '')), ''), TRUE);

    SET p_id_comprador = LAST_INSERT_ID();

    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('Compradores', 'INSERT', p_id_comprador, COALESCE(p_usuario, USER()),
            JSON_OBJECT('nombre', TRIM(p_nombre),
                        'tipo', p_tipo,
                        'pais_destino', p_pais_destino,
                        'contacto', p_contacto));

    COMMIT;
END$$

DELIMITER ;

-- =====================================================================
-- Permisos de las rutinas nuevas
-- =====================================================================

-- Todos consultan existencias; cada quien ve lo que su rol le permite.
GRANT EXECUTE ON FUNCTION trazabilidad_cafe.fn_existencia_lote_bodega
   TO 'cafetrack_admin'@'localhost';
GRANT EXECUTE ON FUNCTION trazabilidad_cafe.fn_existencia_lote_bodega
   TO 'cafetrack_gerente'@'localhost';
GRANT EXECUTE ON FUNCTION trazabilidad_cafe.fn_existencia_lote_bodega
   TO 'cafetrack_acopiador'@'localhost';
GRANT EXECUTE ON FUNCTION trazabilidad_cafe.fn_existencia_lote_bodega
   TO 'cafetrack_catador'@'localhost';
GRANT EXECUTE ON FUNCTION trazabilidad_cafe.fn_existencia_lote_bodega
   TO 'cafetrack_auditor'@'localhost';

-- Vender y dar de alta compradores es del gerente.
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_registrar_venta
   TO 'cafetrack_gerente'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_crear_comprador
   TO 'cafetrack_gerente'@'localhost';

FLUSH PRIVILEGES;

-- =====================================================================
-- Verificacion: existencia de cada lote por bodega
-- =====================================================================
SELECT l.codigo_lote                                        AS lote,
       b.nombre                                             AS bodega,
       fn_existencia_lote_bodega(l.id_lote, b.id_bodega)    AS en_esta_bodega,
       fn_existencia_lote(l.id_lote)                        AS total_del_lote
  FROM Lotes l
  JOIN Bodegas b
 WHERE fn_existencia_lote_bodega(l.id_lote, b.id_bodega) <> 0
 ORDER BY l.codigo_lote, b.nombre;

-- =====================================================================
-- 12_traslados.sql: Traslado entre bodegas
-- =====================================================================
-- =====================================================================
-- CafeTrack · Script 12: traslado de cafe entre bodegas
--
-- Mover un lote de una bodega a otra no es un movimiento nuevo: son dos
-- movimientos de los que ya existen, dentro de una sola transaccion.
--   * En la bodega de origen se escribe un 'Ajuste' (resta).
--   * En la de destino, una 'Entrada' (suma).
-- El ENUM tipo_movimiento no se toca; la tabla tampoco. Siguen 18.
--
-- Quien traslada es quien custodia el cafe: el acopiador, y el
-- administrador. El gerente vende, pero no mueve existencias.
-- =====================================================================

USE trazabilidad_cafe;

DROP PROCEDURE IF EXISTS sp_trasladar_lote;

DELIMITER $$

CREATE PROCEDURE sp_trasladar_lote(
    IN  p_id_lote     INT,
    IN  p_origen      INT,
    IN  p_destino     INT,
    IN  p_cantidad    DECIMAL(10,2),
    IN  p_responsable VARCHAR(100),
    IN  p_motivo      VARCHAR(200),
    IN  p_usuario     VARCHAR(50),
    OUT p_id_salida   INT,
    OUT p_id_entrada  INT
)
sp: BEGIN
    DECLARE v_codigo     VARCHAR(20);
    DECLARE v_en_origen  DECIMAL(10,2);
    DECLARE v_nombre_ori VARCHAR(100);
    DECLARE v_nombre_des VARCHAR(100);
    DECLARE v_nota       VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La cantidad a trasladar debe ser mayor que cero.';
    END IF;

    IF p_origen = p_destino THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El origen y el destino no pueden ser la misma bodega.';
    END IF;

    SELECT l.codigo_lote INTO v_codigo FROM Lotes l WHERE l.id_lote = p_id_lote;

    IF v_codigo IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El lote indicado no existe.';
    END IF;

    SELECT b.nombre INTO v_nombre_ori
      FROM Bodegas b WHERE b.id_bodega = p_origen AND b.activa = TRUE;

    IF v_nombre_ori IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La bodega de origen no existe o esta inactiva.';
    END IF;

    SELECT b.nombre INTO v_nombre_des
      FROM Bodegas b WHERE b.id_bodega = p_destino AND b.activa = TRUE;

    IF v_nombre_des IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La bodega de destino no existe o esta inactiva.';
    END IF;

    -- No se puede sacar de donde no hay.
    SET v_en_origen = fn_existencia_lote_bodega(p_id_lote, p_origen);

    IF v_en_origen <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ese lote no esta guardado en la bodega de origen.';
    END IF;

    IF p_cantidad > v_en_origen THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La bodega de origen no tiene esa cantidad del lote.';
    END IF;

    SET v_nota = CONCAT('Traslado de ', v_nombre_ori, ' a ', v_nombre_des, '.',
                        COALESCE(CONCAT(' ', NULLIF(TRIM(p_motivo), '')), ''));

    START TRANSACTION;

    -- Salida de la bodega de origen. 'Ajuste' resta en fn_existencia_lote.
    INSERT INTO MovimientosBodega (id_bodega, id_lote, tipo_movimiento, cantidad_quintales,
                                   responsable, usuario_registro, observaciones)
    VALUES (p_origen, p_id_lote, 'Ajuste', p_cantidad,
            COALESCE(NULLIF(p_responsable, ''), 'Sin indicar'),
            COALESCE(p_usuario, 'sistema'), v_nota);

    SET p_id_salida = LAST_INSERT_ID();

    -- Entrada en la de destino. El trigger revisa aqui la capacidad.
    INSERT INTO MovimientosBodega (id_bodega, id_lote, tipo_movimiento, cantidad_quintales,
                                   responsable, usuario_registro, observaciones)
    VALUES (p_destino, p_id_lote, 'Entrada', p_cantidad,
            COALESCE(NULLIF(p_responsable, ''), 'Sin indicar'),
            COALESCE(p_usuario, 'sistema'), v_nota);

    SET p_id_entrada = LAST_INSERT_ID();

    -- La columna operacion es un ENUM de cinco valores: el traslado entra
    -- como INSERT y se distingue por lo que dice datos_nuevos.
    INSERT INTO BitacoraAuditoria (tabla_afectada, operacion, id_registro_afectado,
                                   usuario, datos_nuevos)
    VALUES ('MovimientosBodega', 'INSERT', p_id_entrada, COALESCE(p_usuario, USER()),
            JSON_OBJECT('movimiento', 'Traslado entre bodegas',
                        'id_salida', p_id_salida,
                        'id_entrada', p_id_entrada,
                        'codigo_lote', v_codigo,
                        'origen', v_nombre_ori,
                        'destino', v_nombre_des,
                        'cantidad_quintales', p_cantidad,
                        'responsable', p_responsable,
                        'motivo', NULLIF(TRIM(COALESCE(p_motivo, '')), '')));

    COMMIT;
END$$

DELIMITER ;

-- =====================================================================
-- Permisos: solo quien custodia el cafe
-- =====================================================================
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_trasladar_lote
   TO 'cafetrack_acopiador'@'localhost';
GRANT EXECUTE ON PROCEDURE trazabilidad_cafe.sp_trasladar_lote
   TO 'cafetrack_admin'@'localhost';

FLUSH PRIVILEGES;

-- =====================================================================
-- Verificacion: quien puede trasladar
-- =====================================================================
SELECT CONCAT(User, '@', Host) AS usuario,
       Routine_name            AS rutina,
       Proc_priv               AS permiso
  FROM mysql.procs_priv
 WHERE Db = 'trazabilidad_cafe'
   AND Routine_name = 'sp_trasladar_lote'
 ORDER BY User;
