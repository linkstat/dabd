/* TRABAJO PRÁCTICO 1
 *
 *
 * .            Alumno:  HAMANN, PABLO ALEJANDRO
 * .            Legajo:  VINF010782
 * .               Año:  2025
 * . Prof. Disciplinar:  CASTELLI, SILVIA LAURA LANZA
 * .     Prof. Experto:  DAUBROWSKY, RICARDO RAMÓN
 * 
 * Software utilizado para el desarrollo del presente TP:
 * . Motor de BD:   - MariaDB 11.4.3
 * . Clientes SQL:  - HeidiSQL 12.6.0
 * .                - Navicat Premium 17.0.8
 *	.                - MySQL Workbench 8.0 CE
 * .        Otros:  - Git Bash
 * .                - Notepad++ 
 * .                - VSCode
 *
 *
 * Consideraciones a tener en cuenta:
 *
 * 1. Decidí utilizar UUID almacenado como BINARIO para los IDs.
 *    Justificación: es una práctica que adopté de Seminario de Práctica Profesional, y que me gustaría seguir aplicando cada vez que pueda.
 *
 * 2. El presente script está pensado como un "todo en uno", en el sentido de que su ejecución, ELIMINA COMPLETAMENTE LA BASE DE DATOS, y RECREA TODO DESDE CERO.
 *    Justificación: es mucho más fácil para probar que todo fucnciona bien desde cero (con cada ejecución), sobre todo cuando se trabaja realizando constantes cambios.
 *
 *
 * = Repositorio en GitHub =
 * Este archivo es parte del siguiente repositorio en GitHub (creado para esta materia):
 *
 * Repositorio:   https://github.com/linkstat/dabd
 * Este archivo:  https://raw.githubusercontent.com/linkstat/dabd/refs/heads/main/sql/HAMANN-PABLO-ALEJANDRO-TP1.sql
 *
 */



/*
 * Sección 0: Tareas previas a la creación de la estructura de la base de datos.
 */

-- Definición del nombre de la BD vía una variable (para evitar errores de tipeo, defino una sola vez, y utilizo luego la variable)
SET @dbname = 'pedidos';

-- Borrado de la BD (si existiera)
SET @sql = CONCAT('DROP DATABASE IF EXISTS ', @dbname);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Creación (o recreación, según) de la base de datos
SET @sql = CONCAT('CREATE DATABASE ', @dbname, ' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Ahora vamos a usar la BD creada
SET @sql = CONCAT('USE ', @dbname);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;


/* Definición de funciones personalizadas
 * Dado que se decidió utilizar UUID y almacenarlos en formato binario, contar con una función que facilite la inserción y consulta de estos datos, nos facilitará enormemente la vida.
 * Los UUIDs se almacenan usando la representación estándar, de esta forma podemos manipular sin problemas usando java.util.UUID.
 */
-- Función para convertir (y almacenar) un UUID en un binario de 16 bytes
DELIMITER $$
CREATE FUNCTION `UUID_TO_BIN`(uuid CHAR(36))
RETURNS BINARY(16)
DETERMINISTIC
BEGIN
  RETURN UNHEX(CONCAT(
    SUBSTRING(uuid, 1, 8),      -- aaaaaaaa
    SUBSTRING(uuid, 10, 4),     -- bbbb
    SUBSTRING(uuid, 15, 4),     -- cccc
    SUBSTRING(uuid, 20, 4),     -- dddd
    SUBSTRING(uuid, 25, 12)     -- eeeeeeeeeeee
  ));
END$$
DELIMITER ;

-- Función para recuperar y convertir de nuevo a UUID
DELIMITER $$
CREATE FUNCTION `BIN_TO_UUID`(b BINARY(16))
RETURNS CHAR(36) CHARSET ascii
DETERMINISTIC
BEGIN
   DECLARE hexStr CHAR(32);
   SET hexStr = HEX(b);
   RETURN LOWER(CONCAT(
     SUBSTR(hexStr, 1, 8), '-',      -- aaaaaaaa
     SUBSTR(hexStr, 9, 4), '-',      -- bbbb
     SUBSTR(hexStr, 13, 4), '-',     -- cccc
     SUBSTR(hexStr, 17, 4), '-',     -- dddd
     SUBSTR(hexStr, 21, 12)          -- eeeeeeeeeeee
  ));
END$$
DELIMITER ;



/*
 * Sección 1: Sentencias de creación de la estructura de la base de datos.
 */

-- Deshabilitar las Restricciones de Claves Foráneas
SET FOREIGN_KEY_CHECKS = 0;


-- Creación de las tablas del modelo dado
CREATE TABLE Clientes (
    idcliente BINARY(16) NOT NULL PRIMARY KEY,
    DNI VARCHAR(20) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Nombres VARCHAR(100) NOT NULL,
    Direccion VARCHAR(255) NOT NULL,
    mail VARCHAR(100) NOT NULL
);

CREATE TABLE Proveedores (
    idproveedor BINARY(16) NOT NULL PRIMARY KEY,
    NombreProveedor VARCHAR(100) NOT NULL,
    Direccion VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL
);

CREATE TABLE Vendedor (
    idvendedor BINARY(16) NOT NULL PRIMARY KEY,
    DNI VARCHAR(20) NOT NULL,
    Apellido VARCHAR(100) NOT NULL,
    Nombres VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    comision DECIMAL(5,2) NOT NULL
);

CREATE TABLE Productos (
    idproducto BINARY(16) NOT NULL PRIMARY KEY,
    Descripcion VARCHAR(255) NOT NULL,
    PrecioUnitario DECIMAL(10,2) NOT NULL,
    Stock INT NOT NULL,
    StockMax INT NOT NULL,
    StockMin INT NOT NULL,
    idproveedor BINARY(16) NOT NULL,
    origen ENUM('nacional', 'importado') NOT NULL,
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (idproveedor) REFERENCES Proveedores(idproveedor)
);

/* Aquí me tomé la libertad de modificar levemente la propuesta dada.
 * Por un lado, tengo que conservar el concepto de nro de pedido (para la presentación de datos, por ejemplo),
 * y por otra parte, quiero mantener consistencia interna al usar UUID binario para las PK.
 */
CREATE TABLE Pedidos (
    idpedido BINARY(16) NOT NULL PRIMARY KEY,
    NumeroPedido INT NOT NULL AUTO_INCREMENT,
    idcliente BINARY(16) NOT NULL,
    idvendedor BINARY(16) NOT NULL,
    fecha DATE NOT NULL,
    Estado ENUM('pendiente', 'confirmado', 'anulado') NOT NULL DEFAULT 'pendiente',
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (idcliente) REFERENCES Clientes(idcliente)
        ON DELETE RESTRICT,
    CONSTRAINT fk_pedido_vendedor FOREIGN KEY (idvendedor) REFERENCES Vendedor(idvendedor),
    UNIQUE KEY (NumeroPedido)
);


-- Misma lógica de 'modificación sutil' que para la tabla anterior
CREATE TABLE DetallePedidos (
    idDetallePedido BINARY(16) NOT NULL PRIMARY KEY,
    NumeroPedido INT NOT NULL,
    renglon INT NOT NULL,
    idproducto BINARY(16) NOT NULL,
    cantidad INT NOT NULL,
    PrecioUnitario DECIMAL(10,2) NOT NULL,
    Total DECIMAL(10,2) AS (cantidad * PrecioUnitario) VIRTUAL,
    CONSTRAINT uniq_detalle UNIQUE (NumeroPedido, renglon),
    CONSTRAINT fk_detalle_numpedido FOREIGN KEY (NumeroPedido) REFERENCES Pedidos(NumeroPedido)
        ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (idproducto) REFERENCES Productos(idproducto)
);

/* Esta tabla no se explicita en la actividad propuesta, pero sin embargo, la penúltima regla dice:
 * Todo pedido anulado debe ser auditado, grabando en la tabla de log, la información
 * del pedido anulado, indicando la fecha de anulación.
 */
CREATE TABLE LogAnulaciones (
    idLogAnulaciones BINARY(16) NOT NULL PRIMARY KEY,
    idpedido BINARY(16) NOT NULL,
    FechaAnulacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Observaciones TEXT,
    CONSTRAINT fk_log_idpedido FOREIGN KEY (idpedido) REFERENCES Pedidos(idpedido)
);


-- Rehabilitar las Restricciones de Claves Foráneas
SET FOREIGN_KEY_CHECKS = 1;


/* En la consigna, se indican ciertas reglas de negocio
 * Para poder cumplir con estas restricciones, necesitamos ciertos triggers que nos ayuden a cumplirlas.
 * En este trigger BEFORE INSERT para DetallePedidos asegura que:
 * -> se consulte el stock disponible y el precio unitario actual del producto (según su idproducto).
 * -> se produzca un error si el stock es insuficiente para la cantidad solicitada.
 * -> se asigne el precio unitario del producto en el campo correspondiente del detalle.
 * Actualizacion: 12/04/2025: ahora indica producto y stock cuando genera el error (generamos un error en la inserción del producto 10)
 */
DELIMITER $$
CREATE TRIGGER trg_before_insert_detalle
BEFORE INSERT ON DetallePedidos
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_desc VARCHAR(255);
    DECLARE v_msg VARCHAR(512);

    -- Consultamos el stock, precio y descripción del producto a insertar
    SELECT Stock, PrecioUnitario, Descripcion
      INTO v_stock, v_precio, v_desc
      FROM Productos
     WHERE idproducto = NEW.idproducto;
     
    -- Verificamos que haya stock suficiente; sino generamos un error informativo
    IF v_stock < NEW.cantidad THEN
        SET v_msg = CONCAT('Stock insuficiente para el producto ', v_desc,
                           '. Stock disponible: ', v_stock,
                           '. Cantidad requerida: ', NEW.cantidad);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    
    -- Asignar automáticamente el precio unitario del producto al detalle del pedido
    SET NEW.PrecioUnitario = v_precio;
END;
$$
DELIMITER ;


/* Otra imposición de la consigna a resolver, consiste en actualizar el stock del producto al confirmar el pedido.
 * Este trigger sobre la tabla Pedidos se dispara después de una actualización:
 * -> cuando el estado de un pedido cambia a 'confirmado' (si es que previamente no lo estaba), se actualiza el stock de cada producto restando la cantidad pedida.
 */
DELIMITER $$
CREATE TRIGGER trg_after_update_confirmado
AFTER UPDATE ON Pedidos
FOR EACH ROW
BEGIN
    IF NEW.Estado = 'confirmado' AND OLD.Estado <> 'confirmado' THEN
        UPDATE Productos p
        JOIN DetallePedidos d ON p.idproducto = d.idproducto
        SET p.Stock = p.Stock - d.cantidad
        WHERE d.NumeroPedido = NEW.NumeroPedido;
    END IF;
END;
$$
DELIMITER ;


/* Este trigger es practicamente identico al anterior, solo que se ejecuta durante la inserción, y en la tabla DetallePedidos
 * ¿por qué? porque el trigger anterior no sirve cuando se realiza la inserción directamente como confirmado
 * si la lógica de negocios es que un pedido ingresa como pendiente si o si, y luego debiera ser actualizado,
 * este trigger no tendría sentido. Pero como estamos realizando inserciones con pedidos que pueden tener estado
 * çonfirmado' al momento del INSERT, entonces este trigger es fundamental para actualizar el stock. Además, cuando
 * hacemos este tipo de inserciones (como en este TP), en ese momento aún no existen los detalles del pedido, entonces
 * la actualización no se realiza (por eso la hacemos sobre DetallePedidos).
 */
DELIMITER $$
CREATE TRIGGER trg_after_insert_detalle_stock
AFTER INSERT ON DetallePedidos
FOR EACH ROW
BEGIN
    DECLARE v_estado ENUM('pendiente','confirmado','anulado');
    
    -- Obtenemos el estado del pedido correspondiente al detalle
    SELECT Estado 
      INTO v_estado 
      FROM Pedidos 
     WHERE NumeroPedido = NEW.NumeroPedido;
    
    IF v_estado = 'confirmado' THEN
        UPDATE Productos
        SET Stock = Stock - NEW.cantidad
        WHERE idproducto = NEW.idproducto;
    END IF;
END$$
DELIMITER ;


/* Otra regla de negocio indicada en la consigna, indica que, 
 * -> Todo pedido anulado debe ser auditado, grabando en la tabla de log, la información del pedido anulado, indicando la fecha de anulación.
 * -> El sistema debe recomponer el stock de cada pedido confirmado que es anulado.
 * Entonces, cuando se anula un pedido (cambiando el estado a 'anulado'),
 * este trigger sobre la tabla Pedidos, en su acción acción AFTER UPDATE, realizará lo siguiente:
 * -> Registrar en LogAnulaciones la información del pedido anulado (incluida la fecha de anulación).
 * -> Reponer el stock de los productos involucrados (sumando las cantidades que se restaron previamente).
 */
DELIMITER $$
CREATE TRIGGER trg_after_update_anulado
AFTER UPDATE ON Pedidos
FOR EACH ROW
BEGIN
    IF NEW.Estado = 'anulado' AND OLD.Estado = 'confirmado' THEN
        -- Recomponer stock: sumar cantidades de cada detalle del pedido anulado
        UPDATE Productos p
        JOIN DetallePedidos d ON p.idproducto = d.idproducto
        SET p.Stock = p.Stock + d.cantidad
        WHERE d.NumeroPedido = NEW.NumeroPedido;
        
        -- Registrar en LogAnulaciones
        INSERT INTO LogAnulaciones (idLogAnulaciones, idpedido, FechaAnulacion, Observaciones)
        VALUES (UUID_TO_BIN(UUID()), NEW.idpedido, NOW(),
                CONCAT('Pedido ', NEW.NumeroPedido, ' anulado.'));
    END IF;
END;
$$
DELIMITER ;


/* Este triger, verifica que cuando se inserte un nuevo producto, el valor de Stock se encuentre el máximo y mínomo posible.
 * Atento a la regla de negocio que indica:
 * Al ingresar un nuevo producto, se debe controlar que el stock se encuentre entre los límites de stock mínimo y máximo.
 */
DELIMITER $$
CREATE TRIGGER trg_before_insert_productos
BEFORE INSERT ON Productos
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(512);

    IF NEW.Stock < NEW.StockMin OR NEW.Stock > NEW.StockMax THEN
        SET v_msg = CONCAT('El stock (', NEW.Stock, 
                           ') debe estar entre ', NEW.StockMin, 
                           ' y ', NEW.StockMax, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END;
$$
DELIMITER ;



/*
 * Sección 2: Conjunto de sentencias SQL para poblar la base de datos.
 */

-- Ingresar 5 clientes.
SET @uuid_cliente1 = UUID_TO_BIN(UUID());
SET @uuid_cliente2 = UUID_TO_BIN(UUID());
SET @uuid_cliente3 = UUID_TO_BIN(UUID());
SET @uuid_cliente4 = UUID_TO_BIN(UUID());
SET @uuid_cliente5 = UUID_TO_BIN(UUID());

INSERT INTO Clientes (idcliente, DNI, Apellido, Nombres, Direccion, mail)
VALUES
	(@uuid_cliente1, '18465781', 'Rojas Valdivia', 'Lucy Amanda', 'Av. Sabatini 3288', 'lucyamanda23@latinmail.com'),
	(@uuid_cliente2, '39512723', 'Alcaide', 'Santiago Agustín', 'Yrigoyen 733 5 C, La Plata, Buenos Aires', 'santialcaide@mineral.ru'),
	(@uuid_cliente3, '22101645', 'Roqué', 'Juan Manuel', 'Avellaneda 935, La Banda, Santiago del Estero', 'jmroque@yustech.com.ar'),
	(@uuid_cliente4, '42013728', 'Pérez', 'Carlos Enrique', 'Bedoya 724, Córdoba, Córdoba', 'carlitosperez@gmail.com'),
	(@uuid_cliente5, '12309421', 'Sánchez', 'Omar Wenceslao', 'Rivadavia, 724 3 C, Rosario, Santa Fe', 'wen733@mail.ru');


-- Ingresar 3 proveedores.
SET @uuid_proveedor1 = UUID_TO_BIN(UUID());
SET @uuid_proveedor2 = UUID_TO_BIN(UUID());
SET @uuid_proveedor3 = UUID_TO_BIN(UUID());

INSERT INTO Proveedores (idproveedor, NombreProveedor, Direccion, email)
VALUES
	(@uuid_proveedor1, 'Marolio', 'Corrientes 2350, Gral. Rodríguez, Buenos Aires', 'info@marolio.com.ar'),
	(@uuid_proveedor2, 'Arcor', 'Av. Chacabuco 1160, Córdoba, Córdoba', 'arcor@arcor.com'),
	(@uuid_proveedor3, 'Dos Hermanos', 'Av. Pres. Juan Domingo Perón y Scalabrini Ortiz, Concordia, Entre Ríos','info@doshermanos.com.ar');


-- Ingresar 3 vendedores.
SET @uuid_vendedor1 = UUID_TO_BIN(UUID());
SET @uuid_vendedor2 = UUID_TO_BIN(UUID());
SET @uuid_vendedor3 = UUID_TO_BIN(UUID());

INSERT INTO Vendedor (idvendedor, DNI, Apellido, Nombres, email, comision)
VALUES
	(@uuid_vendedor1, '36113214', 'Garay', 'Mauricio Elio', 'mgaray@msn.com', 10.15),
	(@uuid_vendedor2, '28101438', 'Cabral Perez', 'Matías', 'mcp@outlook.com', 23.2),
	(@uuid_vendedor3, '24741573', 'Castellanos', 'Matías','mcastellanos@gmail.com', 14.6);


-- Ingresar al menos 10 productos (distribuidos entre los 3 proveedores creados).
SET @uuid_prod01 = UUID_TO_BIN(UUID());
SET @uuid_prod02 = UUID_TO_BIN(UUID());
SET @uuid_prod03 = UUID_TO_BIN(UUID());
SET @uuid_prod04 = UUID_TO_BIN(UUID());
SET @uuid_prod05 = UUID_TO_BIN(UUID());
SET @uuid_prod06 = UUID_TO_BIN(UUID());
SET @uuid_prod07 = UUID_TO_BIN(UUID());
SET @uuid_prod08 = UUID_TO_BIN(UUID());
SET @uuid_prod09 = UUID_TO_BIN(UUID());
SET @uuid_prod10 = UUID_TO_BIN(UUID());

INSERT INTO Productos (idproducto, Descripcion, PrecioUnitario, Stock, StockMax, StockMin, idproveedor, origen)
VALUES
	(@uuid_prod01, 'Arroz Parboil 1kg Dos Hnos Libre Gluten Sin Tacc', 20865.0, 1518, 5000, 500, @uuid_proveedor3, 'nacional'),
	(@uuid_prod02, 'Huevo de pascuas Arcor Milk unicornio chocolate 140g', 18999.0, 12497, 15000, 0, @uuid_proveedor2, 'nacional'),
	(@uuid_prod03, 'Yerba Mate Marolio Con Menta - Bolsa 500g', 1487.5, 1213, 12000, 1050, @uuid_proveedor1, 'nacional'),
	(@uuid_prod04, 'Turron Arcor 25 Gramos Display De 50 Unidades', 11999.4, 870, 1942, 200, @uuid_proveedor2, 'nacional'),
	(@uuid_prod05, 'Arroz Yamani 500g Dos Hermanos Integral Sin Tacc Libre Gluten', 6017.0, 1803, 7500, 780, @uuid_proveedor3, 'importado'),
	(@uuid_prod06, 'Picadillo Marolio 90g', 1648.98, 680, 3800, 230, @uuid_proveedor1, 'nacional'),
	(@uuid_prod07, 'Mermelada Marolio Damasco Frasco 454 Gr', 2240.0, 213, 1300, 25, @uuid_proveedor1, 'nacional'),
	(@uuid_prod08, 'Mermelada Light De Ciruela Arcor X 390 Grs', 2559.0, 329, 1150, 20, @uuid_proveedor2, 'importado'),
	(@uuid_prod09, 'Bocadito Holanda Arcor X 24 Unidades', 9799.0, 871, 900, 50, @uuid_proveedor2, 'nacional'),
	(@uuid_prod10, 'Palmito Rodaja 800 Gramos Marolio', 7900.0, 852, 2500, 500, @uuid_proveedor1, 'importado');


-- Ingresar 10 pedidos en total con diferente cantidad de renglones (se sugiere crear pedidos con 1, 2 o 3 renglones máximo).
-- Generamos y almacenamos los UUID para los 10 pedidos solicitados
SET @uuid_pedido01 = UUID_TO_BIN(UUID());
SET @uuid_pedido02 = UUID_TO_BIN(UUID());
SET @uuid_pedido03 = UUID_TO_BIN(UUID());
SET @uuid_pedido04 = UUID_TO_BIN(UUID());
SET @uuid_pedido05 = UUID_TO_BIN(UUID());
SET @uuid_pedido06 = UUID_TO_BIN(UUID());
SET @uuid_pedido07 = UUID_TO_BIN(UUID());
SET @uuid_pedido08 = UUID_TO_BIN(UUID());
SET @uuid_pedido09 = UUID_TO_BIN(UUID());
SET @uuid_pedido10 = UUID_TO_BIN(UUID());

-- Genero pedidos (al hacer un INSERT MULTIROW, pierdo la posibilidad de usar LAST_INSERT_ID(); para la variable @numPedido, pero sigue siendo más legible y me resulta cómodo en gral)
INSERT INTO Pedidos (idpedido, idcliente, idvendedor, fecha, Estado)
VALUES
	(@uuid_pedido01, @uuid_cliente1, @uuid_vendedor1, '2025-02-23', 'confirmado'),
	(@uuid_pedido02, @uuid_cliente5, @uuid_vendedor2, '2025-03-14', 'confirmado'),
	(@uuid_pedido03, @uuid_cliente1, @uuid_vendedor1, '2025-04-04', 'pendiente'),
	(@uuid_pedido04, @uuid_cliente4, @uuid_vendedor2, '2025-01-28', 'confirmado'),
	(@uuid_pedido05, @uuid_cliente2, @uuid_vendedor3, '2025-04-11', 'confirmado'),
	(@uuid_pedido06, @uuid_cliente2, @uuid_vendedor3, '2025-02-18', 'pendiente'),
	(@uuid_pedido07, @uuid_cliente1, @uuid_vendedor3, '2025-01-08', 'confirmado'),
	(@uuid_pedido08, @uuid_cliente3, @uuid_vendedor2, '2025-03-05', 'confirmado'),
	(@uuid_pedido09, @uuid_cliente4, @uuid_vendedor2, '2025-04-10', 'pendiente'),
	(@uuid_pedido10, @uuid_cliente3, @uuid_vendedor2, '2025-03-21', 'confirmado');


-- Pedido 01 de 10 (3 renglones)
-- Nota, los números de pedido son autoincrementales (no se introducen manualmente),
-- asi que recupero el valor que necesito en cada caso, realizando una consulta (tengo/conozco el @uuid_pedidoNN)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido01;
-- Genero en cada caso los UUID para el detalle de pedido (y no antes todos juntos para no perderme)
SET @uuid_DP01r1 = UUID_TO_BIN(UUID()); -- Pedido 1 Renglón 1
SET @uuid_DP01r2 = UUID_TO_BIN(UUID()); -- Pedido 1 Renglón 2
SET @uuid_DP01r3 = UUID_TO_BIN(UUID()); -- Pedido 1 Renglón 3
INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES 
    (@uuid_DP01r1, @numPedido, 1, @uuid_prod01, 58),
    (@uuid_DP01r2, @numPedido, 2, @uuid_prod02, 32),
    (@uuid_DP01r3, @numPedido, 3, @uuid_prod03, 211);


-- Pedido 02 de 10 (1 renglón)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido02;
SET @uuid_DP02r1 = UUID_TO_BIN(UUID());
INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES (@uuid_DP02r1, @numPedido, 1, @uuid_prod05, 36);


-- Pedido 03 de 10 (2 renglones)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido03;
SET @uuid_DP03r1 = UUID_TO_BIN(UUID());
SET @uuid_DP03r2 = UUID_TO_BIN(UUID());
INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES 
    (@uuid_DP03r1, @numPedido, 1, @uuid_prod01, 9),
    (@uuid_DP03r2, @numPedido, 2, @uuid_prod04, 12);


-- Pedido 04 de 10 (3 renglones)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido04;
SET @uuid_DP04r1 = UUID_TO_BIN(UUID());
SET @uuid_DP04r2 = UUID_TO_BIN(UUID());
SET @uuid_DP04r3 = UUID_TO_BIN(UUID());

INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES 
    (@uuid_DP04r1, @numPedido, 1, @uuid_prod09, 15),
    (@uuid_DP04r2, @numPedido, 2, @uuid_prod06, 22),
    (@uuid_DP04r3, @numPedido, 3, @uuid_prod08, 10);


-- Pedido 05 de 10 (1 renglón)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido05;
SET @uuid_DP05r1 = UUID_TO_BIN(UUID());

INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES (@uuid_DP05r1, @numPedido, 1, @uuid_prod10, 14);


-- Pedido 06 de 10 (2 renglones)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido06;
SET @uuid_DP06r1 = UUID_TO_BIN(UUID());
SET @uuid_DP06r2 = UUID_TO_BIN(UUID());

INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES 
    (@uuid_DP06r1, @numPedido, 1, @uuid_prod04, 75),
    (@uuid_DP06r2, @numPedido, 2, @uuid_prod08, 23);


-- Pedido 07 de 10 (3 renglones)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido07;
SET @uuid_DP07r1 = UUID_TO_BIN(UUID());
SET @uuid_DP07r2 = UUID_TO_BIN(UUID());
SET @uuid_DP07r3 = UUID_TO_BIN(UUID());

INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES 
    (@uuid_DP07r1, @numPedido, 1, @uuid_prod07, 38),
    (@uuid_DP07r2, @numPedido, 2, @uuid_prod04, 52),
    (@uuid_DP07r3, @numPedido, 3, @uuid_prod01, 92);


-- Pedido 08 de 10 (2 renglones)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido08;
SET @uuid_DP08r1 = UUID_TO_BIN(UUID());
SET @uuid_DP08r2 = UUID_TO_BIN(UUID());

INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES 
    (@uuid_DP08r1, @numPedido, 1, @uuid_prod08, 108),
    (@uuid_DP08r2, @numPedido, 2, @uuid_prod06, 625);


-- Pedido 09 de 10 (1 renglón)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido09;
SET @uuid_DP09r1 = UUID_TO_BIN(UUID());

INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES (@uuid_DP09r1, @numPedido, 1, @uuid_prod02, 458);


-- Pedido 10 de 10 (3 renglones)
SELECT NumeroPedido INTO @numPedido FROM Pedidos WHERE idpedido = @uuid_pedido10;
SET @uuid_DP10r1 = UUID_TO_BIN(UUID());
SET @uuid_DP10r2 = UUID_TO_BIN(UUID());
SET @uuid_DP10r3 = UUID_TO_BIN(UUID());

INSERT INTO DetallePedidos (idDetallePedido, NumeroPedido, renglon, idproducto, cantidad)
VALUES 
    (@uuid_DP10r1, @numPedido, 1, @uuid_prod05, 15),
    (@uuid_DP10r2, @numPedido, 2, @uuid_prod03, 22),
    (@uuid_DP10r3, @numPedido, 3, @uuid_prod08, 210); -- Aquí podemos generar un error a propósito, si establecemos la cantidad (210) a >211



/*
 * Sección 3: Resolución de las consultas mediante las sentencias SQL.
 */

-- Detalle de clientes que realizaron pedidos entre fechas (apellido, nombres, DNI, correo electrónico).
SET @fecha_desde = '2025-04-01';
SET @fecha_hasta = '2025-04-30';
SELECT DISTINCT c.Apellido, c.Nombres, c.DNI, c.mail AS 'Email'
FROM Clientes c
INNER JOIN Pedidos p ON c.idcliente = p.idcliente
WHERE p.fecha BETWEEN @fecha_desde AND @fecha_hasta;


-- Detalle de vendedores con la cantidad de pedidos realizados (apellido, nombres, DNI, correo electrónico, CantidadPedidos).
SELECT v.Apellido, v.Nombres, v.DNI, v.email AS "Email", COUNT(p.idpedido) AS Cant_Pedidos
FROM Vendedor v
LEFT JOIN Pedidos p ON v.idvendedor = p.idvendedor
GROUP BY v.idvendedor, v.Apellido, v.Nombres, v.DNI, v.email;


-- Detalle de pedidos con un total mayor a un determinado valor umbral (NumeroPedido, fecha, TotalPedido).
SET @valorUmbral = 500000.00;
SELECT p.NumeroPedido, p.fecha AS Fecha, SUM(d.Total) AS TotalPedido
FROM Pedidos p
JOIN detallepedidos d ON p.NumeroPedido = d.NumeroPedido
GROUP BY p.NumeroPedido, p.fecha
HAVING TotalPedido > @valorUmbral;


-- Lista de productos vendidos entre fechas. (Descripción, CantidadTotal). CantidadTotal se calcula sumando todas las cantidades vendidas del producto.
SET @fecha_desde = '2025-04-01';
SET @fecha_hasta = '2025-04-30';
SELECT pr.Descripcion, SUM(dp.cantidad) AS CantidadTotal
FROM Pedidos pe
JOIN DetallePedidos dp ON pe.NumeroPedido = dp.NumeroPedido
JOIN Productos pr ON dp.idproducto = pr.idproducto
WHERE pe.fecha BETWEEN @fecha_desde AND @fecha_hasta
GROUP BY pr.Descripcion;

-- ¿Cuál es el proveedor que realizó más?
/* Esta pregunta no se entiende del todo... tal vez se refiere al proveedor del cual más productos se vendieron...
 * (por ejemplo, Si Arcor, Marolio, etc), o tal vez al proveedor del cual más productos compré / recibí.
 * Acordemos que es el proveedor más vendido.
 */
SELECT prov.NombreProveedor, SUM(dp.cantidad) AS TotalProductosVendidos
FROM Proveedores prov
JOIN Productos prod ON prov.idproveedor = prod.idproveedor
JOIN DetallePedidos dp 
  ON prod.idproducto = dp.idproducto
GROUP BY prov.idproveedor, prov.NombreProveedor
ORDER BY TotalProductosVendidos DESC
LIMIT 1;


-- Detalle de clientes registrados que nunca realizaron un pedido. (apellido, nombres, e-mail).
SELECT c.Apellido, c.Nombres, c.mail AS "Email"
FROM Clientes c
LEFT JOIN Pedidos p ON c.idcliente = p.idcliente
WHERE p.idcliente IS NULL;


-- Detalle de clientes que realizaron menos de dos pedidos. (apellido, nombres, e-mail).
SET @cantPedidos = 2;
SELECT c.Apellido, c.Nombres, c.mail AS "Email"
FROM Clientes c
LEFT JOIN Pedidos p ON c.idcliente = p.idcliente
GROUP BY c.idcliente, c.Apellido, c.Nombres, c.mail
HAVING COUNT(p.idpedido) < @cantPedidos;


-- Cantidad total vendida por origen de producto.
SELECT p.origen AS "Origen", SUM(d.cantidad) AS "CantidadTotalVendida"
FROM Productos p
JOIN DetallePedidos d ON p.idproducto = d.idproducto
GROUP BY p.origen;


