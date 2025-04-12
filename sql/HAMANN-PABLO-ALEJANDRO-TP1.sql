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
 * Este archivo:  https://github.com/linkstat/dabd/blob/main/sql/HAMANN-PABLO-ALEJANDRO-TP1.sql
 *
 */



/*
 * Sección 0: Tareas previas a la creación de la estructura de la base de datos.
 */

-- Definición del nombre de la BD vía una variable (apra evitar errores de tipeo, defino una sola vez, y utilizo luego la variable)
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
    CONSTRAINT chk_stock_limits CHECK (Stock >= StockMin AND Stock <= StockMax),
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (idproveedor) REFERENCES Proveedores(idproveedor)
);

/* Aquí me tomé la libertad de modificar levemente la propuesta dada.
 * Por un lado, tengo que conservar el concepto de nro de pedido (para la presentación de datos, por ejemplo),
 * y por otra parte, quiero mantener consistencia interna al usar UUID binario para las PK.
 */
CREATE TABLE Pedidos (
    idpedido BINARY(16) NOT NULL PRIMARY KEY,
    NumeroPedido INT NOT NULL UNIQUE,
    idcliente BINARY(16) NOT NULL,
    idvendedor BINARY(16) NOT NULL,
    fecha DATE NOT NULL,
    Estado ENUM('pendiente', 'confirmado', 'anulado') NOT NULL DEFAULT 'pendiente',
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (idcliente) REFERENCES Clientes(idcliente)
        ON DELETE RESTRICT,
    CONSTRAINT fk_pedido_vendedor FOREIGN KEY (idvendedor) REFERENCES Vendedor(idvendedor)
);

-- Misma lógica de 'modificación sutil' que poara la tabla anterior
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

/* Esta tabla no se explicita en la actividad propueta, pero sin embargo, la penúltima regla dice:
 * Todo pedido anulado debe ser auditado, grabando en la tabla de log, la información
 * del pedido anulado, indicando la fecha de anulación.
 */
CREATE TABLE LogAnulaciones (
    idLogAnulaciones BINARY(16) NOT NULL PRIMARY KEY,
    idpedido BINARY(16) NOT NULL,  -- referencia a la PK de la tabla Pedidos
    FechaAnulacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Observaciones TEXT,
    CONSTRAINT fk_log_idpedido FOREIGN KEY (idpedido) REFERENCES Pedidos(idpedido)
);


-- Rehabilitar las Restricciones de Claves Foráneas
SET FOREIGN_KEY_CHECKS = 1;



/*
 * Sección 2: Conjunto de sentencias SQL para poblar la base de datos.
 */

-- Ingresar 5 clientes.
SET @uuid_cliente1 = UUID_TO_BIN(UUID());
SET @uuid_cliente2 = UUID_TO_BIN(UUID());
SET @uuid_cliente3 = UUID_TO_BIN(UUID());
SET @uuid_cliente4 = UUID_TO_BIN(UUID());
SET @uuid_cliente5 = UUID_TO_BIN(UUID());

INSERT INTO Clientes (idcliente, Apellido, Nombres, Direccion, mail)
VALUES
	(@uuid_cliente1, 'Rojas Valdivia', 'Lucy Amanda', 'Av. Sabatini 3288', 'lucyamanda23@latinmail.com'),
	(@uuid_cliente2, 'Alcaide', 'Santiago Agustín', 'Yrigoyen 733 5 C, La Plata, Buenos Aires', 'santialcaide@mineral.ru'),
	(@uuid_cliente3, 'Roqué', 'Juan Manuel', 'Avellaneda 935, La Banda, Santiago del Estero', 'jmroque@yustech.com.ar'),
	(@uuid_cliente4, 'Pérez', 'Carlos Enrique', 'Bedoya 724, Córdoba, Córdoba', 'carlitosperez@gmail.com'),
	(@uuid_cliente5, 'Sánchez', 'Omar Wenceslao', 'Rivadavia, 724 3 C, Rosario, Santa Fe', 'wen733@mail.ru');


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

INSERT INTO Vendedor (idvendedor, Apellido, Nombres, email, comision)
VALUES
	(@uuid_vendedor1, 'Garay', 'Mauricio Elio', 'mgaray@msn.com', 10.15),
	(@uuid_vendedor2, 'Cabral Perez', 'Matías', 'mcp@outlook.com', 23.2),
	(@uuid_vendedor3, 'Castellanos', 'Matías','mcastellanos@gmail.com', 14.6);


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



