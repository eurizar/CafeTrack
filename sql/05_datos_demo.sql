-- =====================================================================
-- CafeTrack - Datos OPCIONALES para demostrar los formularios de la Fase 2
--
-- 02_datos_prueba.sql deja los 12 lotes que pide el enunciado, todos con su
-- acopio registrado. Para poder mostrar en vivo el formulario de acopio hace
-- falta un lote recien cosechado que todavia no haya sido recibido: eso es lo
-- unico que agrega este archivo.
--
-- Es opcional. Si no se ejecuta, el sistema funciona igual y la pantalla de
-- acopio muestra su mensaje de "no hay lotes pendientes".
-- Ejecutar DESPUES de 02_datos_prueba.sql.
-- =====================================================================

USE trazabilidad_cafe;

SET @cafetrack_carga = 1;

-- Lote 13: cosechado, en camino al centro de acopio.
INSERT INTO Cosechas (id_cosecha, id_parcela, id_temporada, fecha_recoleccion,
                      peso_bruto_quintales, humedad_porcentaje, recolector, observaciones)
VALUES (13, 2, 2, '2026-03-05', 31.50, 53.40, 'Cuadrilla Ba Caal',
        'Corte tardio de la temporada 2026; pendiente de recepcion en acopio.');

INSERT INTO Lotes (id_lote, id_cosecha, codigo_lote, fecha_creacion, peso_inicial_quintales,
                   peso_actual_quintales, estado_lote, certificacion_aplicable)
VALUES (13, 13, 'CAF-2026-007', '2026-03-05 17:20:00', 31.50, 31.50, 'En acopio', 'Organico');

SET @cafetrack_carga = NULL;

-- Verificacion: el lote debe aparecer sin acopio.
SELECT l.codigo_lote,
       c.peso_bruto_quintales AS cosechado,
       l.estado_lote,
       (SELECT COUNT(*) FROM Acopios a WHERE a.id_lote = l.id_lote) AS acopios
  FROM Lotes l
  JOIN Cosechas c ON c.id_cosecha = l.id_cosecha
 WHERE NOT EXISTS (SELECT 1 FROM Acopios a WHERE a.id_lote = l.id_lote);
