# bi-oee-paros-vinilos
Solución de BI de extremo a extremo para las líneas de envasado de vinilos: ETL en Python, modelo dimensional en PostgreSQL, tablero analítico en Power BI y monitoreo con alertas en Grafana. Indicadores de OEE y análisis de paros.  Topics: business-intelligence, oee, postgresql, power-bi, grafana, etl, python, data-warehouse.


# Proceso para reproducir la solución desde 0:

## 1. Preparación de la base de datos (BD) e inserción de datos estáticos 
  En PostgreSQL o Supabase la plataforma que sea de su elección ejecute los archivos en este orden

  - createtables.sql
  - insertestaticos.sql
  - createcalendario.sql
  - triggerslogicanegocio.sql

  todos estos archivos estan en la carpeta (/sql). Con esto ya tendra el DDL en su base de datos correctamente y los datos estaticos como las maquinas, turnos,etc

## 2. Ejecución del ETL en Python
   Ahora en la carpeta (/etl/postgres) deberá ejecutar los archivos .py en el siguiente orden, antes de ejecutarlo deberá escribir la DB_URI de su base de datos para que le inserte los datos correctamente:
   - insertreferncias.py
   - Insert2.0(pgadmin)
  
   (dependiendo del motor de la BD el proceso puede demorar más o menos tiempo, tenga paciencia, cuando finalice vera en la consola un mensaje de finalizacion)

  De esta manera ya tendrá organizados y cargados los datos iniciales

## 3. Conexión a powerBi y Grafana
  ### PowerBI
  Ingrese al archivo de powerBI (/powerbi/dashboardpowerbi_.pbip) realice la conexión a la BD con sus credenciales de 
  - HOST:
  - DATABASE_NAME:
  - USER:
  - PASSWORD:

  para evitar errores de SSL puede desactivar la encriptación o descargar el certificado

  Para deshabilitar la encriptación ingrese a la sección "Archivo" -> "Opciones y configuraciones" -> "Configuración de Origen de Datos" -> "Editar Permisos"(Sobre su fuente de datos) -> y quite la selección de "Cifrar conexiones", guarde los cambios y continue

  ### Grafana

  Ingrese a la web de Grafana Dashboards, diríjase al apartado de "conections" -> "Data sources" -> "Add new data sources" -> seleccione la opcion de postgres y llene los datos:

  - HOST:
  - DATABASE_NAME:
  - USER:
  - PASSWORD:

  haga el test de conexion y guardela
  



