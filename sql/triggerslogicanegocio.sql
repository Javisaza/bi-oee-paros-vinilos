Logica de negocio: triggers y procedimientos almacenados
-- Reejecutable (idempotente). Ejecutar completo en DBeaver (Alt+X).
--
-- Contenido:
--   0. Columnas e indices de soporte
--   1. Utilidades (log de errores, duracion de turno, inicio de paro)
--   2. Trigger 10: validacion basica + idempotencia (hash_evento)
--   3. Trigger 30: duracion de paros vs. duracion del turno
--   4. Trigger 40: solapamiento temporal de paros por maquina
--   5. Auditoria de cambios criticos (UPDATE / DELETE)
--   6. Procedimiento sp_registrar_paro
--
-- Supuestos (verificalos contra tus datos):
--   * registros_paro.hora = hora de INICIO del paro (time).
--   * Un paro ocupa [fecha + hora, fecha + hora + tiempo_paro_minutos).
--   * Las filas invalidas NO abortan la carga: se envian a
--     auditoria_errores y el INSERT se descarta (RETURN NULL).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. SOPORTE
-- ---------------------------------------------------------------------

-- Evento prolongado: permite que los paros excedan la duracion del turno
-- SOLO si hay una justificacion escrita.
ALTER TABLE registros_paro
  ADD COLUMN IF NOT EXISTS evento_prolongado    boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS justificacion_evento text;

ALTER TABLE registros_paro DROP CONSTRAINT IF EXISTS ck_paro_justificacion;
ALTER TABLE registros_paro
  ADD CONSTRAINT ck_paro_justificacion
  CHECK (NOT evento_prolongado
         OR length(btrim(coalesce(justificacion_evento, ''))) > 0);

-- Indices que usan los triggers (busqueda por maquina/fecha y por registro)
CREATE INDEX IF NOT EXISTS ix_rp_maquina_fecha
  ON registros_produccion (fk_maquina, fecha);
CREATE INDEX IF NOT EXISTS ix_paro_registro
  ON registros_paro (fk_registro_produccion);
-- hash_evento unico (idempotencia de la carga)
CREATE UNIQUE INDEX IF NOT EXISTS ux_registros_paro_hash
  ON registros_paro (hash_evento);


-- ---------------------------------------------------------------------
-- 1. UTILIDADES
-- ---------------------------------------------------------------------

-- Registra una fila rechazada en la cuarentena
CREATE OR REPLACE FUNCTION fn_log_error(p_fila int, p_datos jsonb, p_msg text)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO auditoria_errores (fila_origen, datos_fila, mensaje_error, fecha_registro)
  VALUES (p_fila, p_datos, p_msg, now());
$$;

-- Duracion de un turno en minutos (soporta turnos que cruzan medianoche)
CREATE OR REPLACE FUNCTION fn_duracion_turno_min(p_turno bigint)
RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT EXTRACT(EPOCH FROM (
           CASE WHEN t.hora_fin > t.hora_inicio
                THEN t.hora_fin - t.hora_inicio
                ELSE t.hora_fin - t.hora_inicio + interval '24 hours' END)) / 60
  FROM turno t
  WHERE t.id = p_turno;
$$;

-- Timestamp de inicio de un paro. Si el turno cruza medianoche y la hora
-- es anterior al inicio del turno, el paro pertenece al dia siguiente.
CREATE OR REPLACE FUNCTION fn_paro_inicio(p_fecha date, p_hora time, p_turno bigint)
RETURNS timestamp LANGUAGE sql STABLE AS $$
  SELECT CASE
           WHEN p_hora IS NULL THEN NULL
           WHEN t.id IS NOT NULL
                AND t.hora_fin <= t.hora_inicio
                AND p_hora < t.hora_inicio
             THEN (p_fecha + p_hora) + interval '1 day'
           ELSE p_fecha + p_hora
         END
  FROM (SELECT 1) x
  LEFT JOIN turno t ON t.id = p_turno;
$$;


-- ---------------------------------------------------------------------
-- 2. TRIGGER 10: validacion basica + idempotencia
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_paro_validar() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tiempo_paro_minutos IS NULL OR NEW.tiempo_paro_minutos < 0 THEN
    PERFORM fn_log_error(COALESCE(NEW.fk_registro_produccion, -1)::int,
                         to_jsonb(NEW), 'tiempo_paro_minutos nulo o negativo');
    RETURN NULL;
  END IF;

  IF NEW.hash_evento IS NULL THEN
    NEW.hash_evento := md5(concat_ws('|',
      NEW.fk_registro_produccion, NEW.fk_subcodigo_paro,
      NEW.hora, NEW.tiempo_paro_minutos));
  END IF;

  -- Idempotencia: si el evento ya existe, se ignora en silencio.
  -- Evita falsos "solapamientos" al re-ejecutar el ETL.
  IF EXISTS (SELECT 1 FROM registros_paro WHERE hash_evento = NEW.hash_evento) THEN
    RETURN NULL;
  END IF;

  RETURN NEW;
END $$;

-- Limpieza de versiones anteriores
DROP TRIGGER  IF EXISTS trg_paro_validar   ON registros_paro;
DROP TRIGGER  IF EXISTS trg_paro_vs_turno  ON registros_paro;
DROP FUNCTION IF EXISTS fn_paro_vs_turno();

DROP TRIGGER IF EXISTS trg_paro_10_validar ON registros_paro;
CREATE TRIGGER trg_paro_10_validar
BEFORE INSERT ON registros_paro
FOR EACH ROW EXECUTE FUNCTION fn_paro_validar();


-- ---------------------------------------------------------------------
-- 3. TRIGGER 30: duracion de paros vs. duracion del turno
--    Regla: suma de paros del registro <= duracion del turno,
--           salvo evento_prolongado = true (con justificacion, ver CHECK).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_paro_duracion() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_dur   numeric;
  v_otros numeric;
BEGIN
  IF NEW.fk_registro_produccion IS NULL THEN
    PERFORM fn_log_error(-1, to_jsonb(NEW), 'Paro sin registro de produccion asociado');
    RETURN NULL;
  END IF;

  SELECT fn_duracion_turno_min(rp.fk_turno) INTO v_dur
  FROM registros_produccion rp
  WHERE rp.id = NEW.fk_registro_produccion;

  IF v_dur IS NULL THEN
    RETURN NEW;      -- registro sin turno: no se puede validar la duracion
  END IF;

  SELECT COALESCE(SUM(p.tiempo_paro_minutos), 0) INTO v_otros
  FROM registros_paro p
  WHERE p.fk_registro_produccion = NEW.fk_registro_produccion
    AND p.id IS DISTINCT FROM NEW.id;

  IF v_otros + NEW.tiempo_paro_minutos > v_dur AND NOT NEW.evento_prolongado THEN
    PERFORM fn_log_error(
      NEW.fk_registro_produccion::int, to_jsonb(NEW),
      format('Paros acumulados (%s min) exceden la duracion del turno (%s min) '
             'sin justificacion de evento prolongado',
             v_otros + NEW.tiempo_paro_minutos, v_dur));
    RETURN NULL;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_paro_30_duracion ON registros_paro;
CREATE TRIGGER trg_paro_30_duracion
BEFORE INSERT OR UPDATE OF hora, tiempo_paro_minutos, fk_registro_produccion, evento_prolongado
ON registros_paro
FOR EACH ROW EXECUTE FUNCTION fn_paro_duracion();


-- ---------------------------------------------------------------------
-- 4. TRIGGER 40: solapamiento temporal de paros por maquina
--    Dos paros de la misma maquina no pueden compartir ningun minuto.
--    Intervalos semiabiertos [inicio, fin): un paro que termina a las
--    08:15 y otro que empieza a las 08:15 NO se solapan.
--    Si hora es NULL no hay intervalo y no se valida.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_paro_solapamiento() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_maq    bigint;
  v_ini    timestamp;
  v_fin    timestamp;
  v_choque bigint;
BEGIN
  IF NEW.hora IS NULL OR NEW.fk_registro_produccion IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT rp.fk_maquina, fn_paro_inicio(rp.fecha, NEW.hora, rp.fk_turno)
    INTO v_maq, v_ini
  FROM registros_produccion rp
  WHERE rp.id = NEW.fk_registro_produccion;

  IF v_maq IS NULL OR v_ini IS NULL THEN
    RETURN NEW;
  END IF;

  v_fin := v_ini + NEW.tiempo_paro_minutos::float8 * interval '1 minute';

  -- Serializa inserciones concurrentes de la misma maquina
  -- (sin esto, dos transacciones simultaneas podrian pasar la validacion).
  PERFORM pg_advisory_xact_lock(hashtext('registros_paro'), v_maq::int);

  SELECT p.id INTO v_choque
  FROM registros_produccion r
  JOIN registros_paro p ON p.fk_registro_produccion = r.id
  WHERE r.fk_maquina = v_maq
    AND r.fecha BETWEEN v_ini::date - 1 AND v_ini::date + 1
    AND p.hora IS NOT NULL
    AND p.id IS DISTINCT FROM NEW.id
    AND fn_paro_inicio(r.fecha, p.hora, r.fk_turno) < v_fin
    AND fn_paro_inicio(r.fecha, p.hora, r.fk_turno)
        + p.tiempo_paro_minutos::float8 * interval '1 minute' > v_ini
  LIMIT 1;

  IF v_choque IS NOT NULL THEN
    PERFORM fn_log_error(
      NEW.fk_registro_produccion::int, to_jsonb(NEW),
      format('Paro solapado con el paro id=%s de la misma maquina (%s a %s)',
             v_choque, v_ini, v_fin));
    RETURN NULL;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_paro_40_solapamiento ON registros_paro;
CREATE TRIGGER trg_paro_40_solapamiento
BEFORE INSERT OR UPDATE OF hora, tiempo_paro_minutos, fk_registro_produccion
ON registros_paro
FOR EACH ROW EXECUTE FUNCTION fn_paro_solapamiento();

-- Orden de ejecucion (alfabetico por nombre):
--   10_validar -> 30_duracion -> 40_solapamiento -> (trg_paro_jerarquia, si existe)


-- ---------------------------------------------------------------------
-- 5. AUDITORIA DE CAMBIOS CRITICOS
--    Solo UPDATE y DELETE (los INSERT del ETL ya quedan trazados por
--    created_at / hash_evento y duplicarian el volumen).
--    Se ignora updated_at para no registrar cambios "vacios".
--    NO se audita 'agente': copiaria documento/telefono/correo.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auditoria_cambios (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tabla              text        NOT NULL,
  registro_id        bigint,
  operacion          text        NOT NULL CHECK (operacion IN ('UPDATE', 'DELETE')),
  datos_antes        jsonb,
  datos_despues      jsonb,
  columnas_cambiadas text[],
  usuario            text        NOT NULL DEFAULT current_user,
  fecha              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_aud_cambios_tabla_reg
  ON auditoria_cambios (tabla, registro_id, fecha DESC);

CREATE OR REPLACE FUNCTION fn_auditar_cambio() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_old  jsonb := to_jsonb(OLD) - 'updated_at';
  v_new  jsonb;
  v_cols text[];
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v_new := to_jsonb(NEW) - 'updated_at';
    IF v_old = v_new THEN
      RETURN NULL;                          -- no cambio ningun dato real
    END IF;
    SELECT array_agg(n.key ORDER BY n.key) INTO v_cols
    FROM jsonb_each(v_new) n
    WHERE v_old -> n.key IS DISTINCT FROM n.value;

    INSERT INTO auditoria_cambios
      (tabla, registro_id, operacion, datos_antes, datos_despues, columnas_cambiadas)
    VALUES (TG_TABLE_NAME, (v_old ->> 'id')::bigint, 'UPDATE', v_old, v_new, v_cols);
  ELSE
    INSERT INTO auditoria_cambios
      (tabla, registro_id, operacion, datos_antes)
    VALUES (TG_TABLE_NAME, (v_old ->> 'id')::bigint, 'DELETE', v_old);
  END IF;
  RETURN NULL;
END $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['registros_produccion', 'registros_paro',
                           'produccion_referencia', 'maquinas', 'turno',
                           'referencia', 'codigo_paro', 'subcodigo_paro']
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%1$s_audit ON %1$I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_%1$s_audit AFTER UPDATE OR DELETE ON %1$I
       FOR EACH ROW EXECUTE FUNCTION fn_auditar_cambio()', t);
  END LOOP;
END $$;


-- ---------------------------------------------------------------------
-- 6. PROCEDIMIENTO ALMACENADO: registrar un paro
--    Punto de entrada para Grafana/formularios/simulador. Devuelve 'OK'
--    o 'RECHAZADO: motivo' (los triggers descartan en silencio; este
--    procedimiento hace visible el resultado).
--
--    CALL sp_registrar_paro(<id_registro>, <id_subcodigo|NULL>, '08:00',
--                           15, 'observacion', false, NULL, NULL);
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_paro(
  p_registro          bigint,
  p_subcodigo         bigint,
  p_hora              time,
  p_minutos           numeric,
  p_observaciones     text,
  p_evento_prolongado boolean,
  p_justificacion     text,
  INOUT p_resultado   text
)
LANGUAGE plpgsql AS $$
DECLARE
  v_filas int;
BEGIN
  INSERT INTO registros_paro
    (fk_registro_produccion, fk_subcodigo_paro, hora, tiempo_paro_minutos,
     observaciones, evento_prolongado, justificacion_evento, created_at, updated_at)
  VALUES
    (p_registro, p_subcodigo, p_hora, p_minutos,
     p_observaciones, COALESCE(p_evento_prolongado, false), p_justificacion, now(), now());

  GET DIAGNOSTICS v_filas = ROW_COUNT;

  p_resultado := CASE WHEN v_filas = 1
                      THEN 'OK'
                      ELSE 'RECHAZADO: ver ultimo registro de auditoria_errores' END;
EXCEPTION
  WHEN check_violation THEN
    PERFORM fn_log_error(p_registro::int,
      jsonb_build_object('registro', p_registro, 'hora', p_hora, 'minutos', p_minutos),
      SQLERRM);
    p_resultado := 'RECHAZADO: ' || SQLERRM;
END $$;