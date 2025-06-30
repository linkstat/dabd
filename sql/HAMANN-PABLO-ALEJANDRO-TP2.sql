/* TRABAJO PRÁCTICO 2
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
 * 1. Intenté, siempre que fuera posible, adaptar lo realizado en el TP1 (para el motor de base de datos de MySQL/MariaDB),
 *    al motor de base de datos de Oracle Database XE 21.
 *
 * 1. Decidí utilizar UUID almacenado como RAW(16) para los IDs.
 *    Justificación: ya venía haciéndolo así desde eltP1 en MySQL/MariaDB.
 *
 * 2. El presente script está pensado como un "todo en uno", en el sentido de que su ejecución, ELIMINA COMPLETAMENTE EL ESQUEMA (USUARIO), y RECREA TODO DESDE CERO.
 *    Justificación: es mucho más fácil para probar que todo fucnciona bien desde cero (con cada ejecución), sobre todo cuando se trabaja realizando constantes cambios.
 *
 *
 * = Repositorio en GitHub =
 * Este archivo es parte del siguiente repositorio en GitHub (creado para esta materia):
 *
 * Repositorio:   https://github.com/linkstat/dabd
 * Este archivo:  https://raw.githubusercontent.com/linkstat/dabd/refs/heads/main/sql/HAMANN-PABLO-ALEJANDRO-TP2.sql
 *
 */



/*
 * Sección 0: Tareas previas a la creación del esquema y configuración del entorno.
 */

-- 0.0 Borrar esquema (usuario) si existiera
BEGIN
  EXECUTE IMMEDIATE 'DROP USER PEDIDOS CASCADE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -1918 THEN RAISE; END IF;  -- ORA-01918: usuario no existe
END;
/

-- 0.1 Crear el esquema y darle privilegios
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE USER PEDIDOS IDENTIFIED BY dabdTP2
      DEFAULT TABLESPACE USERS
      TEMPORARY TABLESPACE TEMP
      QUOTA UNLIMITED ON USERS
  ]';
  EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE TO PEDIDOS';
END;
/

-- 0.2 Cambiar al esquema PEDIDOS
ALTER SESSION SET CURRENT_SCHEMA = PEDIDOS;



/* 0.3 Definición de funciones personalizadas
 * De forma análoga a lo antes realizado en MySQL, utilizo UUID almacenado en crudo (raw); para esto, desarrollamos dos funciones de conversión.
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



/*
 * Sección 1: Sentencias DDL para la creación del esquema y objetos (tablas, secuencias, funciones).
 */


-- Creación de las tablas del modelo dado
CREATE TABLE Clientes (
    idcliente  RAW(16) NOT NULL CONSTRAINT pk_clientes PRIMARY KEY,
    dni        VARCHAR2(20) NOT NULL,
    apellido   VARCHAR2(100) NOT NULL,
    nombres    VARCHAR2(100) NOT NULL,
    direccion  VARCHAR2(255) NOT NULL,
    mail       VARCHAR2(100) NOT NULL
);

CREATE TABLE Proveedores (
    idproveedor      RAW(16) NOT NULL CONSTRAINT pk_proveedores PRIMARY KEY,
    nombreproveedor  VARCHAR2(100) NOT NULL,
    direccion        VARCHAR2(255) NOT NULL,
    email            VARCHAR2(100) NOT NULL
);

CREATE TABLE Vendedor (
    idvendedor  RAW(16) NOT NULL CONSTRAINT pk_vendedor PRIMARY KEY,
    dni         VARCHAR2(20) NOT NULL,
    apellido    VARCHAR2(100) NOT NULL,
    nombres     VARCHAR2(100) NOT NULL,
    email       VARCHAR2(100) NOT NULL,
    comision    NUMBER(5,2)    NOT NULL
);

CREATE TABLE Productos (
    idproducto     RAW(16) NOT NULL CONSTRAINT pk_productos PRIMARY KEY,
    descripcion    VARCHAR2(255) NOT NULL,
    preciounitario NUMBER(10,2)  NOT NULL,
    stock          NUMBER        NOT NULL,
    stockmax       NUMBER        NOT NULL,
    stockmin       NUMBER        NOT NULL,
    idproveedor    RAW(16)       NOT NULL,
    origen         VARCHAR2(10)  NOT NULL,
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (idproveedor)
      REFERENCES Proveedores(idproveedor),
    CONSTRAINT chk_productos_origen CHECK (origen IN ('nacional', 'importado'))
);

/* Aquí me tomé la libertad de modificar levemente la propuesta dada.
 * Por un lado, tengo que conservar el concepto de nro de pedido (para la presentación de datos, por ejemplo),
 * y por otra parte, quiero mantener consistencia interna al usar UUID binario para las PK.
 */
CREATE TABLE Pedidos (
    idpedido      RAW(16) NOT NULL CONSTRAINT pk_pedidos PRIMARY KEY,
    numeropedido NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY NOT NULL,
    idcliente     RAW(16) NOT NULL,
    idvendedor    RAW(16) NOT NULL,
    fecha         DATE    NOT NULL,
    estado        VARCHAR2(15) DEFAULT 'pendiente' NOT NULL,
    CONSTRAINT uq_pedidos_numeropedido UNIQUE (numeropedido),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (idcliente)
      REFERENCES Clientes(idcliente) ON DELETE CASCADE,
    CONSTRAINT fk_pedido_vendedor FOREIGN KEY (idvendedor)
      REFERENCES Vendedor(idvendedor)
);


-- Misma lógica de 'modificación sutil' que para la tabla anterior
CREATE TABLE DetallePedidos (
    iddetallepedido RAW(16) NOT NULL CONSTRAINT pk_detallepedidos PRIMARY KEY,
    numeropedido   NUMBER         NOT NULL,
    renglon         NUMBER         NOT NULL,
    idproducto      RAW(16)        NOT NULL,
    cantidad        NUMBER         NOT NULL,
    preciounitario  NUMBER(10,2)   NOT NULL,
    total           NUMBER(10,2) GENERATED ALWAYS AS (cantidad * preciounitario) VIRTUAL,
    CONSTRAINT uq_detallepedidos UNIQUE (numeropedido, renglon),
    CONSTRAINT fk_detalle_numpedido FOREIGN KEY (numeropedido)
      REFERENCES Pedidos(numeropedido) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (idproducto)
      REFERENCES Productos(idproducto)
);

/* Esta tabla no se explicita en la actividad propuesta, pero sin embargo, la penúltima regla (del TP1) indicaba que:
 * Todo pedido anulado debe ser auditado, grabando en la tabla de log, la información
 * del pedido anulado, indicando la fecha de anulación.
 */
CREATE TABLE LogAnulaciones (
    idloganulaciones RAW(16) NOT NULL CONSTRAINT pk_loganulaciones PRIMARY KEY,
    idpedido         RAW(16)        NOT NULL,
    fechaanulacion   TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    observaciones    CLOB,
    CONSTRAINT fk_log_idpedido FOREIGN KEY (idpedido)
      REFERENCES Pedidos(idpedido)
);


/* En la consigna, se indican ciertas reglas de negocio
 * Para poder cumplir con estas restricciones, necesitamos ciertos triggers que nos ayuden a cumplirlas.
 * En este trigger BEFORE INSERT para DetallePedidos asegura que:
 * -> se consulte el stock disponible y el precio unitario actual del producto (según su idproducto).
 * -> se produzca un error si el stock es insuficiente para la cantidad solicitada.
 * -> se asigne el precio unitario del producto en el campo correspondiente del detalle.
 * -> se indica producto y stock cuando se genera el error (generamos un error en la inserción del producto 10)
 */
CREATE OR REPLACE TRIGGER trg_before_insert_detalle
BEFORE INSERT ON DetallePedidos
FOR EACH ROW
DECLARE
    v_stock   Productos.stock%TYPE;
    v_precio  Productos.preciounitario%TYPE;
    v_desc    VARCHAR2(255);
    v_msg     VARCHAR2(512);
BEGIN
    -- Consultar stock, precio y descripción
    SELECT stock, preciounitario, descripcion
      INTO v_stock, v_precio, v_desc
      FROM Productos
     WHERE idproducto = :NEW.idproducto;

    -- Si no hay stock suficiente, error con detalle
    IF v_stock < :NEW.cantidad THEN
        v_msg := 'Stock insuficiente para el producto ' || v_desc ||
                 '. Stock disponible: ' || v_stock ||
                 '. Cantidad requerida: ' || :NEW.cantidad;
        RAISE_APPLICATION_ERROR(-20001, v_msg);
    END IF;

    -- Asignar precio unitario actual al detalle
    :NEW.preciounitario := v_precio;
END;
/


/* Otra imposición de la consigna a resolver, consiste en actualizar el stock del producto al confirmar el pedido.
 * Este trigger sobre la tabla Pedidos se dispara después de una actualización:
 * -> cuando el estado de un pedido cambia a 'confirmado' (si es que previamente no lo estaba), se actualiza el stock de cada producto restando la cantidad pedida.
 */
CREATE OR REPLACE TRIGGER trg_after_update_confirmado
AFTER UPDATE ON Pedidos
FOR EACH ROW
BEGIN
    IF :NEW.estado = 'confirmado' AND :OLD.estado <> 'confirmado' THEN
        UPDATE Productos p
           SET p.stock = p.stock - (
             SELECT d.cantidad
               FROM DetallePedidos d
              WHERE d.numeropedido = :NEW.numeropedido
                AND d.idproducto = p.idproducto
           )
         WHERE EXISTS (
             SELECT 1
               FROM DetallePedidos d
              WHERE d.numeropedido = :NEW.numeropedido
                AND d.idproducto = p.idproducto
         );
    END IF;
END;
/


/* Este trigger es practicamente identico al anterior, solo que se ejecuta durante la inserción, y en la tabla DetallePedidos
 * ¿por qué? porque el trigger anterior no sirve cuando se realiza la inserción directamente como confirmado
 * si la lógica de negocios es que un pedido ingresa como pendiente si o si, y luego debiera ser actualizado,
 * este trigger no tendría sentido. Pero como estamos realizando inserciones con pedidos que pueden tener estado
 * çonfirmado' al momento del INSERT, entonces este trigger es fundamental para actualizar el stock. Además, cuando
 * hacemos este tipo de inserciones (como en este TP), en ese momento aún no existen los detalles del pedido, entonces
 * la actualización no se realiza (por eso la hacemos sobre DetallePedidos).
 */
CREATE OR REPLACE TRIGGER trg_after_insert_detalle_stock
AFTER INSERT ON DetallePedidos
FOR EACH ROW
DECLARE
    v_estado Pedidos.estado%TYPE;
BEGIN
    -- Obtener estado actual del pedido
    SELECT estado
      INTO v_estado
      FROM Pedidos
     WHERE numeropedido = :NEW.numeropedido;

    -- Si está confirmado, restar stock del producto
    IF v_estado = 'confirmado' THEN
        UPDATE Productos
           SET stock = stock - :NEW.cantidad
         WHERE idproducto = :NEW.idproducto;
    END IF;
END;
/


/* Otra regla de negocio indicada en la consigna, indica que, 
 * -> Todo pedido anulado debe ser auditado, grabando en la tabla de log, la información del pedido anulado, indicando la fecha de anulación.
 * -> El sistema debe recomponer el stock de cada pedido confirmado que es anulado.
 * Entonces, cuando se anula un pedido (cambiando el estado a 'anulado'),
 * este trigger sobre la tabla Pedidos, en su acción acción AFTER UPDATE, realizará lo siguiente:
 * -> Registrar en LogAnulaciones la información del pedido anulado (incluida la fecha de anulación).
 * -> Reponer el stock de los productos involucrados (sumando las cantidades que se restaron previamente).
 */
CREATE OR REPLACE TRIGGER trg_after_update_anulado
AFTER UPDATE ON Pedidos
FOR EACH ROW
BEGIN
    IF :NEW.estado = 'anulado' AND :OLD.estado = 'confirmado' THEN
        -- Reponer stock de cada producto del pedido
        FOR rec IN (
            SELECT idproducto, cantidad
              FROM DetallePedidos
             WHERE numeropedido = :NEW.numeropedido
        ) LOOP
            UPDATE Productos
               SET stock = stock + rec.cantidad
             WHERE idproducto = rec.idproducto;
        END LOOP;
        -- Registrar anulación en log
        INSERT INTO LogAnulaciones (
            idloganulaciones, idpedido, fechaanulacion, observaciones
        ) VALUES (
            SYS_GUID(),
            :NEW.idpedido,
            SYSTIMESTAMP,
            'Pedido ' || :NEW.numeropedido || ' anulado.'
        );
    END IF;
END;
/


/* Este triger, verifica que cuando se inserte un nuevo producto, el valor de Stock se encuentre el máximo y mínomo posible.
 * Atento a la regla de negocio que indica:
 * Al ingresar un nuevo producto, se debe controlar que el stock se encuentre entre los límites de stock mínimo y máximo.
 */
CREATE OR REPLACE TRIGGER trg_before_insert_productos
BEFORE INSERT ON Productos
FOR EACH ROW
BEGIN
    IF :NEW.stock < :NEW.stockmin OR :NEW.stock > :NEW.stockmax THEN
        RAISE_APPLICATION_ERROR(-20002,
            'El stock (' || :NEW.stock || ') debe estar entre ' ||
            :NEW.stockmin || ' y ' || :NEW.stockmax || '.');
    END IF;
END;
/



/*
 * Sección 2: Sentencias DML para la inserción de datos iniciales en el esquema.
 *
 * Declaramos un único bloque PL/SQL que captura todos los UUID necesarios y reutiliza
 * variables para clientes, proveedores, productos, vendedores, pedidos y detalles.
 */
DECLARE
  -- UUIDs para Clientes
  v_uuid_cliente1 RAW(16) := SYS_GUID();
  v_uuid_cliente2 RAW(16) := SYS_GUID();
  v_uuid_cliente3 RAW(16) := SYS_GUID();
  v_uuid_cliente4 RAW(16) := SYS_GUID();
  v_uuid_cliente5 RAW(16) := SYS_GUID();
  -- UUIDs para Proveedores
  v_uuid_proveedor1 RAW(16) := SYS_GUID();
  v_uuid_proveedor2 RAW(16) := SYS_GUID();
  v_uuid_proveedor3 RAW(16) := SYS_GUID();
  -- UUIDs para Productos
  v_uuid_prod01 RAW(16) := SYS_GUID();
  v_uuid_prod02 RAW(16) := SYS_GUID();
  v_uuid_prod03 RAW(16) := SYS_GUID();
  v_uuid_prod04 RAW(16) := SYS_GUID();
  v_uuid_prod05 RAW(16) := SYS_GUID();
  v_uuid_prod06 RAW(16) := SYS_GUID();
  v_uuid_prod07 RAW(16) := SYS_GUID();
  v_uuid_prod08 RAW(16) := SYS_GUID();
  v_uuid_prod09 RAW(16) := SYS_GUID();
  v_uuid_prod10 RAW(16) := SYS_GUID();
  -- UUIDs para Vendedores
  v_uuid_vendedor1 RAW(16) := SYS_GUID();
  v_uuid_vendedor2 RAW(16) := SYS_GUID();
  v_uuid_vendedor3 RAW(16) := SYS_GUID();
  -- UUIDs para Pedidos
  v_uuid_pedido01 RAW(16) := SYS_GUID();
  v_uuid_pedido02 RAW(16) := SYS_GUID();
  v_uuid_pedido03 RAW(16) := SYS_GUID();
  v_uuid_pedido04 RAW(16) := SYS_GUID();
  v_uuid_pedido05 RAW(16) := SYS_GUID();
  v_uuid_pedido06 RAW(16) := SYS_GUID();
  v_uuid_pedido07 RAW(16) := SYS_GUID();
  v_uuid_pedido08 RAW(16) := SYS_GUID();
  v_uuid_pedido09 RAW(16) := SYS_GUID();
  v_uuid_pedido10 RAW(16) := SYS_GUID();
  -- Variables para capturar numeropedido tras INSERT
  v_numPedido1  NUMBER;
  v_numPedido2  NUMBER;
  v_numPedido3  NUMBER;
  v_numPedido4  NUMBER;
  v_numPedido5  NUMBER;
  v_numPedido6  NUMBER;
  v_numPedido7  NUMBER;
  v_numPedido8  NUMBER;
  v_numPedido9  NUMBER;
  v_numPedido10 NUMBER;
BEGIN
  -- Insertar Clientes
  INSERT INTO Clientes(idcliente,dni,apellido,nombres,direccion,mail)
    VALUES(v_uuid_cliente1,'18465781','Rojas Valdivia','Lucy Amanda','Av. Sabatini 3288','lucyamanda23@latinmail.com');
  INSERT INTO Clientes(idcliente,dni,apellido,nombres,direccion,mail)
    VALUES(v_uuid_cliente2,'39512723','Alcaide','Santiago Agustín','Yrigoyen 733 5 C, La Plata, Buenos Aires','santialcaide@mineral.ru');
  INSERT INTO Clientes(idcliente,dni,apellido,nombres,direccion,mail)
    VALUES(v_uuid_cliente3,'22101645','Roqué','Juan Manuel','Avellaneda 935, La Banda, Santiago del Estero','jmroque@yustech.com.ar');
  INSERT INTO Clientes(idcliente,dni,apellido,nombres,direccion,mail)
    VALUES(v_uuid_cliente4,'42013728','Pérez','Carlos Enrique','Bedoya 724, Córdoba, Córdoba','carlitosperez@gmail.com');
  INSERT INTO Clientes(idcliente,dni,apellido,nombres,direccion,mail)
    VALUES(v_uuid_cliente5,'12309421','Sánchez','Omar Wenceslao','Rivadavia, 724 3 C, Rosario, Santa Fe','wen733@mail.ru');

  -- Insertar Proveedores
  INSERT INTO Proveedores(idproveedor,nombreproveedor,direccion,email)
    VALUES(v_uuid_proveedor1,'Marolio','Corrientes 2350, Gral. Rodríguez, Buenos Aires','info@marolio.com.ar');
  INSERT INTO Proveedores(idproveedor,nombreproveedor,direccion,email)
    VALUES(v_uuid_proveedor2,'Arcor','Av. Chacabuco 1160, Córdoba, Córdoba','arcor@arcor.com');
  INSERT INTO Proveedores(idproveedor,nombreproveedor,direccion,email)
    VALUES(v_uuid_proveedor3,'Dos Hermanos','Av. Pres. Juan Domingo Perón y Scalabrini Ortiz, Concordia, Entre Ríos','info@doshermanos.com.ar');

  -- Insertar Productos
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod01,'Arroz Parboil 1kg Dos Hnos Libre Gluten Sin Tacc',20865.0,1518,5000,500,v_uuid_proveedor3,'nacional');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod02,'Huevo de pascuas Arcor Milk unicornio chocolate 140g',18999.0,12497,15000,0,v_uuid_proveedor2,'nacional');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod03,'Yerba Mate Marolio Con Menta - Bolsa 500g',1487.5,1213,12000,1050,v_uuid_proveedor1,'nacional');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod04,'Turron Arcor 25 Gramos Display De 50 Unidades',11999.4,870,1942,200,v_uuid_proveedor2,'nacional');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod05,'Arroz Yamani 500g Dos Hermanos Integral Sin Tacc Libre Gluten',6017.0,1803,7500,780,v_uuid_proveedor3,'importado');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod06,'Picadillo Marolio 90g',1648.98,680,3800,230,v_uuid_proveedor1,'nacional');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod07,'Mermelada Marolio Damasco Frasco 454 Gr',2240.0,213,1300,25,v_uuid_proveedor1,'nacional');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod08,'Mermelada Light De Ciruela Arcor X 390 Grs',2559.0,329,1150,20,v_uuid_proveedor2,'importado');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod09,'Bocadito Holanda Arcor X 24 Unidades',9799.0,871,900,50,v_uuid_proveedor2,'nacional');
  INSERT INTO Productos(idproducto,descripcion,preciounitario,stock,stockmax,stockmin,idproveedor,origen)
    VALUES(v_uuid_prod10,'Palmito Rodaja 800 Gramos Marolio',7900.0,852,2500,500,v_uuid_proveedor1,'importado');

  -- Insertar Vendedores
  INSERT INTO Vendedor(idvendedor,dni,apellido,nombres,email,comision)
    VALUES(v_uuid_vendedor1,'36113214','Garay','Mauricio Elio','mgaray@msn.com',10.15);
  INSERT INTO Vendedor(idvendedor,dni,apellido,nombres,email,comision)
    VALUES(v_uuid_vendedor2,'28101438','Cabral Perez','Matías','mcp@outlook.com',23.2);
  INSERT INTO Vendedor(idvendedor,dni,apellido,nombres,email,comision)
    VALUES(v_uuid_vendedor3,'24741573','Castellanos','Matías','mcastellanos@gmail.com',14.6);

  -- Insertar Pedidos y capturar numeropedido
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido01,v_uuid_cliente1,v_uuid_vendedor1,DATE '2025-02-23','confirmado')
    RETURNING numeropedido INTO v_numPedido1;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido02,v_uuid_cliente5,v_uuid_vendedor2,DATE '2025-03-14','confirmado')
    RETURNING numeropedido INTO v_numPedido2;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido03,v_uuid_cliente1,v_uuid_vendedor1,DATE '2025-04-04','pendiente')
    RETURNING numeropedido INTO v_numPedido3;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido04,v_uuid_cliente4,v_uuid_vendedor2,DATE '2025-01-28','confirmado')
    RETURNING numeropedido INTO v_numPedido4;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido05,v_uuid_cliente2,v_uuid_vendedor3,DATE '2025-04-11','confirmado')
    RETURNING numeropedido INTO v_numPedido5;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido06,v_uuid_cliente2,v_uuid_vendedor3,DATE '2025-02-18','pendiente')
    RETURNING numeropedido INTO v_numPedido6;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido07,v_uuid_cliente1,v_uuid_vendedor3,DATE '2025-01-08','confirmado')
    RETURNING numeropedido INTO v_numPedido7;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido08,v_uuid_cliente3,v_uuid_vendedor2,DATE '2025-03-05','confirmado')
    RETURNING numeropedido INTO v_numPedido8;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido09,v_uuid_cliente4,v_uuid_vendedor2,DATE '2025-04-10','pendiente')
    RETURNING numeropedido INTO v_numPedido9;
  INSERT INTO Pedidos(idpedido,idcliente,idvendedor,fecha,estado)
    VALUES(v_uuid_pedido10,v_uuid_cliente3,v_uuid_vendedor2,DATE '2025-03-21','confirmado')
    RETURNING numeropedido INTO v_numPedido10;

  -- Insertar en DetallePedidos
  -- Nota, los números de pedido son autoincrementales (no se introducen manualmente),
  -- asi que recupero el valor que necesito en cada caso, realizando una consulta (tengo/conozco el @uuid_pedidoNN)

  -- Pedido 01 de 10 (3 renglones)
  INSERT INTO DetallePedidos(iddetallepedido,numeropedido,renglon,idproducto,cantidad)
    VALUES(SYS_GUID(),v_numPedido1,1,v_uuid_prod01,58);
  INSERT INTO DetallePedidos(iddetallepedido,numeropedido,renglon,idproducto,cantidad)
    VALUES(SYS_GUID(),v_numPedido1,2,v_uuid_prod02,32);
  INSERT INTO DetallePedidos(iddetallepedido,numeropedido,renglon,idproducto,cantidad)
    VALUES(SYS_GUID(),v_numPedido1,3,v_uuid_prod03,211);

  -- Pedido 02 de 10 (1 renglón)
  INSERT INTO DetallePedidos(iddetallepedido,numeropedido,renglon,idproducto,cantidad)
    VALUES(SYS_GUID(),v_numPedido2,1,v_uuid_prod05,36);

  -- Pedido 03 de 10 (2 renglones)
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido3, 1, v_uuid_prod01,  9);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido3, 2, v_uuid_prod04, 12);

  -- Pedido 04 de 10 (3 renglones)
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido4, 1, v_uuid_prod09, 15);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido4, 2, v_uuid_prod06, 22);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido4, 3, v_uuid_prod08, 10);

  -- Pedido 05 de 10 (1 renglón)
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido5, 1, v_uuid_prod10, 14);

  -- Pedido 06 de 10 (2 renglones)
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido6, 1, v_uuid_prod04, 75);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido6, 2, v_uuid_prod08, 23);

  -- Pedido 07 de 10 (3 renglones)
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido7, 1, v_uuid_prod07, 38);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido7, 2, v_uuid_prod04, 52);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido7, 3, v_uuid_prod01, 92);

  -- Pedido 08 de 10 (2 renglones)
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido8, 1, v_uuid_prod08, 108);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido8, 2, v_uuid_prod06, 625);

  -- Pedido 09 de 10 (1 renglón)
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido9, 1, v_uuid_prod02, 458);

  -- Pedido 10 de 10 (3 renglones)
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido10, 1, v_uuid_prod05, 15);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido10, 2, v_uuid_prod03, 22);
  INSERT INTO DetallePedidos(iddetallepedido, numeropedido, renglon, idproducto, cantidad)
    VALUES (SYS_GUID(), v_numPedido10, 3, v_uuid_prod08,210);

  COMMIT;
END;
/


/*
 * Sección 3: Sentencias SQL de prueba y consultas de verificación.
 */

-- 3.1 Detalle de clientes que realizaron pedidos entre fechas
PROMPT
PROMPT 1. Detalle de clientes que realizaron pedidos entre fechas
SELECT DISTINCT c.apellido   AS Apellido,
                c.nombres    AS Nombres,
                c.dni        AS DNI,
                c.mail       AS Email
FROM Clientes c
JOIN Pedidos p ON c.idcliente = p.idcliente
WHERE p.fecha BETWEEN DATE '2025-04-01' AND DATE '2025-04-30';

-- 3.2 Detalle de vendedores con la cantidad de pedidos realizados
PROMPT
PROMPT 2. Detalle de vendedores con la cantidad de pedidos realizados
SELECT v.apellido        AS Apellido,
       v.nombres         AS Nombres,
       v.dni             AS DNI,
       v.email           AS Email,
       COUNT(p.idpedido) AS Cant_Pedidos
FROM Vendedor v
LEFT JOIN Pedidos p ON v.idvendedor = p.idvendedor
GROUP BY v.idvendedor, v.apellido, v.nombres, v.dni, v.email;

-- 3.3 Detalle de pedidos con total mayor a 500000
PROMPT
PROMPT 3. Detalle de pedidos con total mayor a 500000
SELECT p.numeropedido    AS NumeroPedido,
       p.fecha           AS Fecha,
       SUM(d.total)      AS TotalPedido
FROM Pedidos p
JOIN DetallePedidos d ON p.numeropedido = d.numeropedido
GROUP BY p.numeropedido, p.fecha
HAVING SUM(d.total) > 500000;

-- 3.4 Lista de productos vendidos entre fechas
PROMPT
PROMPT 4. Lista de productos vendidos entre fechas
SELECT pr.descripcion     AS Descripcion,
       SUM(dp.cantidad)    AS CantidadTotal
FROM Pedidos pe
JOIN DetallePedidos dp ON pe.numeropedido = dp.numeropedido
JOIN Productos pr    ON dp.idproducto   = pr.idproducto
WHERE pe.fecha BETWEEN DATE '2025-04-01' AND DATE '2025-04-30'
GROUP BY pr.descripcion;

-- 3.5 Proveedor con mayor cantidad de productos vendidos
PROMPT
PROMPT 5. Proveedor con mayor cantidad de productos vendidos
SELECT *
FROM (
  SELECT prov.nombreproveedor AS NombreProveedor,
         SUM(dp.cantidad)      AS TotalProductosVendidos
  FROM Proveedores prov
  JOIN Productos prod   ON prov.idproveedor = prod.idproveedor
  JOIN DetallePedidos dp ON prod.idproducto  = dp.idproducto
  GROUP BY prov.idproveedor, prov.nombreproveedor
  ORDER BY SUM(dp.cantidad) DESC
) WHERE ROWNUM = 1;

-- 3.6 Clientes registrados que nunca realizaron un pedido
PROMPT
PROMPT 6. Clientes registrados que nunca realizaron un pedido
SELECT c.apellido AS Apellido,
       c.nombres  AS Nombres,
       c.mail     AS Email
FROM Clientes c
LEFT JOIN Pedidos p ON c.idcliente = p.idcliente
WHERE p.idcliente IS NULL;

-- 3.7 Clientes que realizaron menos de dos pedidos
PROMPT
PROMPT 7. Clientes que realizaron menos de dos pedidos
SELECT c.apellido AS Apellido,
       c.nombres  AS Nombres,
       c.mail     AS Email
FROM Clientes c
LEFT JOIN Pedidos p ON c.idcliente = p.idcliente
GROUP BY c.idcliente, c.apellido, c.nombres, c.mail
HAVING COUNT(p.idpedido) < 2;

-- 3.8 Cantidad total vendida por origen de producto
PROMPT
PROMPT 8. Cantidad total vendida por origen de producto
SELECT p.origen             AS Origen,
       SUM(d.cantidad)       AS CantidadTotalVendida
FROM Productos p
JOIN DetallePedidos d ON p.idproducto = d.idproducto
GROUP BY p.origen;



-- *** PUNTOS SOLICITADOS EN EL TP2 *** --



/* PUNTO 1:
 * Crear un bloque PL SQL que permita, mediante una transacción, realizar el
 * registro de un pedido con su detalle (renglones). El proceso debe contemplar
 * la actualización del stock de los productos pedidos. En caso de producirse un
 * error, la transacción debe ser cancelada. 
 */

SET SERVEROUTPUT ON
/

-- Pedidos de valores al usuario (intercalado ID y respectiva cantidad)
ACCEPT cli_uuid   CHAR PROMPT 'UUID Cliente (36 chars, incl. guiones): '
ACCEPT vend_uuid  CHAR PROMPT 'UUID Vendedor (36 chars, incl. guiones): '
ACCEPT prod1_uuid CHAR PROMPT '1) UUID Producto 1: '
ACCEPT qty1       NUMBER PROMPT    '   Cantidad producto 1: '
ACCEPT prod2_uuid CHAR PROMPT '2) UUID Producto 2 [ENTER para omitir]: '
ACCEPT qty2       NUMBER PROMPT    '   Cantidad producto 2: '
ACCEPT prod3_uuid CHAR PROMPT '3) UUID Producto 3 [ENTER para omitir]: '
ACCEPT qty3       NUMBER PROMPT    '   Cantidad producto 3: '
/

DECLARE
  -- Cabecera
  v_idPedido   RAW(16) := SYS_GUID();
  v_numPedido  NUMBER;

  -- Valores ingresados (texto)
  v_cli_hex    VARCHAR2(36) := '&cli_uuid';
  v_vend_hex   VARCHAR2(36) := '&vend_uuid';
  v_prod1_hex  VARCHAR2(36) := '&prod1_uuid';
  v_prod2_hex  VARCHAR2(36) := '&prod2_uuid';
  v_prod3_hex  VARCHAR2(36) := '&prod3_uuid';
  v_qty1       PLS_INTEGER := &qty1;
  v_qty2       PLS_INTEGER := &qty2;
  v_qty3       PLS_INTEGER := &qty3;

  -- Conversión a RAW
  v_idCliente  RAW(16);
  v_idVendedor RAW(16);

  -- Tablas asociativas para detalle
  TYPE t_raw_tab IS TABLE OF RAW(16) INDEX BY PLS_INTEGER;
  TYPE t_int_tab IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;
  v_ids  t_raw_tab;
  v_qtys t_int_tab;

  v_stock   NUMBER;
  v_n       PLS_INTEGER := 1;  -- mínimo: 1 renglón
BEGIN
  -- Validar y convertir Cliente
  IF NOT REGEXP_LIKE(v_cli_hex, '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$') THEN
    RAISE_APPLICATION_ERROR(-20030, 'UUID Cliente inválido: '||v_cli_hex);
  END IF;
  v_idCliente := uuid_to_raw(v_cli_hex);

  -- Validar y convertir Vendedor
  IF NOT REGEXP_LIKE(v_vend_hex, '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$') THEN
    RAISE_APPLICATION_ERROR(-20031, 'UUID Vendedor inválido: '||v_vend_hex);
  END IF;
  v_idVendedor := uuid_to_raw(v_vend_hex);

  -- Producto 1 (obligatorio)
  IF NOT REGEXP_LIKE(v_prod1_hex, '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$') THEN
    RAISE_APPLICATION_ERROR(-20032, 'UUID Producto 1 inválido: '||v_prod1_hex);
  END IF;
  v_ids(1)  := uuid_to_raw(v_prod1_hex);
  v_qtys(1) := v_qty1;

  -- Producto 2 (opcional)
  IF TRIM(v_prod2_hex) IS NOT NULL THEN
    IF v_qty2 IS NULL THEN
      RAISE_APPLICATION_ERROR(-20033, 'Debe indicar cantidad para producto 2');
    END IF;
    IF NOT REGEXP_LIKE(v_prod2_hex, '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$') THEN
      RAISE_APPLICATION_ERROR(-20034, 'UUID Producto 2 inválido: '||v_prod2_hex);
    END IF;
    v_ids(2)  := uuid_to_raw(v_prod2_hex);
    v_qtys(2) := v_qty2;
    v_n := 2;
  END IF;

  -- Producto 3 (opcional)
  IF TRIM(v_prod3_hex) IS NOT NULL THEN
    IF v_qty3 IS NULL THEN
      RAISE_APPLICATION_ERROR(-20035, 'Debe indicarse cantidad para producto 3');
    END IF;
    IF NOT REGEXP_LIKE(v_prod3_hex, '^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$') THEN
      RAISE_APPLICATION_ERROR(-20036, 'UUID Producto 3 inválido: '||v_prod3_hex);
    END IF;
    v_ids(3)  := uuid_to_raw(v_prod3_hex);
    v_qtys(3) := v_qty3;
    v_n := 3;
  END IF;

  -- Insertar cabecera y obtener numero de pedido
  INSERT INTO Pedidos(idpedido, idcliente, idvendedor, fecha, estado)
    VALUES(v_idPedido, v_idCliente, v_idVendedor, SYSDATE, 'pendiente')
    RETURNING numeropedido INTO v_numPedido;

  -- Recorrer 1..v_n y procesar cada línea
  FOR i IN 1..v_n LOOP
    -- Intento leer el stock, pero si no existe el producto, capturo el error
    BEGIN
      SELECT stock INTO v_stock
        FROM Productos
        WHERE idproducto = v_ids(i)
        FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
          -20040,
          'Producto inexistente: ' || raw_to_uuid(v_ids(i))
        );
    END;

    IF v_stock < v_qtys(i) THEN
      RAISE_APPLICATION_ERROR(
        -20010,
        'Stock insuficiente (prod '||raw_to_uuid(v_ids(i))||
        '): dispo '||v_stock||', solicitado '||v_qtys(i)
      );
    END IF;

    -- Insertar detalle
    INSERT INTO DetallePedidos(
      iddetallepedido, numeropedido, renglon, idproducto, cantidad
    ) VALUES(
      SYS_GUID(), v_numPedido, i, v_ids(i), v_qtys(i)
    );

    -- Actualizar stock
    UPDATE Productos
        SET stock = stock - v_qtys(i)
      WHERE idproducto = v_ids(i);
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE(
    'Pedido '||v_numPedido||' registrado con '||v_n||' renglones.'
  );

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERROR: '||SQLERRM);
END;
/


/* A los fines de "probar" el bloque PL/SQL anterior, necesito obtener los IDs
 * (en mi caso UUIDs generados aleatoriamente), para poder introducir en el 
 * bloque PL/SQL (cuando sea ejecutado). Entonces, realizamos la siguiente
 * consulta para obtnerlos.
 */
SELECT
  -- Cliente y vendedor aleatorios
  raw_to_uuid(c.idcliente)  AS cliente_UUID,
  raw_to_uuid(v.idvendedor) AS vendedor_UUID,

  -- Producto 1 y su stock
  raw_to_uuid(p1.idproducto) AS prod1_UUID,
  p1.stock                   AS prod1_stock,

  -- Producto 2 y su stock
  raw_to_uuid(p2.idproducto) AS prod2_UUID,
  p2.stock                   AS prod2_stock,

  -- Producto 3 y su stock
  raw_to_uuid(p3.idproducto) AS prod3_UUID,
  p3.stock                   AS prod3_stock

FROM
  -- Elegimos un cliente al azar
  ( SELECT idcliente
      FROM (SELECT idcliente FROM Clientes ORDER BY DBMS_RANDOM.VALUE)
     WHERE ROWNUM = 1
  ) c
  -- Elegimos un vendedor al azar
  ,( SELECT idvendedor
      FROM (SELECT idvendedor FROM Vendedor ORDER BY DBMS_RANDOM.VALUE)
     WHERE ROWNUM = 1
  ) v
  -- Producto 1 aleatorio
  ,( SELECT idproducto, stock
      FROM (SELECT idproducto, stock FROM Productos ORDER BY DBMS_RANDOM.VALUE)
     WHERE ROWNUM = 1
  ) p1
  -- Producto 2 aleatorio
  ,( SELECT idproducto, stock
      FROM (SELECT idproducto, stock FROM Productos ORDER BY DBMS_RANDOM.VALUE)
     WHERE ROWNUM = 1
  ) p2
  -- Producto 3 aleatorio
  ,( SELECT idproducto, stock
      FROM (SELECT idproducto, stock FROM Productos ORDER BY DBMS_RANDOM.VALUE)
     WHERE ROWNUM = 1
  ) p3
;



/* PUNTO 2:
 * Crear un procedimiento almacenado que permita anular un pedido confirmado.
 * El proceso de anulación debe actualizar los stocks de los artículos del
 * pedido.
 */
-- Recibimos por parámetro, el número de pedido
CREATE OR REPLACE PROCEDURE anular_pedido_confirmado (
  p_numPedido IN NUMBER
) IS
  v_idPedido   RAW(16);
  v_estado     VARCHAR2(15);
  v_stock      NUMBER;
BEGIN
  -- Obtenemos idpedido y el estado del pedido
  SELECT idpedido, estado
    INTO v_idPedido, v_estado
    FROM Pedidos
   WHERE numeropedido = p_numPedido;    -- podría lanzar NO_DATA_FOUND

  -- Verificamos que esté confirmado
  IF v_estado <> 'confirmado' THEN
    RAISE_APPLICATION_ERROR(
      -20020,
      'No se puede anular el pedido ' || p_numPedido ||
      ' porque su estado actual es "' || v_estado ||
      '". Solo los pedidos en estado CONFIRMADO pueden anularse.'
    );
  END IF;

  -- Reponemos stock para cada renglón
  FOR reg IN (
    SELECT idproducto, cantidad
      FROM DetallePedidos
     WHERE numeropedido = p_numPedido
  ) LOOP
    UPDATE Productos
       SET stock = stock + reg.cantidad
     WHERE idproducto = reg.idproducto;    -- aquí actualizamos el stock ( equivalente a: SELECT ... FOR UPDATE + UPDATE)
  END LOOP;

  -- Marcamos como anulado el pedido
  UPDATE Pedidos
     SET estado = 'anulado'
   WHERE numeropedido = p_numPedido;

  -- Registramos en tabla de log
  INSERT INTO LogAnulaciones (
    idLogAnulaciones,
    idpedido,
    FechaAnulacion,
    Observaciones
  ) VALUES (
    SYS_GUID(),
    v_idPedido,
    SYSTIMESTAMP,
    'Pedido '||p_numPedido||' anulado.'
  );

  COMMIT;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(
      -20021,
      'Pedido no encontrado: '||p_numPedido
    );
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END anular_pedido_confirmado;
/


/* Vamos a obtener un listado de pedidos de forma talque podamos seleccionar
 * alguno que nos permita probar el procedimiento almacenado anterior y
 * (posteriormente a su ejecución) luego poder verificar que se anuló.
 */
SELECT
  p.numeropedido          AS NumeroPedido,
  p.estado                AS Estado,
  p.fecha                 AS Fecha,
  raw_to_uuid(p.idvendedor) AS Vendedor_UUID
FROM
  Pedidos p
ORDER BY
  p.numeropedido;

-- Llamamos al procedmiento almacenado anular_pedido_confirmado() y anulamos un pedido
-- anular pedido nro. 2 (confirmado)
EXEC anular_pedido_confirmado(2);
-- Intentamos nuevamente anular un pedido, pero esta vez, uno no confirmado:
-- anular pedido nro. 6 (pendiente)
EXEC anular_pedido_confirmado(6);


/* PUNTO 3:
 * Crear una tabla denominada log (idlog, numeroPedido, FechaAnulacion). 
 */
/* Si bien ya contábamos con una tabla LogAnulaciones (desde el TP1), observo
 * sutiles diferencias con la solicitada en este punto:
 * * nombre: 'log' (en vez de 'LogAnulaciones')
 * * campo: 'numeroPedido' (en lugar de 'idpedido')
 * * sin campo 'Observaciones' 
 */
CREATE TABLE log (
  idlog RAW(16)  NOT NULL
    CONSTRAINT pk_log PRIMARY KEY,
  numeroPedido  NUMBER  NOT NULL
    CONSTRAINT fk_log_numPedido
      REFERENCES Pedidos(numeroPedido),
  fechaAnulacion TIMESTAMP  DEFAULT SYSTIMESTAMP NOT NULL
);


/* PUNTO 4:
 * Crear un trigger que permita, al momento de anularse un pedido, registrar en
 * la tabla log, el número de pedido anulado y la fecha de anulación.
 */
CREATE OR REPLACE TRIGGER trg_after_update_anulacion
  AFTER UPDATE OF estado
    ON Pedidos
  FOR EACH ROW
  WHEN (
    NEW.estado   = 'anulado'
    AND OLD.estado <> 'anulado'
  )
BEGIN
  INSERT INTO log (
    idlog, 
    numeroPedido, 
    fechaAnulacion
  ) VALUES (
    SYS_GUID(), 
    :NEW.numeroPedido,
    SYSTIMESTAMP
  );
END;
/

-- Vamos a probar este trigger, y anulemos un pedido:(por ejemplo: nro 10)
EXEC anular_pedido_confirmado(7);

-- Anulado un pedido, vamos a chequear la tabla de Logs:
SELECT
  raw_to_uuid(idlog)  AS idLog_ID,
  numeroPedido  AS nro_Pedido,
  FechaAnulacion
FROM log
ORDER BY FechaAnulacion DESC;




/* PUNTO 5:
 * Crear un procedimiento almacenado que permita actualizar el precio de los
 * artículos de un determinado origen en un determinado porcentaje.
 */
CREATE OR REPLACE PROCEDURE actualizar_precio_por_origen (
  p_origen      IN VARCHAR2,
  p_porcentaje  IN NUMBER
) IS
  -- factor de ajuste calculado a partir del porcentaje
  v_factor NUMBER := 1 + p_porcentaje/100;
BEGIN
  -- cctualizams precios multiplicando por factor de ajuste. Redondeamos 2 dec.
  UPDATE Productos
     SET preciounitario = ROUND(preciounitario * v_factor, 2)
   WHERE origen = p_origen;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;  -- si lacosa falla, deshacer cambios y generar error con código personalizado
    RAISE_APPLICATION_ERROR(
      -20050,
      'Error al actualizar precios para origen "'||p_origen||'": '||SQLERRM
    );
END actualizar_precio_por_origen;
/


/*
 * Ahora,vamos a probar el procedimiento almacenado.
 */
 
-- Consultamos los precios de los productos nacionales ANTES del cambio de precios
SELECT 'Lista de productos nacionales ANTES del cambio de precios' AS Descripcion FROM DUAL;
SELECT descripcion AS Producto, preciounitario AS PrecioActual
FROM Productos WHERE origen = 'nacional' ORDER BY descripcion;
-- Bajamos los productos nacionales un 15%
EXEC actualizar_precio_por_origen('nacional', -15);
-- Consultamos los precios de los productos nacionales DESPUES del cambio de precios
SELECT 'Lista de productos nacionales POSTERIOR al cambio de precios' AS Descripcion FROM DUAL;
SELECT descripcion AS Producto, preciounitario AS PrecioActual
FROM Productos WHERE origen = 'nacional' ORDER BY descripcion;


-- Consultamos los precios de los productos importados ANTES del cambio de precios
SELECT 'Lista de productos importados ANTES del cambio de precios' AS Descripcion FROM DUAL;
SELECT descripcion AS Producto, preciounitario AS PrecioActual
FROM Productos WHERE origen = 'importado' ORDER BY descripcion;
-- Aumentamos el precio de los importados en un 13%
BEGIN
  actualizar_precio_por_origen('importado', 13);
END;
/
-- Consultamos los precios de los productos nacionales DESPUES del cambio de precios
SELECT 'Lista de productos importados POSTERIOR al cambio de precios' AS Descripcion FROM DUAL;
SELECT descripcion AS Producto, preciounitario AS PrecioActual
FROM Productos WHERE origen = 'importado' ORDER BY descripcion;


