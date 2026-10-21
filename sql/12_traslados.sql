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
