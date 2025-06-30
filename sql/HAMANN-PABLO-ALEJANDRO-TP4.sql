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
 * 3. NO OBSTATE, COMO ALGUNAS COSAS SE DEBEN EJECUTAR COMO SYSTEM, Y OTRAS COMO DWPEDIDOS, Y COMO EN Oracle, no hay
 *    un comando tipo "sudo" o "EXECUTE AS" como en otros motores. La regla general es:
 *    -> Los comandos de administración y concesión de permisos los hace el DBA (por ejemplo, SYSTEM).
 *    -> Los objetos del DW y los sinónimos los crea el usuario DW (ejemplo, DWPEDIDOS).
 *    POR ESTO, DE ESTE ARCHIVO SQL, REALIZO DOS COPIAS: CADA UNA, CON LO QUE DEBE EJECUTAR CADA USUARIO. 
 *
 * = Repositorio en GitHub =
 * Este archivo es parte del siguiente repositorio en GitHub (creado para esta materia):
 *
 * Repositorio:   https://github.com/linkstat/dabd
 * Este archivo:  https://raw.githubusercontent.com/linkstat/dabd/refs/heads/main/sql/HAMANN-PABLO-ALEJANDRO-TP4.sql
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

  -- 0.2 Cambiar al esquema DWPEDIDOS
  ALTER SESSION SET CURRENT_SCHEMA = DWPEDIDOS;



/* 0.3 Definición de funciones personalizadas
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


/* 0.4 Para que el usuario DWPEDIDOS consulte datos de las tablas del esquema PEDIDOS, necesitamos:
 * A. Permisos de SELECT en las tablas de PEDIDOS
 * B. [OPCIONAL] sinónimos para comodidad (así no escribimos PEDIDOS.<tabla> siempre)
 */
-- A. Dar permisos de SELECT:
GRANT SELECT ON PEDIDOS.Clientes TO DWPEDIDOS;
GRANT SELECT ON PEDIDOS.Proveedores TO DWPEDIDOS;
GRANT SELECT ON PEDIDOS.Productos TO DWPEDIDOS;
GRANT SELECT ON PEDIDOS.Pedidos TO DWPEDIDOS;
GRANT SELECT ON PEDIDOS.DetallePedidos TO DWPEDIDOS;


-- B. Crear sinónimos en DWPEDIDOS [Opcional, pero deseable]
-- -------------------------------------------
-- EJECUTAR COMO DWPEDIDOS (usuario DW)
-- -------------------------------------------
CREATE SYNONYM Clientes FOR PEDIDOS.Clientes;
CREATE SYNONYM Proveedores FOR PEDIDOS.Proveedores;
CREATE SYNONYM Productos FOR PEDIDOS.Productos;
CREATE SYNONYM Pedidos FOR PEDIDOS.Pedidos;
CREATE SYNONYM DetallePedidos FOR PEDIDOS.DetallePedidos;


/*
 * Sección 1: Sentencias de creación de la base de datos DWPedidos, con las tablas correspondientes.
 */


-- Sentencias de creación de las tablas del DW (modelo estrella, PK RAW(16)/UUID)
-- Dimensión de Fechas
CREATE TABLE dim_fechas (
  id_fec     RAW(16) PRIMARY KEY,
  fecha      DATE,
  dia        NUMBER,
  mes        NUMBER,
  anio       NUMBER
);

-- Dimensión de Productos
CREATE TABLE dim_productos (
  id_pro       RAW(16) PRIMARY KEY,
  idproducto   RAW(16),
  descripcion  VARCHAR2(255),
  nombreproveedor VARCHAR2(100)
);

-- Dimensión de Clientes
CREATE TABLE dim_clientes (
  id_cli      RAW(16) PRIMARY KEY,
  idcliente   RAW(16),
  nombre      VARCHAR2(255)
);

-- Tabla de hechos (FACTORIAL)
CREATE TABLE fact_pedidos (
  id_cli      RAW(16),
  id_pro      RAW(16),
  id_fec      RAW(16),
  cantidad    NUMBER,
  total       NUMBER(10,2),
  FOREIGN KEY (id_cli) REFERENCES dim_clientes(id_cli),
  FOREIGN KEY (id_pro) REFERENCES dim_productos(id_pro),
  FOREIGN KEY (id_fec) REFERENCES dim_fechas(id_fec)
);



/*
 * Sección 2: Detalle de procedimientos almacenados desarrollados para la
 *            carga de datos en la base de datos DWPedidos (Proceso ETL).
 *
 * Conviene encapsular cada carga en un procedimiento almacenado.
 */

-- A. Procedimiento para cargar dim_fechas
CREATE OR REPLACE PROCEDURE cargar_dim_fechas IS
BEGIN
  -- Primero eliminamos datos existentes, para evitar duplicados en recargas
  DELETE FROM dim_fechas;

  -- Cargamos fechas únicas desde Pedidos
  INSERT INTO dim_fechas (id_fec, fecha, dia, mes, anio)
  SELECT
    SYS_GUID(),
    fecha,
    EXTRACT(DAY FROM fecha),
    EXTRACT(MONTH FROM fecha),
    EXTRACT(YEAR FROM fecha)
  FROM (SELECT DISTINCT fecha FROM PEDIDOS.Pedidos);

  COMMIT;
END cargar_dim_fechas;
/

-- B. Procedimiento para cargar dim_clientes
CREATE OR REPLACE PROCEDURE cargar_dim_clientes IS
BEGIN
  DELETE FROM dim_clientes;

  INSERT INTO dim_clientes (id_cli, idcliente, nombre)
  SELECT
    SYS_GUID(),
    idcliente,
    apellido || ', ' || nombres
  FROM PEDIDOS.Clientes;

  COMMIT;
END cargar_dim_clientes;
/

-- C. Procedimiento para cargar dim_productos
CREATE OR REPLACE PROCEDURE cargar_dim_productos IS
BEGIN
  DELETE FROM dim_productos;

  INSERT INTO dim_productos (id_pro, idproducto, descripcion, nombreproveedor)
  SELECT
    SYS_GUID(),
    p.idproducto,
    p.descripcion,
    prov.nombreproveedor
  FROM PEDIDOS.Productos p
  JOIN PEDIDOS.Proveedores prov ON p.idproveedor = prov.idproveedor;

  COMMIT;
END cargar_dim_productos;
/

-- D. Procedimiento para cargar fact_pedidos
CREATE OR REPLACE PROCEDURE cargar_fact_pedidos IS
BEGIN
  DELETE FROM fact_pedidos;

  INSERT INTO fact_pedidos (id_cli, id_pro, id_fec, cantidad, total)
  SELECT
    dc.id_cli,
    dp.id_pro,
    df.id_fec,
    det.cantidad,
    det.cantidad * det.preciounitario
  FROM
    PEDIDOS.DetallePedidos det
    JOIN PEDIDOS.Pedidos ped ON det.numeropedido = ped.numeropedido
    JOIN dim_fechas df ON ped.fecha = df.fecha
    JOIN dim_clientes dc ON ped.idcliente = dc.idcliente
    JOIN dim_productos dp ON det.idproducto = dp.idproducto;

  COMMIT;
END cargar_fact_pedidos;
/


/*
 * Procedimiento ETL Maestro
 * Es un procedimiento que invoca a todos los anteriores, en orden
 */
 -- Procedimiento para cargar todos los procedimientos ordenadamente
CREATE OR REPLACE PROCEDURE ejecutar_etl_dw IS
BEGIN
  cargar_dim_fechas;
  cargar_dim_clientes;
  cargar_dim_productos;
  cargar_fact_pedidos;
END;
/


-- Ejecutar el ETL Maestro
EXEC ejecutar_etl_dw;