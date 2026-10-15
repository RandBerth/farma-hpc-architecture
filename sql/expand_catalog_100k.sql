BEGIN;

ALTER TABLE productos ADD COLUMN IF NOT EXISTS principio_activo VARCHAR(80) NOT NULL DEFAULT 'PARACETAMOL';
ALTER TABLE productos ADD COLUMN IF NOT EXISTS presentacion VARCHAR(80) NOT NULL DEFAULT 'CAJA X 30 COMPRIMIDOS';
ALTER TABLE productos ADD COLUMN IF NOT EXISTS requiere_receta BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS descuento_max_pct NUMERIC(5,2) NOT NULL DEFAULT 5.00;
ALTER TABLE pedidos_ecommerce ADD COLUMN IF NOT EXISTS ip_origen VARCHAR(45) NOT NULL DEFAULT '127.0.0.1';
ALTER TABLE pedidos_ecommerce ADD COLUMN IF NOT EXISTS filtro_busqueda VARCHAR(140) NOT NULL DEFAULT 'DIRECT_CRUD';

-- Actualizar los primeros 50,000 registros con variedad de principios activos y presentaciones
UPDATE productos
SET
    principio_activo = (ARRAY[
        'PARACETAMOL', 'IBUPROFENO', 'AMOXICILINA', 'AZITROMICINA', 'LOSARTAN',
        'ATORVASTATINA', 'OMEPRAZOL', 'METFORMINA', 'ENALAPRIL', 'CETIRIZINA',
        'NAPROXENO', 'DEXAMETASONA', 'CLONAZEPAM', 'SALBUTAMOL', 'CIPROFLOXACINO',
        'PREGABALINA', 'TELMISARTAN', 'ROSUVASTATINA', 'ESOMEPRAZOL', 'LEVOFLOXACINO',
        'SERTRALINA', 'FLUOXETINA', 'MELOXICAM', 'CELECOXIB', 'CLARITROMICINA'
    ])[1 + (id_producto % 25)],
    presentacion = (ARRAY[
        'CAJA X 30 TABLETAS RECUBIERTAS', 'CAJA X 100 COMPRIMIDOS', 'FRASCO JARABE 120ML',
        'AMPOLLA INYECTABLE 5ML', 'SOBRE GRANULADO EFERVESCENTE', 'INHALADOR 200 DOSIS',
        'CAPSULAS BLANDAS X 20', 'GOTAS OFTALMICAS 15ML'
    ])[1 + (id_producto % 8)],
    requiere_receta = ((id_producto % 3) = 0),
    descuento_max_pct = ROUND(((id_producto % 25) * 1.25)::numeric, 2)
WHERE principio_activo = 'PARACETAMOL';

-- Insertar 50,000 nuevos productos adicionales (llegando a ~100,000 SKUs)
INSERT INTO productos (
    codigo_barras, nombre, precio_base, stock_actual, categoria,
    id_sucursal, laboratorio, principio_activo, presentacion, requiere_receta, descuento_max_pct
)
SELECT
    '775' || LPAD((200000000 + g)::text, 9, '0') AS codigo_barras,
    (ARRAY[
        'Telmisartán', 'Rosuvastatina', 'Esomeprazol', 'Levofloxacino', 'Sertralina',
        'Fluoxetina', 'Meloxicam', 'Celecoxib', 'Claritromicina', 'Montelukast',
        'Budesonida', 'Insulina Glargina', 'Sitagliptina', 'Empagliflozina', 'Bisoprolol',
        'Amlodipino', 'Valsartán', 'Clopidogrel', 'Rivaroxabán', ' Tamsulosina',
        'Finasterida', 'Ketorolaco', 'Tramadol', 'Gabapentina', 'Quetiapina'
    ])[1 + (g % 25)] || ' ' ||
    (ARRAY['5mg', '10mg', '20mg', '40mg', '50mg', '75mg', '100mg', '500mg'])[1 + (g % 8)] || ' · ' ||
    (ARRAY['Caja x 30', 'Caja x 60', 'Pack Clínico x 100', 'Frasco Suspensión', 'Pluma Prellenada', 'Blíster x 14'])[1 + (g % 6)] ||
    ' [SKU-' || (50000 + g) || ']' AS nombre,
    ROUND((6.80 + ((g * 19) % 240) + ((g % 95) * 0.10))::numeric, 2) AS precio_base,
    80 + ((g * 29) % 3200) AS stock_actual,
    (ARRAY[
        'CARDIOLOGIA', 'NEUROLOGIA', 'ENDOCRINOLOGIA', 'ANTIBIOTICOS',
        'GASTROENTEROLOGIA', 'RESPIRATORIO', 'ANALGESICOS', 'ONCOLOGIA_SOPORTE'
    ])[1 + (g % 8)] AS categoria,
    1 + (g % 12) AS id_sucursal,
    (ARRAY['ROCHE', 'PFIZER', 'BAYER', 'SANOFI', 'NOVARTIS', 'MEDIFARMA', 'HERSIL', 'BAGÓ'])[1 + (g % 8)] AS laboratorio,
    (ARRAY[
        'TELMISARTAN', 'ROSUVASTATINA', 'ESOMEPRAZOL', 'LEVOFLOXACINO', 'SERTRALINA',
        'FLUOXETINA', 'MELOXICAM', 'CELECOXIB', 'CLARITROMICINA', 'MONTELUKAST',
        'BUDESONIDA', 'INSULINA', 'SITAGLIPTINA', 'EMPAGLIFLOZINA', 'BISOPROLOL',
        'AMLODIPINO', 'VALSARTAN', 'CLOPIDOGREL', 'RIVAROXABAN', 'TAMSULOSINA',
        'FINASTERIDA', 'KETOROLACO', 'TRAMADOL', 'GABAPENTINA', 'QUETIAPINA'
    ])[1 + (g % 25)] AS principio_activo,
    (ARRAY[
        'CAJA X 30 TABLETAS RECUBIERTAS', 'CAJA X 100 COMPRIMIDOS', 'FRASCO JARABE 120ML',
        'AMPOLLA INYECTABLE 5ML', 'SOBRE GRANULADO EFERVESCENTE', 'INHALADOR 200 DOSIS'
    ])[1 + (g % 6)] AS presentacion,
    ((g % 2) = 0) AS requiere_receta,
    ROUND(((g % 30) * 1.15)::numeric, 2) AS descuento_max_pct
FROM generate_series(1, 50000) AS g
ON CONFLICT (codigo_barras) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_prod_busqueda_compuesta
ON productos(categoria, principio_activo, id_sucursal, precio_base);

COMMIT;
ANALYZE productos;
