-- =====================================================================
-- CafeTrack - FASE 4: las 11 consultas del proyecto, como VISTAS
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
