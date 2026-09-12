
-- 01_schema.sql - Esquema Relacional Base (Farma HPC Core)
-- Ejecutar en PostgreSQL 18 (Nodo Maestro)

-- 1. Tabla de Sucursales
CREATE TABLE IF NOT EXISTS sucursales (
    id_sucursal SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion TEXT,
    ip_tailscale VARCHAR(45),
    activa BOOLEAN DEFAULT TRUE,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Catálogo Central de Productos
CREATE TABLE IF NOT EXISTS productos (
    id_producto SERIAL PRIMARY KEY,
    codigo_barras VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    precio_base DECIMAL(10, 2) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Control de Inventario por Sucursal
CREATE TABLE IF NOT EXISTS inventario_sucursal (
    id_inventario SERIAL PRIMARY KEY,
    id_sucursal INT REFERENCES sucursales(id_sucursal),
    id_producto INT REFERENCES productos(id_producto),
    stock_actual INT DEFAULT 0,
    stock_minimo INT DEFAULT 10,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_sucursal_producto UNIQUE (id_sucursal, id_producto)
);

-- 4. Registro Consolidado de Ventas (Sincronizado desde POS Offline)
CREATE TABLE IF NOT EXISTS ventas_consolidado (
    id_venta SERIAL PRIMARY KEY,
    uuid_venta_local VARCHAR(64) UNIQUE NOT NULL,
    -- UUID de transacción local en SQLite
    id_sucursal INT REFERENCES sucursales(id_sucursal),
    monto_total DECIMAL(10, 2) NOT NULL,
    metodo_pago VARCHAR(30) DEFAULT 'EFECTIVO',
    fecha_venta TIMESTAMP NOT NULL,
    sincronizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Tabla de Métricas Analíticas Avanzadas (Calculadas por C++ / OpenMPI)
CREATE TABLE IF NOT EXISTS metricas_analiticas_orda (
    id_metrica SERIAL PRIMARY KEY,
    id_sucursal INT REFERENCES sucursales(id_sucursal),
    fecha_calculo DATE NOT NULL,
    orda_score DECIMAL(8, 4),
    -- Resultado del cómputo paralelo
    pxt_cumplimiento DECIMAL(5, 2),
    procesado_por_nodo VARCHAR(50)
    -- Ejemplo: 'Lenovo_N4020' o 'i7_WSL2_Worker'
);
