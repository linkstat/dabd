/* TRABAJO PRÁCTICO 4
 *
 *
 * .            Alumno:  HAMANN, PABLO ALEJANDRO
 * .            Legajo:  VINF010782
 * .               Año:  2025
 * . Prof. Disciplinar:  CASTELLI, SILVIA LAURA LANZA
 * .     Prof. Experto:  DAUBROWSKY, RICARDO RAMÓN
 * 
 * Software utilizado para el desarrollo del presente TP:
 * .  Motor de BD:  - Oracle Database 21c Express Edition
 * . Clientes SQL:  - Oracle SQL Developer 24.3.1.347
 * .        Otros:  - Docker 5:20.10.13~3-0~ubuntu-jammy
 * .                - ONLYOFFICE 8.3.3.21 (deb)
 * .                - VSCode
 * .                - git-cli
 *
 *
 * Consideraciones a tener en cuenta:
 *
 * 1. Decidí utilizar UUID almacenado como RAW(16) para los IDs.
 *    Justificación: ya venía haciéndolo así desde el TP1 en MySQL/MariaDB.
 *
 * 2. El presente script está pensado como un "todo en uno", en el sentido de que su ejecución, ELIMINA COMPLETAMENTE EL ESQUEMA (USUARIO), y RECREA TODO DESDE CERO.
 *    Justificación: es mucho más fácil para probar que todo fucnciona bien desde cero (con cada ejecución), sobre todo cuando se trabaja realizando constantes cambios.
 *
 * 3. Este script, contiene las sentencias que DEBEN EJECUTARSE COMO SYSTEM / DBO
 *
 *
 * = Repositorio en GitHub =
 * Este archivo es parte del siguiente repositorio en GitHub (creado para esta materia):
 *
 * Repositorio:   https://github.com/linkstat/dabd
 * Este archivo:  https://raw.githubusercontent.com/linkstat/dabd/refs/heads/main/sql/HAMANN-PABLO-ALEJANDRO-TP4-[SYSTEM].sql
 *
 */



/*
 * Sección 0: Tareas previas a la creación del esquema y configuración del entorno.
 */

-- 0.0 Borrar esquema (usuario) si existiera
BEGIN
  EXECUTE IMMEDIATE 'DROP USER DWPEDIDOS CASCADE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1918 THEN RAISE; END IF;  -- ORA-01918: usuario no existe
END;
/

-- 0.1 Crear el esquema y darle privilegios
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE USER DWPEDIDOS IDENTIFIED BY dabdTP4
      DEFAULT TABLESPACE USERS
      TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON USERS
  ]';
  EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO DWPEDIDOS';
END;
/


/* 0.2 Definición de funciones personalizadas
 * utilizo UUID almacenado en crudo (raw); para esto, desarrollamos dos funciones de conversión.
 */

-- Función para convertir (y almacenar) UUID en RAW(16)
CREATE OR REPLACE FUNCTION uuid_to_raw(p_uuid IN VARCHAR2)
  RETURN RAW DETERMINISTIC AS
BEGIN
  RETURN HEXTORAW(REPLACE(p_uuid,'-',''));
END;
/

-- Función para recuperar y convertir de nuevo a UUID
CREATE OR REPLACE FUNCTION raw_to_uuid(p_raw IN RAW)
  RETURN VARCHAR2 DETERMINISTIC AS
  v_hex VARCHAR2(32) := RAWTOHEX(p_raw);
BEGIN
  RETURN LOWER(
    SUBSTR(v_hex,1,8)||'-'||
    SUBSTR(v_hex,9,4)||'-'||
    SUBSTR(v_hex,13,4)||'-'||
    SUBSTR(v_hex,17,4)||'-'||
    SUBSTR(v_hex,21,12)
  );
END;
/


/* 0.3 Asignación de permisos
 *     Para que el usuario DWPEDIDOS consulte datos de las tablas del esquema PEDIDOS, necesitamos:
 *       A.  Permisos de SELECT en las tablas de PEDIDOS
 *       B.  Permisos de ejecución de funciones.
 *       C.  Permisos de creación de sinónimos para comodidad (así no escribimos PEDIDOS.<tabla> siempre)
 */

-- A. Dar permisos de SELECT:
GRANT SELECT ON PEDIDOS.Clientes TO DWPEDIDOS;
GRANT SELECT ON PEDIDOS.Proveedores TO DWPEDIDOS;
GRANT SELECT ON PEDIDOS.Productos TO DWPEDIDOS;
GRANT SELECT ON PEDIDOS.Pedidos TO DWPEDIDOS;
GRANT SELECT ON PEDIDOS.DetallePedidos TO DWPEDIDOS;

-- B. Dar permisos de EXECUTE:
GRANT EXECUTE ON uuid_to_raw TO DWPEDIDOS;
GRANT EXECUTE ON raw_to_uuid TO DWPEDIDOS;

-- C. Dar permiso para crear sinónimos
GRANT CREATE SYNONYM TO DWPEDIDOS;

