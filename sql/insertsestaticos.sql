-- ==============================================================================
-- PARTE 1 DE INSERTS: CATÁLOGOS Y TABLAS MAESTRAS INICIALES
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CATÁLOGOS BASE (NIVEL 1 - SIN DEPENDENCIAS DE FK)
-- ------------------------------------------------------------------------------

-- Tabla: area_impacto
INSERT INTO public.area_impacto (descripcion) VALUES
('Mantenimiento'),
('Producción'),
('Calidad'),
('Almacén de materias primas'),
('Paro programado'),
('Ventas'),
('No aplica');

-- Tabla: maquinas
INSERT INTO public.maquinas (nombre, descripcion) VALUES
('Vinilos_1', 'Línea de envasado Vinilos 1'),
('Vinilos_2', 'Línea de envasado Vinilos 2'),
('Vinilos_3', 'Línea de envasado Vinilos 3'),
('Vinilos_4', 'Línea de envasado Vinilos 4');

-- Tabla: turno
INSERT INTO public.turno (hora_inicio, hora_fin, descripcion) VALUES
('06:00:00', '14:00:00', '6am-2pm (Turno 1)'),
('14:00:00', '22:00:00', '2pm-10pm (Turno 2)'),
('22:00:00', '06:00:00', '10pm-6am (Turno 3)'),
('06:00:00', '18:00:00', '6am-6pm'),
('18:00:00', '06:00:00', '6pm-6am'),
('06:00:00', '16:30:00', '6am-4:30pm'),
('00:00:00', '00:00:00', 'No aplica');

-- Tabla: tipo_agente
INSERT INTO public.tipo_agente (descripcion) VALUES
('Personal de mantenimiento'),
('Operarios'),
('Auxiliar de piso'),
('Personal de despachos'),
('Personal de calidad'),
('Supervisor');


-- ------------------------------------------------------------------------------
-- 2. CATÁLOGOS DEPENDIENTES (NIVEL 2 - CON DEPENDENCIAS DE NIVEL 1)
-- ------------------------------------------------------------------------------

-- Tabla: codigo_paro
INSERT INTO public.codigo_paro (codigo, descripcion, fk_area_impacto) VALUES
('01', 'Falla del sistema electromecánico y/o de control', (SELECT id FROM public.area_impacto WHERE descripcion = 'Mantenimiento')),
('02', 'Espera de soporte de mantenimiento', (SELECT id FROM public.area_impacto WHERE descripcion = 'Mantenimiento')),
('03', 'Novedad en los sistemas de potencia (Aire, energía, vapor)', (SELECT id FROM public.area_impacto WHERE descripcion = 'Mantenimiento')),
('04', 'Mantenimiento preventivo', (SELECT id FROM public.area_impacto WHERE descripcion = 'Mantenimiento')),
('05', 'Ajuste operativo', (SELECT id FROM public.area_impacto WHERE descripcion = 'Producción')),
('06', 'Limpieza por derrame operativo', (SELECT id FROM public.area_impacto WHERE descripcion = 'Producción')),
('07', 'Alistamiento de máquina / Cambio de referencia', (SELECT id FROM public.area_impacto WHERE descripcion = 'Producción')),
('08', 'Capacitación / Reunión', (SELECT id FROM public.area_impacto WHERE descripcion = 'Producción')),
('09', 'Falta de operario', (SELECT id FROM public.area_impacto WHERE descripcion = 'Producción')),
('10', 'Paro por ventaja/evacuación', (SELECT id FROM public.area_impacto WHERE descripcion = 'Producción')),
('11', 'Reproceso', (SELECT id FROM public.area_impacto WHERE descripcion = 'Producción')),
('12', 'Materia prima defectuosa o material de empaque no conforme', (SELECT id FROM public.area_impacto WHERE descripcion = 'Calidad')),
('13', 'En espera por el aval del laboratorio de microbiología', (SELECT id FROM public.area_impacto WHERE descripcion = 'Calidad')),
('14', 'Falta de materia prima', (SELECT id FROM public.area_impacto WHERE descripcion = 'Almacén de materias primas')),
('15', 'Cambio de insumos (Roscadores, O''ring, Etiquetas)', (SELECT id FROM public.area_impacto WHERE descripcion = 'Paro programado')),
('16', 'Alimentación y aseo de la zona de trabajo y la máquina', (SELECT id FROM public.area_impacto WHERE descripcion = 'Paro programado')),
('17', 'Pausa activa', (SELECT id FROM public.area_impacto WHERE descripcion = 'Paro programado')),
('18', 'Paro de maquina', (SELECT id FROM public.area_impacto WHERE descripcion = 'Ventas')),
('N/A', 'No aplica', (SELECT id FROM public.area_impacto WHERE descripcion = 'No aplica'));

-- Tabla: agente
INSERT INTO public.agente (nombre, fk_tipo_agente) VALUES
('Carlos Arturo Arguello Monsalve', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Luis Carlos Mercado Mercado', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Juan David Osipina Rincon', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Juan Diego Albarracin Vanegas', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Jose Rafael Nuñez Mesa', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Gilberto De Jesus Zapata Herrera', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Chiry Novady Arboleda Sanchez', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Bayron Rua Bohorquez', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('John Fredy Valencia Henao', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Daniel Hernney Cardona Jaramillo', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Juan Sebastian Arboleda Garcia', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Personal de mantenimiento')),
('Auxiliar de piso', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Auxiliar de piso')),
('Adriana Patricia Henao García', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Operarios')),
('Mónica Velez Vasco', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Operarios')),
('Juan Sebastián Rodriguez Manco', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Operarios')),
('Valentina Velásquez Cardona', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Operarios')),
('Francis Isabel Blanco Pinto', (SELECT id FROM public.tipo_agente WHERE descripcion = 'Operarios'));


-- ------------------------------------------------------------------------------
-- 3. CATÁLOGOS DEPENDIENTES (NIVEL 3 - CON DEPENDENCIAS DE NIVEL 2)
-- ------------------------------------------------------------------------------

-- Tabla: subcodigo_paro
INSERT INTO public.subcodigo_paro (codigo, descripcion, fk_codigo_paro) VALUES
-- CÓDIGO 01
('1.1', '1.1 SISTEMA ALIMENTADOR DE ENVASES', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.1.A', '1.1.A Banda', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.1.B', '1.1.B Motor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.1.C', '1.1.C Sensor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.2', '1.2 SISTEMA DE DOSIFICACIÓN', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.2.A', '1.2.A Cambio de racores', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.2.B', '1.2.B Ajuste de sensor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.2.C', '1.2.C Cambio de Valvula', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.2.D', '1.2.D Retenedores', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.2.E', '1.2.E O''Ring', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.3', '1.3 SISTEMA DE BANDA DE ENTRADA', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.3.A', '1.3.A Banda', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.3.B', '1.3.B Motor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.4', '1.4 SISTEMA DE TAPADO', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.4.A', '1.4.A Motor del transfer', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.4.B', '1.4.B Pisador de tapa', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.4.C', '1.4.C Sensor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.5', '1.5 SISTEMA DE ALIMENTACIÓN DE TAPA', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.5.A', '1.5.A Banda', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.5.B', '1.5.B Motor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.5.C', '1.5.C Sensor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.6', '1.6 SISTEMA VIDEO JET', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.6.A', '1.6.A Fotocelda', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.6.B', '1.6.B Sensor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.7', '1.7 SISTEMA DE SUJECIÓN Y ROSCADORES', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.7.A', '1.7.A Banda de sujeción', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.7.B', '1.7.B Roscadores', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.8', '1.8 SISTEMA ETIQUETADORA', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.8.A', '1.8.A Banda', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.8.B', '1.8.B Motor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('1.8.C', '1.8.C Sensor', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),

-- CÓDIGO 03
('3.1', '3.1 Fallo en la subestación', (SELECT id FROM public.codigo_paro WHERE codigo = '03')),
('3.2', '3.2 Fallo en la red pública', (SELECT id FROM public.codigo_paro WHERE codigo = '03')),
('3.3', '3.3 Falla en la red neumática o el compresor', (SELECT id FROM public.codigo_paro WHERE codigo = '03')),
('3.4', '3.4 Falla en la red de enfriamiento o el chiller', (SELECT id FROM public.codigo_paro WHERE codigo = '03')),
('3.5', '3.5 Falla en la red de vapor o la caldera', (SELECT id FROM public.codigo_paro WHERE codigo = '03')),

-- CÓDIGO 05
('5.1', '5.1 Sistema alimentador de envases', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.2', '5.2 Sistema de dosificación de pintura, frontal posterior', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.3', '5.3 Banda transportadora de entrada', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.4', '5.4 Banda transportadora de salida', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.5', '5.5 Transfer y pisador de tapa', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.6', '5.6 Sistema alimentador de tapa y tobogan', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.7', '5.7 Video Jet', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.8', '5.8 Banda de sujeción y roscadores', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.9', '5.9 Sistema de etiquetado', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.10', '5.10 Purga de color', (SELECT id FROM public.codigo_paro WHERE codigo = '05')),
('5.11', '5.11 Lavado de boquilla', (SELECT id FROM public.codigo_paro WHERE codigo = '05'));

-- CODIGOS EXTRA
INSERT INTO public.subcodigo_paro (codigo, descripcion, fk_codigo_paro) VALUES
('1.99', '1.99 Otros / No especificado', (SELECT id FROM public.codigo_paro WHERE codigo = '01')),
('3.99', '3.99 Otros / No especificado', (SELECT id FROM public.codigo_paro WHERE codigo = '03')),
('5.99', '5.99 Otros / No especificado', (SELECT id FROM public.codigo_paro WHERE codigo = '05'));

-- Agentes tipo Operarios 

INSERT INTO public.agente (nombre, fk_tipo_agente) VALUES
('Alba', 1),
('Alexandra', 1),
('Ana', 1),
('Andrea', 1),
('Andrea G.', 1),
('Andrea U.', 1),
('Blanquita', 1),
('Blas', 1),
('Ceidy', 1),
('Claudia', 1),
('Cristina', 1),
('Dayana', 1),
('Diana', 1),
('Eliannis', 1),
('Erika', 1),
('Erika H.', 1),
('Estela', 1),
('Evelin', 1),
('Helen', 1),
('Isabel', 1),
('Leidi', 1),
('Lorena T.', 1),
('Luisa', 1),
('Luz R.', 1),
('Maira', 1),
('Marcela', 1),
('Marcela C.', 1),
('Maria', 1),
('Maria O.', 1),
('Mariana', 1),
('Monica', 1),
('No aplica', 1),
('Paola', 1),
('Paula', 1),
('Sebastian', 1),
('Tatiana', 1),
('Valentina', 1),
('Veronica', 1),
('Veronica M.', 1),
('Yarima', 1),
('Yessenia A.', 1),
('Yina', 1),
('Yuliana Y.', 1),
('Carla', 1);