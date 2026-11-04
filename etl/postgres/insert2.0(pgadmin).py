import pandas as pd
import datetime
import psycopg2
from psycopg2.extras import execute_values
import hashlib
import json

#conexion a pgadmin
DB_URI = "postgresql://postgres:1234@localhost:5432/taller5"

df = pd.read_excel('BD_actividad.xlsx', sheet_name='Base De Datos (2)', header=1)

mapeo_subcodigos = {
    "1.1B  MOTOR ": "1.1.B", "1.2C  CAMBIO DE VALVULA ": "1.2.C", "1.4.3 Sensor": "1.4.C",
    "4.1  SISTEMA ALIMENTACION DE ENVASE ": "5.1", "4.2  SISTEMA DOSIFICADOR DE PINTURA, FRONTAL Y POSTERIOR.": "5.2",
    "4.3  BANDA TRASPORTADORA DE ENTRADA ": "5.3", "4.4  TRANSFER Y PISADOR DE TAPADO ": "5.5",
    "4.5  SISTEMA ALIMENTADOR DE TAPA. YBTOBOGAN ": "5.6", "4.6 VIDEO JET": "5.7",
    "4.7 BANDA SUJECION Y ROSCADORES ": "5.8", "4.8 SISTEMA DE ETIQUETADO": "5.9", "Sin especificar": "5.99"
}

horas_fin_turno = {"1": datetime.time(14, 0, 0), "2": datetime.time(22, 0, 0), "3": datetime.time(6, 0, 0)}
cache_ids = {}

def obtener_id(cursor, tabla, columna, valor):
    if pd.isna(valor): return None
    valor_str = str(valor).strip()
    clave_cache = f"{tabla}_{columna}_{valor_str}"
    if clave_cache in cache_ids: return cache_ids[clave_cache]
    cursor.execute(f"SELECT id FROM public.{tabla} WHERE {columna} = %s LIMIT 1", (valor_str,))
    res = cursor.fetchone()
    if res:
        cache_ids[clave_cache] = res[0]
        return res[0]
    return None

def obtener_o_crear_agente(cursor, nombre_operario, id_tipo_operario=1):
    if pd.isna(nombre_operario) or str(nombre_operario).strip() == "": return None
    nombre_limpio = str(nombre_operario).strip()
    clave_cache = f"agente_{nombre_limpio}"
    if clave_cache in cache_ids: return cache_ids[clave_cache]
    cursor.execute("SELECT id FROM public.agente WHERE nombre = %s LIMIT 1", (nombre_limpio,))
    res = cursor.fetchone()
    if res:
        cache_ids[clave_cache] = res[0]
        return res[0]
    cursor.execute("INSERT INTO public.agente (nombre, fk_tipo_agente) VALUES (%s, %s) RETURNING id", (nombre_limpio, id_tipo_operario))
    nuevo_id = cursor.fetchone()[0]
    cache_ids[clave_cache] = nuevo_id
    return nuevo_id

def safe_float(valor):
    if pd.isna(valor): return 0.0
    if isinstance(valor, str): valor = valor.replace(',', '').strip()
    try: return float(valor)
    except ValueError: return 0.0

try:
    conn = psycopg2.connect(DB_URI)
    cursor = conn.cursor()
    print("Iniciando pipeline ETL automatizado...")

    for index, row in df.iterrows():
        if pd.isna(row['Fecha']): continue
        
        # Iniciar un SAVEPOINT para aislar errores por fila sin romper el bucle masivo
        cursor.execute("SAVEPOINT fila_actual")
        
        try:
            id_turno = obtener_id(cursor, "turno", "descripcion", row['Turno'])
            id_maquina = obtener_id(cursor, "maquinas", "nombre", row['Maquina'])
            id_referencia = obtener_id(cursor, "referencia", "descripcion", row['Referencia'])
            id_agente = obtener_o_crear_agente(cursor, row['Operario'])
            
            fecha_base = row['Fecha'].date()
            hora_asignada = horas_fin_turno.get(str(row['Turno']).strip(), datetime.time(0, 0, 0))
            fecha_hora_final = datetime.datetime.combine(fecha_base, hora_asignada)
            
            p_producidas = safe_float(row.get('Pacas producidas'))
            p_defectuosas = safe_float(row.get('Pacas defectuosas'))
            h_trabajadas = safe_float(row.get('Horas trabajadas'))

            # UPSERT Idempotente para Producción
            upsert_query = """
                INSERT INTO public.registros_produccion 
                (fecha, fk_maquina, fk_agente, fk_referencia, fk_turno, pacas_producidas, pacas_defectuosas, horas_trabajadas)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (fecha, fk_turno, fk_maquina, fk_referencia)
                DO UPDATE SET 
                    fk_agente = EXCLUDED.fk_agente,
                    pacas_producidas = COALESCE(public.registros_produccion.pacas_producidas, 0) + EXCLUDED.pacas_producidas,
                    pacas_defectuosas = COALESCE(public.registros_produccion.pacas_defectuosas, 0) + EXCLUDED.pacas_defectuosas,
                    horas_trabajadas = COALESCE(public.registros_produccion.horas_trabajadas, 0) + EXCLUDED.horas_trabajadas
                RETURNING id;
            """
            cursor.execute(upsert_query, (fecha_hora_final, id_maquina, id_agente, id_referencia, id_turno, p_producidas, p_defectuosas, h_trabajadas))
            id_produccion = cursor.fetchone()[0]
            
            lote_paros = []
            for i in range(1, 19):
                minutos = safe_float(row.get(f'Codigo de paro {i}'))
                if minutos > 0:
                    subcodigo_texto = None
                    if i == 1: subcodigo_texto = row.get('Sub Codigo de paro 1')
                    elif i == 3: subcodigo_texto = row.get('Subcodigo 3')
                    elif i == 5: subcodigo_texto = row.get('Subcodigo 5')
                    
                    fk_subcodigo = None
                    if pd.notna(subcodigo_texto) and str(subcodigo_texto).strip() != "":
                        texto_limpio = mapeo_subcodigos.get(str(subcodigo_texto).strip(), str(subcodigo_texto).strip())
                        fk_subcodigo = obtener_id(cursor, "subcodigo_paro", "codigo", str(texto_limpio).split(" ")[0])
                    
                    if fk_subcodigo is None:
                        fk_subcodigo = obtener_id(cursor, "codigo_paro", "codigo", str(i).zfill(2))
                    
                    obs_final = str(row.get('Observaciones de paro', '')) if pd.notna(row.get('Observaciones de paro')) else None
                    
                    # Generación de Clave Hash Única por evento de paro
                    hash_str = f"{id_produccion}-{fk_subcodigo}-{minutos}-{i}-{fecha_base}"
                    hash_evento = hashlib.sha256(hash_str.encode()).hexdigest()
                    
                    lote_paros.append((id_produccion, fk_subcodigo, minutos, obs_final, hash_evento))
            
            # BULK INSERT Idempotente para Paros
            if lote_paros:
                insert_paros_query = """
                    INSERT INTO public.registros_paro 
                    (fk_registro_produccion, fk_subcodigo_paro, tiempo_paro_minutos, observaciones, hash_evento)
                    VALUES %s
                    ON CONFLICT (hash_evento) DO NOTHING
                """
                execute_values(cursor, insert_paros_query, lote_paros)

            cursor.execute("RELEASE SAVEPOINT fila_actual")
            
        except Exception as e:
            # Captura y auditoría del error sin detener la ejecución
            cursor.execute("ROLLBACK TO SAVEPOINT fila_actual")
            error_msg = str(e)
            
            # Convertir la fila a JSON de forma segura
            row_dict = {str(k): str(v) for k, v in row.to_dict().items()}
            row_json = json.dumps(row_dict)
            
            cursor.execute(
                "INSERT INTO public.auditoria_errores (fila_origen, datos_fila, mensaje_error) VALUES (%s, %s, %s)",
                (index, row_json, error_msg)
            )
            print(f"Error gestionado en fila {index}. Registrado en auditoria_errores.")

        if index % 500 == 0:
            conn.commit()

    conn.commit()
    print("Pipeline finalizado. Todos los datos han sido procesados de forma segura e idempotente.")

except Exception as e:
    print(f"Error crítico de conexión: {e}")
finally:
    if 'cursor' in locals(): cursor.close()
    if 'conn' in locals(): conn.close()