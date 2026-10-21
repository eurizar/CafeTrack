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
