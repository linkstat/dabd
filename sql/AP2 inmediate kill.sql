

/* Para poder hacerun DROP USER ESQUEMA, primero hay que asegurarse de que no
 * haya sesiones activas. Oracle no permite borrar un usuario que está conectado.
 * Entonces, una forma automatizada de buscar lac onexiones activas y matarlas:
 */
 BEGIN
  FOR r IN (
    SELECT sid, serial#
      FROM v$session
     WHERE username = 'PEDIDOS'
  ) LOOP
    EXECUTE IMMEDIATE 
      'ALTER SYSTEM KILL SESSION '''||r.sid||','||r.serial#||''' IMMEDIATE';
  END LOOP;
END;
/
