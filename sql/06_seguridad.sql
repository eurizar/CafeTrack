-- =====================================================================
-- CafeTrack - FASE 3: seguridad
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
