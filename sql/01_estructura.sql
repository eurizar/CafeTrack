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