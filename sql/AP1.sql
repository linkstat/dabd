/* Recreación del modelo presentado.
 * Se utilizó MariaDB 11.1
 * Se decidió utilizar UUID almacenado como BINARIO para los IDs.
*/


/*
 * TAREAS INICIALES
*/

-- Borrado total de las tablas de la BD
USE ap_dabd;

-- Borrado de las funciones personalizadas
DROP FUNCTION IF EXISTS UUID_TO_BIN;
DROP FUNCTION IF EXISTS BIN_TO_UUID;

-- Desactiva la verificación de claves foráneas
SET FOREIGN_KEY_CHECKS = 0;

-- Inicializar la variable de tablas como NULL
SET @tables = NULL;

-- Obtiene la lista de todas las tablas
SELECT GROUP_CONCAT('`', table_name, '`') INTO @tables
FROM information_schema.tables
WHERE table_schema = (SELECT DATABASE());

-- Si existen tablas, ejecuta el DROP
SET @tables = CONCAT('DROP TABLE IF EXISTS ', @tables);
PREPARE stmt FROM @tables;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

 -- Vuelve a activar la verificación de claves foráneas
SET FOREIGN_KEY_CHECKS = 1;



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

CREATE TABLE `CONTRIBUYENTES`  (
  `ID` binary(16) NOT NULL,
  `APELLIDOS` varchar(255) NULL,
  `NOMBRES` varchar(255) NULL,
  PRIMARY KEY (`ID`)
);

CREATE TABLE `CONTRIBUYENTES_DOMICILIOS`  (
  `ID_CON` binary(16) NOT NULL,
  `ID_DOM` binary(16) NOT NULL,
  `ID_TIP` binary(16) NOT NULL,
  PRIMARY KEY (`ID_CON`, `ID_DOM`, `ID_TIP`)
);

CREATE TABLE `CUOTAS`  (
  `NUM_CATASTRAL` varchar(40) NOT NULL,
  `ANIO` int(4) NOT NULL,
  `NUM_CUOTA` int(20) NOT NULL,
  `VALOR` double NULL,
  `FECHA_VENCIMIENTO` date NULL,
  `FECHA_COBRO` date NULL,
  `COBRADA` boolean,
  PRIMARY KEY (`NUM_CATASTRAL`, `ANIO`, `NUM_CUOTA`)
);

CREATE TABLE `DOMICILIOS`  (
  `ID` binary(16) NOT NULL,
  `CALLE` varchar(255) NULL,
  `NUMERO` SMALLINT UNSIGNED NULL,
  `PISO` tinytext NULL,
  `DEPARTAMENTO` tinytext NULL,
  `ID_LOC` binary(16) NULL,
  PRIMARY KEY (`ID`)
);

CREATE TABLE `DOMICILIOS_TIPO`  (
  `ID` binary(16) NOT NULL,
  `DESCRIPCION` varchar(255) NULL,
  PRIMARY KEY (`ID`)
);

CREATE TABLE `INMUEBLES`  (
  `NUM_CATASTRAL` varchar(40) NOT NULL,
  `ID_CON` binary(16) NULL,
  `ID_DOM` binary(16) NULL,
  `ID_ZON` binary(16) NULL,
  `ID_TIPO` binary(16) NULL,
  PRIMARY KEY (`NUM_CATASTRAL`)
);

CREATE TABLE `LOCALIDADES`  (
  `ID` binary(16) NOT NULL,
  `DESCRIPCION` varchar(255) NULL,
  `CODIGO_POSTAL` VARCHAR(18) NULL,
  `ID_PRO` binary(16) NULL,
  PRIMARY KEY (`ID`)
);

CREATE TABLE `PAISES`  (
  `ID` binary(16) NOT NULL,
  `DESCRIPCION` varchar(255) NULL,
  PRIMARY KEY (`ID`)
);

CREATE TABLE `PROVINCIAS`  (
  `ID` binary(16) NOT NULL,
  `DESCRIPCION` varchar(255) NULL,
  `ID_PAI` binary(16) NULL,
  PRIMARY KEY (`ID`)
);

CREATE TABLE `TIPOS_INMUEBLES`  (
  `ID` binary(16) NOT NULL,
  `DESCRIPCION` varchar(255) NULL,
  PRIMARY KEY (`ID`)
);

CREATE TABLE `ZONAS`  (
  `ID` binary(16) NOT NULL,
  `DESCRIPCION` varchar(255) NULL,
  PRIMARY KEY (`ID`)
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



