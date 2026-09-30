from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List
import psycopg2
from psycopg2.extras import RealDictCursor


app = FastAPI()


# Configuración de la base de datos
DB_CONFIG = {
    "dbname": "farma_db",
    "user": "postgres",
    "password": "TuPasswordSeguro123",
    "host": "localhost",
    "port": "5432",
}


def get_db_connection():
    try:
        conn = psycopg2.connect(
            **DB_CONFIG,
            cursor_factory=RealDictCursor
        )
        return conn
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )


# Modelo para registrar ventas
class VentaItem(BaseModel):
    id_venta: str
    id_sucursal: int
    id_tecnico: int
    monto_total: float
    metodo_pago: str
    fecha_hora: str


# Ruta principal
@app.get("/")
def read_root():
    return {
        "status": "online",
        "nodo": "Master"
    }


# Listar productos
@app.get("/productos")
def listar_productos():
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("""
            SELECT
                id_producto,
                codigo_barras,
                nombre,
                descripcion,
                precio_base
            FROM productos;
        """)

        productos = cursor.fetchall()

        return {
            "total": len(productos),
            "data": productos
        }

    finally:
        cursor.close()
        conn.close()


# Sincronizar ventas
@app.post("/sincronizar/venta")
def registrar_venta(ventas: List[VentaItem]):
    conn = get_db_connection()
    cursor = conn.cursor()

    registrados = 0

    try:
        for v in ventas:
            cursor.execute("""
                INSERT INTO ventas_consolidado (
                    id_venta,
                    id_sucursal,
                    id_tecnico,
                    monto_total,
                    metodo_pago,
                    fecha_hora
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (id_venta) DO NOTHING;
            """, (
                v.id_venta,
                v.id_sucursal,
                v.id_tecnico,
                v.monto_total,
                v.metodo_pago,
                v.fecha_hora
            ))

            registrados += cursor.rowcount

        conn.commit()

    except Exception as e:
        conn.rollback()

        raise HTTPException(
            status_code=400,
            detail=str(e)
        )

    finally:
        cursor.close()
        conn.close()

    return {
        "status": "ok",
        "ventas_procesadas": registrados
    }
