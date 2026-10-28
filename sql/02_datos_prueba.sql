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
