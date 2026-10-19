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
