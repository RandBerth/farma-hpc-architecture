BEGIN;

-- 1. Asegurar columnas e índices de alto rendimiento para búsquedas sobre 50,000 SKUs
ALTER TABLE productos ADD COLUMN IF NOT EXISTS stock_actual INTEGER NOT NULL DEFAULT 500;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS categoria VARCHAR(80) NOT NULL DEFAULT 'FARMACIA_CLINICA';
ALTER TABLE productos ADD COLUMN IF NOT EXISTS id_sucursal INTEGER NOT NULL DEFAULT 1;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS laboratorio VARCHAR(80) NOT NULL DEFAULT 'GENFARMA_PERU';

CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos(categoria);
CREATE INDEX IF NOT EXISTS idx_productos_sucursal ON productos(id_sucursal);

-- 2. Inyectar 50,000 SKUs farmacéuticos realistas (EAN-13 775..., principios activos, concentraciones y 12 sedes)
INSERT INTO productos (codigo_barras, nombre, precio_base, stock_actual, categoria, id_sucursal, laboratorio)
SELECT
    '775' || LPAD((100000000 + g)::text, 9, '0') AS codigo_barras,
    (ARRAY[
        'Paracetamol', 'Ibuprofeno', 'Amoxicilina', 'Azitromicina', 'Losartán Potásico',
        'Atorvastatina', 'Omeprazol', 'Metformina', 'Enalapril', 'Cetirizina',
        'Naproxeno Sódico', 'Dexametasona', 'Clonazepam', 'Salbutamol', 'Ciprofloxacino',
        'Captopril', 'Loratadina', 'Pantoprazol', 'Pregabalina', 'Cefalexina'
    ])[1 + (g % 20)] || ' ' ||
    (ARRAY['10mg', '20mg', '50mg', '100mg', '250mg', '500mg', '850mg', '1g'])[1 + (g % 8)] || ' - ' ||
    (ARRAY['Caja x 30 Tabs', 'Caja x 100 Tabs', 'Blíster x 10', 'Frasco Jarabe 120ml', 'Ampolla Iny. x 5', 'Sobre Granulado'])[1 + (g % 6)] ||
    ' [SKU-' || g || ']' AS nombre,
    ROUND((4.50 + ((g * 17) % 185) + ((g % 99) * 0.10))::numeric, 2) AS precio_base,
    150 + ((g * 31) % 2400) AS stock_actual,
    (ARRAY[
        'ANALGESICOS', 'ANTIBIOTICOS', 'CARDIOLOGIA', 'GASTROENTEROLOGIA',
        'ENDOCRINOLOGIA', 'RESPIRATORIO', 'NEUROLOGIA', 'PEDIATRIA'
    ])[1 + (g % 8)] AS categoria,
    1 + (g % 12) AS id_sucursal,
    (ARRAY['MEDIFARMA', 'HERSIL', 'PORTUGAL', 'FARMINDUSTRIA', 'AC FARMA', 'IQFARMA'])[1 + (g % 6)] AS laboratorio
FROM generate_series(1, 50000) AS g
ON CONFLICT (codigo_barras) DO NOTHING;

-- 3. Inyectar 100,000 registros históricos de auditoría PxT / Sedes para pruebas analíticas pesadas
INSERT INTO metricas_analiticas_pxt (
    id_sucursal, tecnicos_activos, operaciones_mix, total_ventas, total_intenciones,
    horas_trabajadas, pxt_calculado, sql_amenazas_bloqueadas, quiebres_stock_sedes,
    ahorro_promociones, speedup, eficiencia, tiempo_paralelo_ms, fecha_calculo
)
SELECT
    1 + (h % 12) AS id_sucursal,
    25 + (h % 40) AS tecnicos_activos,
    (ARRAY['ORDA,PXT', 'SANITIZER,SEDES', 'ORDA,HISTORICO,PROMOS', 'ECOMMERCE_CRUD'])[1 + (h % 4)] AS operaciones_mix,
    500000 + (h * 150) AS total_ventas,
    750000 + (h * 210) AS total_intenciones,
    360.0 AS horas_trabajadas,
    ROUND(((1250000 + (h * 360)) / 360.0)::numeric, 2) AS pxt_calculado,
    12 + (h % 450) AS sql_amenazas_bloqueadas,
    1 + (h % 18) AS quiebres_stock_sedes,
    ROUND((1250.50 + (h % 8000) * 1.35)::numeric, 2) AS ahorro_promociones,
    ROUND((8.15 + ((h % 65) * 0.08))::numeric, 4) AS speedup,
    ROUND((0.76 + ((h % 19) * 0.01))::numeric, 4) AS eficiencia,
    ROUND((110.0 + (h % 420) * 1.5)::numeric, 2) AS tiempo_paralelo_ms,
    CURRENT_TIMESTAMP - ((h || ' minutes')::interval) AS fecha_calculo
FROM generate_series(1, 100000) AS h
WHERE (SELECT COUNT(*) FROM metricas_analiticas_pxt) < 50000;

COMMIT;

-- Actualizar estadísticas del optimizador de consultas de PostgreSQL 18
ANALYZE productos;
ANALYZE metricas_analiticas_pxt;
