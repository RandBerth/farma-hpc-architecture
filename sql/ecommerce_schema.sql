ALTER TABLE productos ADD COLUMN IF NOT EXISTS stock_actual INTEGER NOT NULL DEFAULT 500;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS categoria VARCHAR(80) NOT NULL DEFAULT 'FARMACIA_CLINICA';

CREATE TABLE IF NOT EXISTS pedidos_ecommerce (
    id_pedido SERIAL PRIMARY KEY,
    operacion_crud VARCHAR(25) NOT NULL,
    id_producto INTEGER NOT NULL,
    documento_cliente VARCHAR(20) NOT NULL,
    token_sha256 VARCHAR(64) NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL,
    monto_igv NUMERIC(12, 2) NOT NULL,
    monto_total NUMERIC(12, 2) NOT NULL,
    amenazas_sql_neutralizadas INTEGER NOT NULL DEFAULT 0,
    nodo_ejecutor VARCHAR(80) NOT NULL,
    estado_green_it VARCHAR(60) NOT NULL,
    latencia_total_ms DOUBLE PRECISION NOT NULL,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Poblar catálogo base si tiene menos de 5 productos para pruebas CRUD reales
INSERT INTO productos (codigo_barras, nombre, precio_base, stock_actual, categoria)
VALUES
    ('775100200301', 'Paracetamol 500mg Caja x 100 Tabs', 12.50, 1500, 'ANALGESICOS'),
    ('775100200302', 'Amoxicilina 500mg + Ac. Clavulánico x 30', 38.90, 950, 'ANTIBIOTICOS'),
    ('775100200303', 'Losartán Potásico 50mg Caja x 60', 24.00, 1200, 'CARDIOLOGIA'),
    ('775100200304', 'Atorvastatina 20mg Blíster x 30', 19.50, 1100, 'CARDIOLOGIA'),
    ('775100200305', 'Omeprazol 20mg Cápsulas Liberación Prol.', 15.80, 1800, 'GASTROENTEROLOGIA'),
    ('775100200306', 'Azitromicina 500mg Pack Rescate x 15', 29.90, 800, 'ANTIBIOTICOS')
ON CONFLICT (codigo_barras) DO UPDATE
SET stock_actual = GREATEST(productos.stock_actual, 500);
