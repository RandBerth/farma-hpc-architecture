CREATE TABLE IF NOT EXISTS productos (
    id_producto SERIAL PRIMARY KEY,
    codigo_barras VARCHAR(64) UNIQUE NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    precio_base NUMERIC(12, 2) NOT NULL CHECK (precio_base >= 0),
    creado_en TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS metricas_analiticas_orda (
    id_metrica SERIAL PRIMARY KEY,
    modo_ejecucion VARCHAR(50) NOT NULL,
    nodos_mpi INTEGER NOT NULL,
    hilos_openmp INTEGER NOT NULL,
    total_transacciones BIGINT NOT NULL,
    total_pacientes BIGINT NOT NULL,
    orda_acumulado DOUBLE PRECISION NOT NULL,
    pxt_promedio DOUBLE PRECISION NOT NULL,
    tiempo_secuencial_ms DOUBLE PRECISION NOT NULL,
    tiempo_paralelo_ms DOUBLE PRECISION NOT NULL,
    speedup DOUBLE PRECISION NOT NULL,
    eficiencia DOUBLE PRECISION NOT NULL,
    fecha_calculo TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_productos_codigo ON productos(codigo_barras);

CREATE TABLE IF NOT EXISTS metricas_analiticas_pxt (
    id_pxt SERIAL PRIMARY KEY,
    id_sucursal INTEGER NOT NULL DEFAULT 1,
    tecnicos_activos INTEGER NOT NULL,
    operaciones_mix VARCHAR(120) NOT NULL DEFAULT 'PXT',
    total_ventas BIGINT NOT NULL,
    total_intenciones BIGINT NOT NULL,
    horas_trabajadas DOUBLE PRECISION NOT NULL,
    pxt_calculado DOUBLE PRECISION NOT NULL,
    sql_amenazas_bloqueadas BIGINT NOT NULL DEFAULT 0,
    quiebres_stock_sedes BIGINT NOT NULL DEFAULT 0,
    ahorro_promociones DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    speedup DOUBLE PRECISION NOT NULL,
    eficiencia DOUBLE PRECISION NOT NULL,
    tiempo_paralelo_ms DOUBLE PRECISION NOT NULL,
    fecha_calculo TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
