/* TRABAJO PRÁCTICO 1
 *
 * Alumno: HAMANN, PABLO ALEJANDRO
 * Legajo: VINF010782
 * Año: 2025
 * Prof. Titular Disciplinar: CASTELLI, SILVIA LAURA LANZA
 * Prof. Titular Experto: DAUBROWSKY, RICARDO RAMÓN
 * 
 * Software utilizado para el desarrollo del presente TP:
 * Motor de BD: MariaDB 11.4.3
 * Clientes SQL: HeidiSQL 12.6.0, Navicat Premium 17.0.8, MySQL Workbench 8.0 CE
 * Otros: Git Bash
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
 * GitHub:  https://github.com/linkstat/dabd
 *
 */


/*
 * TAREAS INICIALES
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



-- Creación de claves foráneas con nombres coherentes

ALTER TABLE `CONTRIBUYENTES_DOMICILIOS`
  ADD CONSTRAINT `FK_CONTRIBUYENTES_DOMICILIOS_CONTRIBUYENTES`
  FOREIGN KEY (`ID_CON`) REFERENCES `CONTRIBUYENTES` (`ID`);

ALTER TABLE `CONTRIBUYENTES_DOMICILIOS`
  ADD CONSTRAINT `FK_CONTRIBUYENTES_DOMICILIOS_DOMICILIOS`
  FOREIGN KEY (`ID_DOM`) REFERENCES `DOMICILIOS` (`ID`);

ALTER TABLE `CONTRIBUYENTES_DOMICILIOS`
  ADD CONSTRAINT `FK_CONTRIBUYENTES_DOMICILIOS_DOMICILIOS_TIPO`
  FOREIGN KEY (`ID_TIP`) REFERENCES `DOMICILIOS_TIPO` (`ID`);

ALTER TABLE `CUOTAS`
  ADD CONSTRAINT `FK_CUOTAS_INMUEBLES`
  FOREIGN KEY (`NUM_CATASTRAL`) REFERENCES `INMUEBLES` (`NUM_CATASTRAL`);

ALTER TABLE `DOMICILIOS`
  ADD CONSTRAINT `FK_DOMICILIOS_LOCALIDADES`
  FOREIGN KEY (`ID_LOC`) REFERENCES `LOCALIDADES` (`ID`);

ALTER TABLE `INMUEBLES`
  ADD CONSTRAINT `FK_INMUEBLES_CONTRIBUYENTES`
  FOREIGN KEY (`ID_CON`) REFERENCES `CONTRIBUYENTES` (`ID`);

ALTER TABLE `INMUEBLES`
  ADD CONSTRAINT `FK_INMUEBLES_DOMICILIOS`
  FOREIGN KEY (`ID_DOM`) REFERENCES `DOMICILIOS` (`ID`);

ALTER TABLE `INMUEBLES`
  ADD CONSTRAINT `FK_INMUEBLES_ZONAS`
  FOREIGN KEY (`ID_ZON`) REFERENCES `ZONAS` (`ID`);

ALTER TABLE `INMUEBLES`
  ADD CONSTRAINT `FK_INMUEBLES_TIPOS_INMUEBLES`
  FOREIGN KEY (`ID_TIPO`) REFERENCES `TIPOS_INMUEBLES` (`ID`);

ALTER TABLE `LOCALIDADES`
  ADD CONSTRAINT `FK_LOCALIDADES_PROVINCIAS`
  FOREIGN KEY (`ID_PRO`) REFERENCES `PROVINCIAS` (`ID`);

ALTER TABLE `PROVINCIAS`
  ADD CONSTRAINT `FK_PROVINCIAS_PAISES`
  FOREIGN KEY (`ID_PAI`) REFERENCES `PAISES` (`ID`);

-- Rehabilitar las Restricciones de Claves Foráneas
SET FOREIGN_KEY_CHECKS = 1;



-- CONSIGNAS
/*
 * Una vez leído el caso planteado y teniendo en cuenta el diagrama que se te ofrece como ejemplo, será tu tarea para esta actividad realizar las siguientes consignas:
 * 
 * 1. Inserte al menos los datos de cinco contribuyentes.
 * 2. Inserte los tipos de domicilios, tipos de inmuebles, zonas, países, provincias y localidades que le serán de utilidad para el resto de las inserciones.
      Independientemente de cada país, las zonas son; Este, Oeste, Norte y Sur.
		Los tipos de inmuebles son; casa, departamento, lote, galpón.
 * 3. Asigne a cada uno de los contribuyentes un domicilio del tipo particular.
      Dos de los domicilios particulares deben ser de alguna localidad de Córdoba,
		dos de alguna localidad de Santa Fe y
		el resto de Buenos Aires.
 * 4. Al menos a tres de los contribuyentes asígnele un domicilio de cobro. 
 * 5. Asigne a cada uno de los contribuyentes al menos un inmueble.
      Al menos un contribuyente debe tener más de un tipo de inmueble.
 * 6. Genere las cuotas de cada mes del corriente año para cada uno de los inmuebles cargados en la base de datos.
 * 7. Emita un informe que muestre apellido y nombre de cada uno de los contribuyentes con su respectivo inmueble y
      el costo y vencimiento de cada una de las cuotas del año.
 */


-- DESARROLLO

/*  
 * PUNTO 1: Inserción de datos de contribuyentes
 */
  
-- Dado que utilizo UUIDs, voy a almacenarlos en variables para facilitarme las inserciones posteriores.
SET @uuid_con1 = UUID();
SET @uuid_con2 = UUID();
SET @uuid_con3 = UUID();
SET @uuid_con4 = UUID();
SET @uuid_con5 = UUID();
SET @uuid_con6 = UUID();
SET @uuid_con7 = UUID();

INSERT INTO CONTRIBUYENTES (ID, APELLIDOS, NOMBRES)
VALUES
	(UUID_TO_BIN(@uuid_con1), 'Rojas Valdivia', 'Lucy Amanda'),
	(UUID_TO_BIN(@uuid_con2), 'Alcaide', 'Santiago Agustín'),
	(UUID_TO_BIN(@uuid_con3), 'Roqué', 'Juan Manuel'),
	(UUID_TO_BIN(@uuid_con4), 'Canga Castellanos', 'Matías Enrique'),
	(UUID_TO_BIN(@uuid_con5), 'Garay', 'Mauricio Elio'),
	(UUID_TO_BIN(@uuid_con6), 'Cabral Perez', 'Matías'),	
	(UUID_TO_BIN(@uuid_con7), 'Sánchez', 'Omar Wenceslao');


/*  
 * PUNTO 2. Inserción de tipos de domicilios, tipos de inmuebles, zonas, países, provincias y localidades
 */

-- Inserción de tipos de domicilio (deducidos desde la descripcion del PDF de la AP1)
SET @uuid_td_particular = UUID();
SET @uuid_td_decobro = UUID();

INSERT INTO DOMICILIOS_TIPO (ID, DESCRIPCION)
VALUES 
  (UUID_TO_BIN(@uuid_td_particular), 'particular'),
  (UUID_TO_BIN(@uuid_td_decobro), 'de cobro');

-- Inserción de tipos de inmuebles
INSERT INTO TIPOS_INMUEBLES (ID, DESCRIPCION)
VALUES 
  (UUID_TO_BIN(UUID()), 'casa'),
  (UUID_TO_BIN(UUID()), 'departamento'),
  (UUID_TO_BIN(UUID()), 'lote'),
  (UUID_TO_BIN(UUID()), 'galpón');

-- Inserción de zonas
INSERT INTO ZONAS (ID, DESCRIPCION)
VALUES 
  (UUID_TO_BIN(UUID()), 'Este'),
  (UUID_TO_BIN(UUID()), 'Oeste'),
  (UUID_TO_BIN(UUID()), 'Norte'),
  (UUID_TO_BIN(UUID()), 'Sur');

-- Inserción de países
SET @uuid_ar = UUID();
SET @uuid_br = UUID();
SET @uuid_py = UUID();
SET @uuid_uy = UUID();

INSERT INTO PAISES (ID, DESCRIPCION)
VALUES 
  (UUID_TO_BIN(@uuid_ar), 'Argentina'),
  (UUID_TO_BIN(@uuid_br), 'Brasil'),
  (UUID_TO_BIN(@uuid_py), 'Paraguay'),
  (UUID_TO_BIN(@uuid_uy), 'Uruguay');

-- Inserción de provincias
SET @uuid_ar_bsas = UUID();
SET @uuid_ar_caba = UUID();
SET @uuid_ar_cba = UUID();
SET @uuid_ar_sf = UUID();
SET @uuid_ar_tuc = UUID();
SET @uuid_br_mg = UUID();
SET @uuid_br_rdj = UUID();
SET @uuid_br_sp = UUID();
SET @uuid_py_as = UUID();
SET @uuid_py_it = UUID();
SET @uuid_uy_mv = UUID();
SET @uuid_uy_md = UUID();
INSERT INTO PROVINCIAS (ID, DESCRIPCION, ID_PAI)
VALUES 
  (UUID_TO_BIN(@uuid_ar_bsas), 'Buenos Aires', UUID_TO_BIN(@uuid_ar)),
  (UUID_TO_BIN(@uuid_ar_caba), 'CABA', UUID_TO_BIN(@uuid_ar)),
  (UUID_TO_BIN(@uuid_ar_cba), 'Córdoba', UUID_TO_BIN(@uuid_ar)),
  (UUID_TO_BIN(@uuid_ar_sf), 'Santa Fe', UUID_TO_BIN(@uuid_ar)),
  (UUID_TO_BIN(@uuid_ar_tuc), 'Tucumán', UUID_TO_BIN(@uuid_ar)),
  (UUID_TO_BIN(@uuid_br_mg), 'Minas Gerais', UUID_TO_BIN(@uuid_br)),
  (UUID_TO_BIN(@uuid_br_rdj), 'Rio de Janeiro', UUID_TO_BIN(@uuid_br)),
  (UUID_TO_BIN(@uuid_br_sp), 'São Paulo', UUID_TO_BIN(@uuid_br)),
  (UUID_TO_BIN(@uuid_py_as), 'Asunción', UUID_TO_BIN(@uuid_py)),
  (UUID_TO_BIN(@uuid_py_it), 'Itapúa', UUID_TO_BIN(@uuid_py)),
  (UUID_TO_BIN(@uuid_uy_mv), 'Montevideo', UUID_TO_BIN(@uuid_uy)),
  (UUID_TO_BIN(@uuid_uy_md), 'Maldonado', UUID_TO_BIN(@uuid_uy));

-- Inserción de localidades
INSERT INTO LOCALIDADES (ID, DESCRIPCION, CODIGO_POSTAL, ID_PRO)
VALUES 
  (UUID_TO_BIN(UUID()), 'CABA', '1000', UUID_TO_BIN(@uuid_ar_caba)),
  (UUID_TO_BIN(UUID()), 'La Plata', '1900', UUID_TO_BIN(@uuid_ar_bsas)),
  (UUID_TO_BIN(UUID()), 'Zárate', '2800', UUID_TO_BIN(@uuid_ar_bsas)),
  (UUID_TO_BIN(UUID()), 'Bahía Blanca', '8000', UUID_TO_BIN(@uuid_ar_bsas)),
  (UUID_TO_BIN(UUID()), 'Córdoba', '5000', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Villa Allende', '5105', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Malagueño', '5101', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Mendiolaza', '5107', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Villa Carlos Paz', '5152', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Cosquín', '5166', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Alta Gracia', '5186', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Deán Funes', '5200', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Jesús María', '5220', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Oncativo', '5986', UUID_TO_BIN(@uuid_ar_cba)),
  (UUID_TO_BIN(UUID()), 'Rosario', '2000', UUID_TO_BIN(@uuid_ar_sf)),
  (UUID_TO_BIN(UUID()), 'Rafaela', '2300', UUID_TO_BIN(@uuid_ar_sf)),
  (UUID_TO_BIN(UUID()), 'Venado Tuerto', '2600', UUID_TO_BIN(@uuid_ar_sf)),
  (UUID_TO_BIN(UUID()), 'Santa Fe', '3000', UUID_TO_BIN(@uuid_ar_sf)),
  (UUID_TO_BIN(UUID()), 'San Miguel de Tucumán', '4000', UUID_TO_BIN(@uuid_ar_tuc)),
  (UUID_TO_BIN(UUID()), 'Tafí del Valle', '4137', UUID_TO_BIN(@uuid_ar_tuc)),
  (UUID_TO_BIN(UUID()), 'São Paulo', '01000-000', UUID_TO_BIN(@uuid_br_sp)),
  (UUID_TO_BIN(UUID()), 'Rio de Janeiro', '22050-000', UUID_TO_BIN(@uuid_br_rdj)),
  (UUID_TO_BIN(UUID()), 'Sete Lagoas', '35701-000', UUID_TO_BIN(@uuid_br_mg)),
  (UUID_TO_BIN(UUID()), 'Minas Gerais', '38778-000', UUID_TO_BIN(@uuid_br_mg)),
  (UUID_TO_BIN(UUID()), 'Asunción', '001518', UUID_TO_BIN(@uuid_py_as)),
  (UUID_TO_BIN(UUID()), 'Encarnación', '070121', UUID_TO_BIN(@uuid_py_it)),
  (UUID_TO_BIN(UUID()), 'Montevideo', '11000', UUID_TO_BIN(@uuid_uy_mv)),
  (UUID_TO_BIN(UUID()), 'Punta del Este', '20100', UUID_TO_BIN(@uuid_uy_md));


/*
 * PUNTO 3: Asignación de domicilios particulares a cada uno de los contribuyentes
 * dos de los domicilios particulares deben ser de alguna localidad de Córdoba,
 * dos de alguna localidad de Santa Fe y el resto de Buenos Aires.
 */

-- Asignar domicilio a contribuyente 1 (Rojas Validiva) en alguna localidad de Córdoba
SET @uuid_dom1 = UUID();

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES (
  UUID_TO_BIN(@uuid_dom1),
  'Libertad',
  881,
  NULL,
  NULL,
  (
    SELECT ID 
    FROM LOCALIDADES 
    WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Córdoba' LIMIT 1)
    ORDER BY RAND() 
    LIMIT 1
  )
);

INSERT INTO CONTRIBUYENTES_DOMICILIOS (ID_CON, ID_DOM, ID_TIP)
VALUES (
  UUID_TO_BIN(@uuid_con1),
  UUID_TO_BIN(@uuid_dom1),
  UUID_TO_BIN(@uuid_td_particular)
);


-- Asignar domicilio a contribuyente 2 (Alcaide) en alguna localidad de Córdoba
SET @uuid_dom2 = UUID();

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES (
  UUID_TO_BIN(@uuid_dom2),
  'Independencia', '347', '3', 'C',
  (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Córdoba' LIMIT 1) ORDER BY RAND() LIMIT 1)
);

INSERT INTO CONTRIBUYENTES_DOMICILIOS (ID_CON, ID_DOM, ID_TIP)
VALUES (
  UUID_TO_BIN(@uuid_con2),
  UUID_TO_BIN(@uuid_dom2), UUID_TO_BIN(@uuid_td_particular)
);


-- Asignar domicilio a contribuyente 3 (Roqué) en alguna localidad de Santa Fe
SET @uuid_dom3 = UUID();

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES (
  UUID_TO_BIN(@uuid_dom3),
  'Saavedra', '1185', '1', NULL,
  (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Santa Fe' LIMIT 1) ORDER BY RAND() LIMIT 1)
);

INSERT INTO CONTRIBUYENTES_DOMICILIOS (ID_CON, ID_DOM, ID_TIP)
VALUES (
  UUID_TO_BIN(@uuid_con3),
  UUID_TO_BIN(@uuid_dom3), UUID_TO_BIN(@uuid_td_particular)
);


-- Asignar domicilio a contribuyente 4 (Canga Castellanos) en alguna localidad de Santa Fe
SET @uuid_dom4 = UUID();

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES (
  UUID_TO_BIN(@uuid_dom4),
  'Mate de Luna', '153', NULL, NULL,
  (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Santa Fe' LIMIT 1) ORDER BY RAND() LIMIT 1)
);

INSERT INTO CONTRIBUYENTES_DOMICILIOS (ID_CON, ID_DOM, ID_TIP)
VALUES (
  UUID_TO_BIN(@uuid_con4),
  UUID_TO_BIN(@uuid_dom4), UUID_TO_BIN(@uuid_td_particular)
);


-- Asignar domicilios al resto de los contribuyentes en alguna localidad de Buenos Aires
SET @uuid_dom5 = UUID();
SET @uuid_dom6 = UUID();
SET @uuid_dom7 = UUID();

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES (
  UUID_TO_BIN(@uuid_dom5),
  'Belgrano', '556', '3', 'C',
  (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Buenos Aires' LIMIT 1) ORDER BY RAND() LIMIT 1)
);

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES (
  UUID_TO_BIN(@uuid_dom6),
  'Congreso', '1258', NULL, NULL,
  (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Buenos Aires' LIMIT 1) ORDER BY RAND() LIMIT 1)
);

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES (
  UUID_TO_BIN(@uuid_dom7),
  'Defensa', '3188', NULL, 'F',
  (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Buenos Aires' LIMIT 1) ORDER BY RAND() LIMIT 1)
);

INSERT INTO CONTRIBUYENTES_DOMICILIOS (ID_CON, ID_DOM, ID_TIP)
VALUES
  (UUID_TO_BIN(@uuid_con5), UUID_TO_BIN(@uuid_dom5), UUID_TO_BIN(@uuid_td_particular)),
  (UUID_TO_BIN(@uuid_con6), UUID_TO_BIN(@uuid_dom6), UUID_TO_BIN(@uuid_td_particular)),
  (UUID_TO_BIN(@uuid_con7), UUID_TO_BIN(@uuid_dom7), UUID_TO_BIN(@uuid_td_particular));


/*
 * PUNTO 4: Asignación de domicilios de cobro, al menos a tres de los contribuyentes
 */

-- Asignación de domicilios de cobro a contribuyentes 5, 6 y 7
SET @uuid_dom_dc5 = UUID();
SET @uuid_dom_dc6 = UUID();
SET @uuid_dom_dc7 = UUID();

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES
  (UUID_TO_BIN(@uuid_dom_dc5), 'San Martín', 15, NULL, 'C', (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Córdoba' LIMIT 1) ORDER BY RAND() LIMIT 1)),
  (UUID_TO_BIN(@uuid_dom_dc6), 'Colón', 3201, '4', 'A', (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Córdoba' LIMIT 1) ORDER BY RAND() LIMIT 1)),
  (UUID_TO_BIN(@uuid_dom_dc7), '9 de julio', 788, NULL, NULL, (SELECT ID FROM LOCALIDADES WHERE ID_PRO = (SELECT ID FROM PROVINCIAS WHERE DESCRIPCION = 'Córdoba' LIMIT 1) ORDER BY RAND() LIMIT 1));

INSERT INTO CONTRIBUYENTES_DOMICILIOS (ID_CON, ID_DOM, ID_TIP)
VALUES
  (UUID_TO_BIN(@uuid_con5), UUID_TO_BIN(@uuid_dom_dc5), UUID_TO_BIN(@uuid_td_decobro)),
  (UUID_TO_BIN(@uuid_con6), UUID_TO_BIN(@uuid_dom_dc6), UUID_TO_BIN(@uuid_td_decobro)),
  (UUID_TO_BIN(@uuid_con7), UUID_TO_BIN(@uuid_dom_dc7), UUID_TO_BIN(@uuid_td_decobro));


/*
 * PUNTO 5: Asigne a cada uno de los contribuyentes al menos un inmueble.
 *          Al menos un contribuyente debe tener más de un tipo de inmueble.
 */

-- Contribuyente 1: Rojas Valdivia
SET @domInmueble1 = UUID();
SET @domInmueble2 = UUID();
SET @domInmueble3 = UUID();
SET @domInmueble4 = UUID();
SET @domInmueble5 = UUID();
SET @domInmueble6 = UUID();

INSERT INTO DOMICILIOS (ID, CALLE, NUMERO, PISO, DEPARTAMENTO, ID_LOC)
VALUES
  (UUID_TO_BIN(@domInmueble1), 'Sabatini', 3288, NULL, NULL, (SELECT ID FROM LOCALIDADES ORDER BY RAND() LIMIT 1)),
  (UUID_TO_BIN(@domInmueble2), 'Yrigoyen', 733, '5', 'C', (SELECT ID FROM LOCALIDADES ORDER BY RAND() LIMIT 1)),
  (UUID_TO_BIN(@domInmueble3), 'Maipú', 804, '1', NULL, (SELECT ID FROM LOCALIDADES ORDER BY RAND() LIMIT 1)),
  (UUID_TO_BIN(@domInmueble4), 'Avellaneda', 9352, NULL, NULL, (SELECT ID FROM LOCALIDADES ORDER BY RAND() LIMIT 1)),
  (UUID_TO_BIN(@domInmueble5), 'Pellegrini', 618, NULL, 'B', (SELECT ID FROM LOCALIDADES ORDER BY RAND() LIMIT 1)),
  (UUID_TO_BIN(@domInmueble6), 'Bedoya', 724, '3', 'C', (SELECT ID FROM LOCALIDADES ORDER BY RAND() LIMIT 1));

INSERT INTO INMUEBLES (NUM_CATASTRAL, ID_CON, ID_DOM, ID_ZON, ID_TIPO)
VALUES 
  ('CAT1-101-99-15-03', UUID_TO_BIN(@uuid_con1), UUID_TO_BIN(@domInmueble1), (SELECT ID FROM ZONAS WHERE DESCRIPCION = 'Norte' LIMIT 1),
    (SELECT ID FROM TIPOS_INMUEBLES WHERE DESCRIPCION = 'casa' LIMIT 1)),
  ('CAT2-201-78-66-34', UUID_TO_BIN(@uuid_con1), UUID_TO_BIN(@domInmueble2), (SELECT ID FROM ZONAS WHERE DESCRIPCION = 'Oeste' LIMIT 1),
    (SELECT ID FROM TIPOS_INMUEBLES WHERE DESCRIPCION = 'lote' LIMIT 1)),
  ('CATG-30-76-00-00-22', UUID_TO_BIN(@uuid_con2), UUID_TO_BIN(@domInmueble3), (SELECT ID FROM ZONAS WHERE DESCRIPCION = 'Sur' LIMIT 1),
    (SELECT ID FROM TIPOS_INMUEBLES ORDER BY RAND() LIMIT 1)),
  ('000-99-10-000-32-81', UUID_TO_BIN(@uuid_con3), UUID_TO_BIN(@domInmueble4), (SELECT ID FROM ZONAS WHERE DESCRIPCION = 'Este' LIMIT 1),
    (SELECT ID FROM TIPOS_INMUEBLES ORDER BY RAND() LIMIT 1)),
  ('8-AC-23000-3F', UUID_TO_BIN(@uuid_con4), UUID_TO_BIN(@domInmueble5), (SELECT ID FROM ZONAS ORDER BY RAND() LIMIT 1), (SELECT ID FROM TIPOS_INMUEBLES ORDER BY RAND() LIMIT 1)),
  ('300-1230-ACX-F02222-33', UUID_TO_BIN(@uuid_con4), UUID_TO_BIN(@domInmueble6), (SELECT ID FROM ZONAS ORDER BY RAND() LIMIT 1), (SELECT ID FROM TIPOS_INMUEBLES ORDER BY RAND() LIMIT 1));



/*
 * PUNTO 6: Genere las cuotas de cada mes del corriente año para cada uno de los inmuebles cargados en la base de datos
 */
INSERT INTO CUOTAS (NUM_CATASTRAL, ANIO, NUM_CUOTA, VALOR, FECHA_VENCIMIENTO, COBRADA)
VALUES
  ('CAT1-101-99-15-03', YEAR(CURDATE()), 1, 1000.00, CONCAT(YEAR(CURDATE()), "-", LPAD(MONTH(CURDATE()),2,'0'), "-15"), false),
  ('CAT2-201-78-66-34', YEAR(CURDATE()), 1, 1000.00, CONCAT(YEAR(CURDATE()), "-", LPAD(MONTH(CURDATE()),2,'0'), "-15"), false);



/*
 * PUNTO 7: Emita un informe que muestre apellido y nombre de cada uno de los contribuyentes 
 *          con su respectivo inmueble y el costo y vencimiento de cada una de las cuotas del año.
 */



