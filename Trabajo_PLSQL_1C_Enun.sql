DROP TABLE detalle_pedido CASCADE CONSTRAINTS;
DROP TABLE pedidos CASCADE CONSTRAINTS;
DROP TABLE platos CASCADE CONSTRAINTS;
DROP TABLE personal_servicio CASCADE CONSTRAINTS;
DROP TABLE clientes CASCADE CONSTRAINTS;

DROP SEQUENCE seq_pedidos;


-- Creación de tablas y secuencias



create sequence seq_pedidos;

CREATE TABLE clientes (
    id_cliente INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    telefono VARCHAR2(20)
);

CREATE TABLE personal_servicio (
    id_personal INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    apellido VARCHAR2(100) NOT NULL,
    pedidos_activos INTEGER DEFAULT 0 CHECK (pedidos_activos <= 5)
);

CREATE TABLE platos (
    id_plato INTEGER PRIMARY KEY,
    nombre VARCHAR2(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponible INTEGER DEFAULT 1 CHECK (DISPONIBLE in (0,1))
);

CREATE TABLE pedidos (
    id_pedido INTEGER PRIMARY KEY,
    id_cliente INTEGER REFERENCES clientes(id_cliente),
    id_personal INTEGER REFERENCES personal_servicio(id_personal),
    fecha_pedido DATE DEFAULT SYSDATE,
    total DECIMAL(10, 2) DEFAULT 0
);

CREATE TABLE detalle_pedido (
    id_pedido INTEGER REFERENCES pedidos(id_pedido),
    id_plato INTEGER REFERENCES platos(id_plato),
    cantidad INTEGER NOT NULL,
    PRIMARY KEY (id_pedido, id_plato)
);

-- Autores:
-- Álvaro Ayllón
-- Mario Remacha
-- Samuel De Castro
-- GitHub: https://github.com/mariorv4/Practica2_PLSQL.git	
    
-- Procedimiento a implementar para realizar la reserva
create or replace procedure registrar_pedido(
    arg_id_cliente      INTEGER, 
    arg_id_personal     INTEGER, 
    arg_id_primer_plato INTEGER DEFAULT NULL,
    arg_id_segundo_plato INTEGER DEFAULT NULL
) is 
-- variables
    v_pedidosActivosPersonal  INTEGER; -- Contador de pedidos del personal
    v_precioPlato1            DECIMAL(10, 2) := 0; -- Precio del primer plato
    v_precioPlato2            DECIMAL(10, 2) := 0; -- Precio del segundo plato
    v_totalCalculado          DECIMAL(12, 2) := 0; -- Suma total del pedido
    v_nuevoIdPedido           INTEGER; -- Id para el nuevo pedido
    v_esPlatoDisponible       INTEGER; -- Flag de disponibilidad (0 o 1)
 begin
    -- Primera validación. Cada pedido debe incluir al menos un plato.
    if arg_id_primer_plato is null and arg_id_segundo_plato is null then
        RAISE_APPLICATION_ERROR(-20002, 'El pedido debe contener al menos un plato.');
    end if;
    -- Segunda validación. Capacidad del personal(5 pedidos simultáneos)
    select pedidos_activos
    into v_pedidosActivosPersonal
    from personal_servicio
    where id_personal = arg_id_personal
    for update;

    if v_pedidosActivosPersonal >= 5 then
             RAISE_APPLICATION_ERROR(-20003, 'El personal de servicio tiene demasiados pedidos.');
    end if;
    -- En caso de que no exista el Id del personal, al final se capturará en el "When others" que pondremos
    -- posteriormente la excepción ORA que enviará el select.
    --Tercera validación. Exitencia y disponibilidad de los platos y calculo parcial del total.
    v_totalCalculado := 0; 
    if arg_id_primer_plato is not null then
        begin
            select precio, disponible
            into v_precioPlato1, v_esPlatoDisponible 
            from platos
            where id_plato = arg_id_primer_plato;
            
            if v_esPlatoDisponible = 0 then 
                RAISE_APPLICATION_ERROR(-20001, 'El plato ' || arg_id_primer_plato || ' no está disponible.');
            end if;
            v_totalCalculado := v_totalCalculado + v_precioPlato1; 
        --Excepción si no hay primer plato (-20004)   
        exception
            when NO_DATA_FOUND then 
                RAISE_APPLICATION_ERROR(-20004, 'El primer plato seleccionado (' || arg_id_primer_plato || ') no existe.');
        end;
    end if;
    --Cuarta validación. Validar el segundo plato.
    if arg_id_segundo_plato is not  null and arg_id_segundo_plato != NVL(arg_id_primer_plato, -1) THEN
        begin
            select precio, disponible
            into v_precioPlato2, v_esPlatoDisponible
            from platos
            where id_plato = arg_id_segundo_plato;

            if v_esPlatoDisponible = 0 then 
                RAISE_APPLICATION_ERROR(-20001, 'El plato ' ||arg_id_segundo_plato || ' no está disponible.');
            end if;

            v_totalCalculado := v_totalCalculado + v_precioPlato2;
        --Excepción si no hay segundo plato (-20004)
        exception
            when NO_DATA_FOUND then
                RAISE_APPLICATION_ERROR(-20004, 'El segundo plato seleccionado (' || arg_id_segundo_plato || ') no existe.');
        end;
    end if;
    
    --Obtenemos el ID y el Crear Pedido en Pedidos

    select seq_pedidos.nextval into v_nuevoIdPedido from dual; --
    insert into pedidos (id_pedido, id_cliente, id_personal, fecha_pedido, total)
    values (v_nuevoIdPedido, arg_id_cliente, arg_id_personal, SYSDATE, v_totalCalculado);
    
     --Añadimos detalles en detalle_pedido
    
    if arg_id_primer_plato is not null then
        insert into detalle_pedido (id_pedido, id_plato, cantidad)
        values (v_nuevoIdPedido, arg_id_primer_plato, 1);
    end if;
    

    if arg_id_segundo_plato is not null and arg_id_segundo_plato != NVL(arg_id_primer_plato, -1) then
        insert into detalle_pedido (id_pedido, id_plato, cantidad)
        values (v_nuevoIdPedido, arg_id_segundo_plato, 1);
    END IF;
    --Actualizamos el número de pedidos activos del personal de servicio
    update personal_servicio
    set pedidos_activos = pedidos_activos + 1
    where id_personal = arg_id_personal;
    
    COMMIT;
    
    -- Ponemos el When others para capturar cualquier otra excepción
    -- Así evitamos estados inconsistentes en la base de datos
    exception
    when others then
        rollback;
        raise;
end;
/

------ Deja aquí tus respuestas a las preguntas del enunciado:
-- NO SE CORREGIRÁN RESPUESTAS QUE NO ESTÉN AQUÍ (utiliza el espacio que necesites apra cada una)
-- * P4.1
----Para garantizar que un miembro del personal de servicio no supere el limite 
--de pedidos activos he usado dos mecanismos:

--El primero es la restricción check en la tabla personal_servicio que asegura 
--que pedidos_activos no supere 5.

--El segundo es la segunda validación en el procedimiento registrar_pedido: antes de crear un pedido, 
--se verifica si el personal ya tiene 5 pedidos activos (usando SELECT ... FOR UPDATE
--para bloquear la fila y evitar condiciones de carrera). Si se cumple, se lanza el error -20003.

-- * P4.2
--   El sistema es extensible. Los nuevos platos y personal se pueden agregar sin necesidad de 
--modificar el procedimiento.

-- * P4.3
-- Si gracias al bloqueo for update que bloquea la fila del personal hasta que se haga commmit, 
--evitando que otras conexiones modifiquen pedidos_activos durante el proceso.
-- Además si falla cualquier paso posterior el roolback deshace todos los cambios manteniendo 
--la consistencia.

-- * P4.4
-- La restricción check añade una capa de seguridad a nivel de base de datos, pero es redundante con 
-- la lógica select for update y la comprobación if v_pedidosActivosPersonal >= 5 que ya existen en el procedimiento.

-- Gestión de excepciones:
-- El código actual ya previene el update y lanza el error -20003 si el límite se alcanza.
-- Si el update intentara violar el límite, la restricción check lanzaría un error genérico ORA-02290,
-- que sería capturado por el when others, provocando un rollback. El mensaje de error sería menos específico que el -20003.

-- Modificaciones: No son necesarias modificaciones significativas. La estrategia actual (comprobar antes de actualizar con for update)
-- es preferible porque da un error de aplicación claro (-20003). El check funciona como un elemento de seguridad adicional.
-- * P4.5
--   Las claves foráneas garantizan que no se puedan eliminar registros relacionados sin antes eliminar sus dependencias.


create or replace
procedure reset_seq( p_seq_name varchar )
is
    l_val number;
begin
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by -' || l_val || 
                                                          ' minvalue 0';
    execute immediate
    'select ' || p_seq_name || '.nextval from dual' INTO l_val;

    execute immediate
    'alter sequence ' || p_seq_name || ' increment by 1 minvalue 0';

end;
/


create or replace procedure inicializa_test is
begin
    
    reset_seq('seq_pedidos');
        
  
    delete from Detalle_pedido;
    delete from Pedidos;
    delete from Platos;
    delete from Personal_servicio;
    delete from Clientes;
    
    -- Insertar datos de prueba
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (1, 'Pepe', 'Perez', '123456789');
    insert into Clientes (id_cliente, nombre, apellido, telefono) values (2, 'Ana', 'Garcia', '987654321');
    
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (1, 'Carlos', 'Lopez', 0);
    insert into Personal_servicio (id_personal, nombre, apellido, pedidos_activos) values (2, 'Maria', 'Fernandez', 5);
    
    insert into Platos (id_plato, nombre, precio, disponible) values (1, 'Sopa', 10.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (2, 'Pasta', 12.0, 1);
    insert into Platos (id_plato, nombre, precio, disponible) values (3, 'Carne', 15.0, 0);

    commit;
end;
/

exec inicializa_test;

-- Completa lost test, incluyendo al menos los del enunciado y añadiendo los que consideres necesarios


 CREATE OR REPLACE PROCEDURE test_registrar_pedido IS
BEGIN
    -- Caso 1: Pedido válido con un plato disponible y personal con capacidad.
    BEGIN
        inicializa_test;
        registrar_pedido(1, 1, 1); -- Cliente Pepe pide Sopa con Personal Carlos.
        DBMS_OUTPUT.PUT_LINE('Caso 1 exitoso: Pedido realizado correctamente.');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caso 1 fallido: ' || SQLERRM);
    END;

-- Caso 2: Pedido vacío (sin platos).
    BEGIN
        inicializa_test;
        registrar_pedido(1, 1); -- Cliente Pepe no selecciona platos.
        DBMS_OUTPUT.PUT_LINE('Caso 2 exitoso.');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caso 2 fallido: ' || SQLERRM);
    END;

-- Caso 3: Pedido con un plato que no existe.
    BEGIN
        inicializa_test;
        registrar_pedido(1, 1, 99); -- Plato inexistente.
        DBMS_OUTPUT.PUT_LINE('Caso 3 exitoso.');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caso 3 fallido: ' || SQLERRM);
    END;
  
    -- Caso 4: Pedido que incluye un plato que no está disponible.
    -- Este caso espera la excepción -20001
    begin
        inicializa_test;
        -- Usamos el plato 3 (Carne), que está marcado como no disponible (0) en inicializa_test
        registrar_pedido(arg_id_cliente => 1, arg_id_personal => 1, arg_id_primer_plato => 3);
        -- Si llega aquí, el test falló porque no lanzó la excepción esperada.
        DBMS_OUTPUT.PUT_LINE('Caso 4 (Plato no disponible): FALLO - No se lanzó la excepción esperada -20001.');
    exception
        when others then
            if sqlcode = -20001 then
                DBMS_OUTPUT.PUT_LINE('Caso 4 (Plato no disponible): ÉXITO - Se lanzó correctamente la excepción -20001.');
            else
                DBMS_OUTPUT.PUT_LINE('Caso 4 (Plato no disponible): FALLO - Se lanzó una excepción inesperada: ' || SQLERRM);
            end if;
    end;
    
    -- Caso 5: Personal de servicio ya tiene 5 pedidos activos.
    -- Este caso espera a la excepción -20003
    begin
        inicializa_test;
        -- Usamos el personal 2 (Maria), que tiene 5 pedidos activos en inicializa_test
        registrar_pedido(arg_id_cliente => 1, arg_id_personal => 2, arg_id_primer_plato => 1); -- Plato 1 es válido
        -- Si llega aquí, el test falló porque no lanzó la excepción esperada.
        DBMS_OUTPUT.PUT_LINE('Caso 5 (Personal lleno): FALLO - No se lanzó la excepción esperada -20003.');
    exception
        when others then
            if sqlcode = -20003 then
                DBMS_OUTPUT.PUT_LINE('Caso 5 (Personal lleno): ÉXITO - Se lanzó correctamente la excepción -20003.');
            else
                DBMS_OUTPUT.PUT_LINE('Caso 5 (Personal lleno): FALLO - Se lanzó una excepción inesperada: ' || SQLERRM);
            end if;
    end;

    DBMS_OUTPUT.PUT_LINE('Fin de bateria de tests');
  
  -- Idem para el resto de casos

  /* - Si se realiza un pedido vac´ıo (sin platos) devuelve el error -200002.
     - Si se realiza un pedido con un plato que no existe devuelve en error -20004.
     - Si se realiza un pedido que incluye un plato que no est´a ya disponible devuelve el error -20001.
     - Personal de servicio ya tiene 5 pedidos activos y se le asigna otro pedido devuelve el error -20003
     - ... los que os puedan ocurrir que puedan ser necesarios para comprobar el correcto funcionamiento del procedimiento
*/
  
end;
/


set serveroutput on;
exec test_registrar_pedido;