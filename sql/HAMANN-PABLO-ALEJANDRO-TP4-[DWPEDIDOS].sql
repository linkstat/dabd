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
 * 3. Este script, contiene las sentencias que DEBEN EJECUTARSE COMO DWPEDIDOS
 *
 *
 * = Repositorio en GitHub =
 * Este archivo es parte del siguiente repositorio en GitHub (creado para esta materia):
 *
 * Repositorio:   https://github.com/linkstat/dabd
 * Este archivo:  https://raw.githubusercontent.com/linkstat/dabd/refs/heads/main/sql/HAMANN-PABLO-ALEJANDRO-TP4.sql
 *
 */


  -- 0.2 Cambiar al esquema DWPEDIDOS
  ALTER SESSION SET CURRENT_SCHEMA = DWPEDIDOS;

/*
 * TODAS LAS SENTENCIAS QUE SIGUEN DE AQUI EN MÁS,
 * DEBEN EJECUTARSE COMO DWPEDIDOS (QUE YA FUE CREADO)
 * COMO ES EL PROPOSITO D ESTE SCRIPT, SE DESCOMENTAN
 */

-- C. Crear sinónimos en DWPEDIDOS [Opcional, pero deseable]
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
CREATE TABLE DIMFechas (
  id_Fec     RAW(16) PRIMARY KEY,
  fecha      DATE,
  dia        NUMBER,
  mes        NUMBER,
  anio       NUMBER
);

-- Dimensión de Productos
CREATE TABLE DIMProductos (
  id_pro       RAW(16) PRIMARY KEY,
  idproducto   RAW(16),
  descripcion  VARCHAR2(255),
  nombreproveedor VARCHAR2(100)
);

-- Dimensión de Clientes
CREATE TABLE DIMClientes (
  id_cli      RAW(16) PRIMARY KEY,
  idcliente   RAW(16),
  nombre      VARCHAR2(255)
);

-- Tabla de hechos de Pedidos
CREATE TABLE FACTPedidos (
  id_cli      RAW(16),
  id_pro      RAW(16),
  id_fec      RAW(16),
  cantidad    NUMBER,
  total       NUMBER(10,2),
  FOREIGN KEY (id_cli) REFERENCES DIMClientes(id_cli),
  FOREIGN KEY (id_pro) REFERENCES DIMProductos(id_pro),
  FOREIGN KEY (id_fec) REFERENCES DIMFechas(id_fec)
);



/*
 * Sección 2: Detalle de procedimientos almacenados desarrollados para la
 *            carga de datos en la base de datos DWPedidos (Proceso ETL).
 *
 * Conviene encapsular cada carga en un procedimiento almacenado.
 */

-- A. Procedimiento para cargar DIMFechas
CREATE OR REPLACE PROCEDURE cargar_DIMFechas IS
BEGIN
  -- Primero eliminamos datos existentes, para evitar duplicados en recargas
  DELETE FROM DIMFechas;

  -- Cargamos fechas únicas desde Pedidos
  INSERT INTO DIMFechas (id_fec, fecha, dia, mes, anio)
  SELECT
    SYS_GUID(),
    fecha,
    EXTRACT(DAY FROM fecha),
    EXTRACT(MONTH FROM fecha),
    EXTRACT(YEAR FROM fecha)
  FROM (SELECT DISTINCT fecha FROM PEDIDOS.Pedidos);

  COMMIT;
END cargar_DIMFechas;
/

-- B. Procedimiento para cargar DIMClientes
CREATE OR REPLACE PROCEDURE cargar_DIMClientes IS
BEGIN
  DELETE FROM DIMClientes;

  INSERT INTO DIMClientes (id_cli, idcliente, nombre)
  SELECT
    SYS_GUID(),
    idcliente,
    apellido || ', ' || nombres
  FROM PEDIDOS.Clientes;

  COMMIT;
END cargar_DIMClientes;
/

-- C. Procedimiento para cargar DIMProductos
CREATE OR REPLACE PROCEDURE cargar_DIMProductos IS
BEGIN
  DELETE FROM DIMProductos;

  INSERT INTO DIMProductos (id_pro, idproducto, descripcion, nombreproveedor)
  SELECT
    SYS_GUID(),
    p.idproducto,
    p.descripcion,
    prov.nombreproveedor
  FROM PEDIDOS.Productos p
  JOIN PEDIDOS.Proveedores prov ON p.idproveedor = prov.idproveedor;

  COMMIT;
END cargar_DIMProductos;
/

-- D. Procedimiento para cargar FACTPedidos
CREATE OR REPLACE PROCEDURE cargar_FACTPedidos IS
BEGIN
  DELETE FROM FACTPedidos;

  INSERT INTO FACTPedidos (id_cli, id_pro, id_fec, cantidad, total)
  SELECT
    dc.id_cli,
    dp.id_pro,
    df.id_fec,
    det.cantidad,
    det.cantidad * det.preciounitario
  FROM
    PEDIDOS.DetallePedidos det
    JOIN PEDIDOS.Pedidos ped ON det.numeropedido = ped.numeropedido
    JOIN DIMFechas df ON ped.fecha = df.fecha
    JOIN DIMClientes dc ON ped.idcliente = dc.idcliente
    JOIN DIMProductos dp ON det.idproducto = dp.idproducto;

  COMMIT;
END cargar_FACTPedidos;
/


/*
 * Procedimiento ETL Maestro
 * Es un procedimiento que invoca a todos los anteriores, en orden
 */
-- Procedimiento para cargar todos los procedimientos ordenadamente
CREATE OR REPLACE PROCEDURE ejecutar_ETLMaestroDW IS
BEGIN
  cargar_DIMFechas;
  cargar_DIMClientes;
  cargar_DIMProductos;
  cargar_FACTPedidos;
END;
/


-- Ejecutar el ETL Maestro
EXEC ejecutar_ETLMaestroDW;


-- FIN DEL SCRIPT
