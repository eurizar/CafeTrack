-- =====================================================================
-- CafeTrack - FASE 2: funcion, procedimientos y triggers
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
