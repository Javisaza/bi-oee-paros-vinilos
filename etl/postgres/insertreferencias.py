import pandas as pd
import re
import psycopg2
from psycopg2.extras import execute_values

# Conexión directa a tu base de datos local en pgAdmin
DB_URI = "postgresql://postgres:1234@localhost:5432/taller5"

def obtener_id(cursor, tabla, columna, valor):
    if pd.isna(valor): return None
    valor_str = str(valor).strip()
    query = f"SELECT id FROM public.{tabla} WHERE {columna} = %s LIMIT 1"
    cursor.execute(query, (valor_str,))
    res = cursor.fetchone()
    return res[0] if res else None

# 1. LEER LOS ARCHIVOS
df_img = pd.read_excel('maquina1.xlsx') 
df_csv = pd.read_csv('Libro2.csv', encoding='latin1', sep=';')
if len(df_csv.columns) == 1:
    df_csv = pd.read_csv('Libro2.csv', encoding='latin1', sep=',')

# 2. PROCESAR Y UNIFICAR REFERENCIAS ÚNICAS
referencias_dict = {}

for _, row in df_img.iterrows():
    nombre = str(row['Nombre de referencia']).strip()
    referencias_dict[nombre] = {
        'num_colores': int(row['# colores']),
        'display': int(row['Display'])
    }

pares_maquina_csv = []
for i in range(4):
    maq_col = 'maquina' if i == 0 else f'maquina.{i}'
    ref_col = 'referencia' if i == 0 else f'referencia.{i}'
    
    if maq_col in df_csv.columns and ref_col in df_csv.columns:
        subset = df_csv[[maq_col, ref_col]].dropna()
        for _, row in subset.iterrows():
            ref_nombre = str(row[ref_col]).strip()
            maquina_nombre = str(row[maq_col]).strip()
            
            if ref_nombre.lower() != 'no aplica':
                pares_maquina_csv.append({'maquina': maquina_nombre, 'referencia': ref_nombre})
                
                if ref_nombre not in referencias_dict:
                    match = re.search(r'\((\d+)\s*col', ref_nombre.lower())
                    colores = int(match.group(1)) if match else 0
                    referencias_dict[ref_nombre] = {'num_colores': colores, 'display': 1}

# Iniciar conexión a PostgreSQL
try:
    conn = psycopg2.connect(DB_URI)
    cursor = conn.cursor()
    print("Conexión a PostgreSQL establecida correctamente.")

    # 3. INSERTAR EN LA TABLA REFERENCIA
    mapa_id_referencias = {}
    for nombre, datos in referencias_dict.items():
        cursor.execute("SELECT id FROM public.referencia WHERE descripcion = %s LIMIT 1", (nombre,))
        res = cursor.fetchone()
        
        if res:
            mapa_id_referencias[nombre] = res[0]
        else:
            cursor.execute(
                """INSERT INTO public.referencia (descripcion, num_colores, display) 
                   VALUES (%s, %s, %s) RETURNING id""",
                (nombre, datos['num_colores'], datos['display'])
            )
            mapa_id_referencias[nombre] = cursor.fetchone()[0]

    # 4. INSERTAR EN LA TABLA PRODUCCION_REFERENCIA (En Bloque)
    lote_produccion = []

    # A. Datos de la Máquina 1 (Imagen)
    for _, row in df_img.iterrows():
        nombre = str(row['Nombre de referencia']).strip()
        id_ref = mapa_id_referencias[nombre]
        lote_produccion.append((
            1, id_ref, float(row['Pacas']), int(row['Unidades * paca']), 
            float(row['unidades *minuto']), float(row['horas trabajas']), 
            float(row['minutos * turno']), float(row['unidades ideales * turno']), 
            float(row['pacas ideales * turno'])
        ))

    # B. Datos del CSV
    for par in pares_maquina_csv:
        nombre = par['referencia']
        id_ref = mapa_id_referencias[nombre]
        id_maquina_csv = obtener_id(cursor, "maquinas", "nombre", par['maquina'])
        
        if id_maquina_csv:
            lote_produccion.append((
                id_maquina_csv, id_ref, 0.0, 0, 0.0, 0.0, 0.0, 0.0, 0.0
            ))

    # Inserción masiva final
    if lote_produccion:
        query_insert = """
            INSERT INTO public.produccion_referencia 
            (fk_maquina, fk_referencia, pacas, ud_paca, ud_minuto, horas_trabajadas, minutos_turno, ud_ideales_turno, pacas_ideales_turno)
            VALUES %s
        """
        execute_values(cursor, query_insert, lote_produccion)

    # Confirmar todas las transacciones
    conn.commit()
    print("¡Migración de referencias completada con éxito!")

except Exception as e:
    print(f"Error durante la ejecución: {e}")
    if 'conn' in locals():
        conn.rollback()
finally:
    if 'cursor' in locals(): cursor.close()
    if 'conn' in locals(): conn.close()