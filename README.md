
# BI OEE & Análisis de Paros - Línea de Vinilos

Solución de Inteligencia de Negocios de extremo a extremo para el monitoreo de las líneas de envasado de vinilos. Este proyecto integra la extracción de datos, modelado dimensional, visualización y alertas en tiempo real para el cálculo del OEE y el análisis de tiempos perdidos.

**Tecnologías:** `Python` (ETL) | `PostgreSQL / Supabase` (Data Warehouse) | `Power BI` (Dashboard) | `Grafana` (Alertas y Monitoreo).

## Estructura Github

```
bi-oee-paros-vinilos/
├── sql/
│   ├── createtables.sql
│   ├── insertsestaticos.sql
│   └── createcalendario.sql
├── etl/
│   └── postgres/
│       ├── insert2.0(pgadmin).py
│       └── insertreferencias.py
├── grafana/
│   └── dashboardgrafana.json
├── powerbi/
│   ├── dashboardpowerbi.Report/
│   └── definition.pbir
├── doc/
│   └── BI_ProyectoFinal_Javier_Isaza-Diego_Mazo.pdf
└── README.md
```



## Proceso para reproducir la solución desde cero

### 1. Preparación de la Base de Datos (DDL y Datos Estáticos)
En PostgreSQL o Supabase (la plataforma de tu elección), ejecuta los scripts SQL en el siguiente orden estricto para construir el esquema relacional y poblar los catálogos:

1. `createtables.sql`
2. `insertestaticos.sql`
3. `createcalendario.sql`
4. `triggerslogicanegocio.sql`

> **Nota:** Todos estos archivos se encuentran en la carpeta `/sql`. Al finalizar, tendrás la estructura de tablas completa y los datos estáticos (máquinas, turnos, áreas, etc.) listos.

### 2. Ejecución del ETL en Python
Dirígete a la carpeta `/etl/postgres`. Antes de ejecutar los scripts, asegúrate de configurar tus credenciales y dependencias:

1. Instala las dependencias necesarias (se recomienda usar un entorno virtual):

   pip install -r requirements.txt

2. Configura la variable `DB_URI` con la cadena de conexión de tu base de datos dentro de los scripts.
3. Ejecuta los archivos en este orden:
* `insertreferencias.py`
* `Insert2.0(pgadmin).py` *(Asegúrate de incluir la extensión .py)*



> **Nota:** Dependiendo del motor de la BD y la latencia, este proceso tomará algo de tiempo. Espera hasta ver el mensaje de finalización en la consola.

### 3. Conexión a Power BI y Grafana

#### Power BI

Abre el archivo de proyecto `/powerbi/dashboardpowerbi_.pbip` y actualiza las credenciales de origen de datos:

* **Servidor (Host):** `tu_host` *(Si usas Supabase, usa el puerto del Connection Pooler, ej: `aws-0-xx.pooler.supabase.com:6543`)*
* **Base de datos:** `postgres`
* **Usuario:** `tu_usuario` *(En Supabase, incluye el ID del proyecto, ej: `postgres.tu_ref_proyecto`)*
* **Contraseña:** `tu_password`

**Solución a errores de Certificado SSL:**
Si experimentas errores de validación, deshabilita la encriptación estricta:

1. Ve a **Archivo** > **Opciones y configuración** > **Configuración de origen de datos**.
2. Selecciona tu conexión PostgreSQL y haz clic en **Editar permisos**.
3. Desmarca la casilla **"Cifrar conexiones"**, guarda los cambios y presiona **Actualizar**.

#### Grafana

Ingresa a tu entorno de Grafana y configura la conexión a la base de datos:

1. Ve a **Connections** > **Data sources** > **Add new data source**.
2. Selecciona **PostgreSQL** y completa los parámetros:
* **Host:** `tu_host:puerto`
* **Database:** `tu_base_de_datos`
* **User:** `tu_usuario`
* **Password:** `tu_password`


3. **TLS/SSL Mode:** Configúralo en `disable` o `require` según la política de tu servidor.
4. Haz clic en **Save & Test** para confirmar la conexión.

```

```
