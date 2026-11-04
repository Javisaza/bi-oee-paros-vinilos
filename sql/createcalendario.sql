-- 1. Crear la tabla dimensión tiempo si no existe
CREATE TABLE IF NOT EXISTS public.dim_tiempo (
    id_tiempo INT PRIMARY KEY, -- Formato YYYYMMDD
    fecha DATE UNIQUE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    dia INT NOT NULL,
    trimestre INT NOT NULL,
    semana_anio INT NOT NULL
);

-- 2. Poblar con todas las fechas desde 2022 hasta 2030
INSERT INTO public.dim_tiempo (id_tiempo, fecha, anio, mes, nombre_mes, dia, trimestre, semana_anio)
SELECT 
    TO_CHAR(d, 'YYYYMMDD')::INT AS id_tiempo,
    d::DATE AS fecha,
    EXTRACT(YEAR FROM d) AS anio,
    EXTRACT(MONTH FROM d) AS mes,
    TO_CHAR(d, 'TMMonth') AS nombre_mes,
    EXTRACT(DAY FROM d) AS dia,
    EXTRACT(QUARTER FROM d) AS trimestre,
    EXTRACT(WEEK FROM d) AS semana_anio
FROM generate_series('2022-01-01'::DATE, '2030-12-31'::DATE, '1 day'::interval) AS d
ON CONFLICT (fecha) DO NOTHING;