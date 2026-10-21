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
