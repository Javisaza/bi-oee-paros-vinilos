-- Borra primero el detalle y las tablas transaccionales
TRUNCATE TABLE registros_paro RESTART IDENTITY CASCADE;
TRUNCATE TABLE registros_produccion RESTART IDENTITY CASCADE;
TRUNCATE TABLE produccion_referencia RESTART IDENTITY CASCADE;

-- Borra los catálogos dinámicos que vamos a volver a crear con los scripts
TRUNCATE TABLE agente RESTART IDENTITY CASCADE;
TRUNCATE TABLE referencia RESTART IDENTITY CASCADE;

-- Borra todos los datos existentes

TRUNCATE TABLE 
    public.registros_paro,
    public.registros_produccion,
    public.produccion_referencia,
    public.agente,
    public.subcodigo_paro,
    public.codigo_paro,
    public.tipo_agente,
    public.turno,
    public.referencia,
    public.area_impacto,
    public.maquinas 
RESTART IDENTITY CASCADE;