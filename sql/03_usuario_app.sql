-- =====================================================================
-- CafeTrack - Usuario de aplicacion para MySQL
-- Ejecutar como root, DESPUES de 01_estructura.sql
--
-- IMPORTANTE: cambie la contrasena antes de ejecutarlo y no la guarde en
-- ningun archivo versionado. La contrasena real vive solo en User Secrets:
--   dotnet user-secrets set "ConnectionStrings:CafeTrack" ^
--     "Server=localhost;Port=3306;Database=trazabilidad_cafe;User=cafetrack_dev;Password=...;"
-- =====================================================================

CREATE USER IF NOT EXISTS 'cafetrack_dev'@'localhost'
  IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';

GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
  ON trazabilidad_cafe.*
  TO 'cafetrack_dev'@'localhost';

FLUSH PRIVILEGES;

-- Verificacion de los permisos otorgados:
SHOW GRANTS FOR 'cafetrack_dev'@'localhost';

-- ---------------------------------------------------------------------
-- Cada rol de la aplicacion tiene su propio usuario de MySQL con permisos
-- distintos. Los crea sql/06_seguridad.sql; este es el resumen:
--
--   cafetrack_admin      -> todo sobre trazabilidad_cafe
--   cafetrack_gerente    -> SELECT en todo; INSERT/UPDATE en VentasLotes y Pagos
--   cafetrack_acopiador  -> SELECT + INSERT en Acopios, Lotes, MovimientosBodega
--   cafetrack_catador    -> SELECT + INSERT/UPDATE en Calidad
--   cafetrack_auditor    -> solo SELECT (incluida BitacoraAuditoria)
-- ---------------------------------------------------------------------
