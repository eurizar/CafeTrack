-- =====================================================================
-- CafeTrack - RECUPERAR EL ACCESO
--
-- Para cuando nadie puede entrar al sistema. Casos tipicos:
--   * El administrador perdio su contrasena.
--   * Le asignaron una contrasena temporal y no la anoto.
--   * El unico usuario con rol admin quedo inactivo.
--
-- Se ejecuta en MySQL con una cuenta que tenga privilegios sobre la base
-- (normalmente root). No necesita la aplicacion ni la contrasena anterior:
-- la contrasena no se recupera —solo esta guardado su hash—, se reemplaza.
--
-- Ejecucion:
--     mysql -u root -p < sql/09_recuperar_acceso.sql
-- =====================================================================

USE trazabilidad_cafe;

-- ---------------------------------------------------------------------
-- 1. Ver como esta el sistema antes de tocar nada
-- ---------------------------------------------------------------------
SELECT username,
       nombre_completo,
       rol,
       IF(activo, 'activo', 'INACTIVO') AS estado,
       IF(LEFT(password_hash, 4) = 'TMP:', 'temporal', 'propia') AS contrasena,
       ultimo_acceso
  FROM Usuarios
 ORDER BY rol, username;


-- ---------------------------------------------------------------------
-- 2. Asignar una contrasena temporal nueva
--
-- Cambie el usuario y la clave de las dos lineas de abajo. Al entrar con
-- ella, el sistema va a exigir que registre una propia.
-- ---------------------------------------------------------------------
SET @usuario = 'admin';
SET @temporal = 'Recuperar2026';

CALL sp_reiniciar_password(@usuario, @temporal, 'recuperacion');

SELECT CONCAT('Listo: entre como "', @usuario,
              '" con la clave "', @temporal,
              '" y el sistema le pedira cambiarla.') AS resultado;


-- ---------------------------------------------------------------------
-- 3. Si ademas el usuario quedo inactivo, reactivelo
-- ---------------------------------------------------------------------
-- CALL sp_cambiar_estado_usuario(@usuario, TRUE, 'recuperacion');


-- ---------------------------------------------------------------------
-- 4. Si no quedo ningun administrador, devuelva el rol
-- ---------------------------------------------------------------------
-- CALL sp_cambiar_rol(@usuario, 'admin', 'recuperacion');
--
-- Nota: sp_cambiar_rol impide dejar la cooperativa sin administrador, de
-- modo que para volver a poner a alguien como admin no hay restriccion.


-- ---------------------------------------------------------------------
-- 5. Comprobacion y rastro
-- ---------------------------------------------------------------------
-- La variable de sesion viene con la colacion de la conexion y la columna
-- usa utf8mb4_unicode_ci: se iguala para que MySQL no rechace la comparacion.
SELECT username, rol, IF(activo, 'activo', 'INACTIVO') AS estado,
       IF(LEFT(password_hash, 4) = 'TMP:', 'temporal', 'propia') AS contrasena
  FROM Usuarios
 WHERE username = @usuario COLLATE utf8mb4_unicode_ci;

-- La recuperacion queda registrada en la bitacora como cualquier cambio.
SELECT fecha_hora, operacion, usuario, datos_nuevos
  FROM BitacoraAuditoria
 WHERE tabla_afectada = 'Usuarios'
 ORDER BY id_bitacora DESC
 LIMIT 5;


-- =====================================================================
-- COMO EVITAR LLEGAR AQUI
--
--   * Tenga siempre un segundo usuario con rol admin: si uno pierde su
--     clave, el otro se la reinicia desde /Usuarios en dos clics.
--   * La aplicacion ya no deja que un administrador se reinicie a si
--     mismo: en su propia fila ofrece "Cambiar mi clave", que exige
--     conocer la actual y no genera ninguna temporal.
--   * La contrasena temporal se muestra una sola vez, al generarla.
--     Anotela antes de cerrar el aviso.
-- =====================================================================
