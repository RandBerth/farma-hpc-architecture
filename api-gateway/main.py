import logging
import os
import subprocess
import time
from pathlib import Path
from typing import Optional
import psycopg2
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.responses import FileResponse
import app.database as db_module
from app.database import reader_cursor, writer_cursor
from app.green_it import wake_on_lan
from app.hpc_runner import run_hpc_engine, get_real_slave_cpu_per_core, run_empirical_calibration
from app.ecommerce_gateway import (
    ejecutar_operacion_gateway_crud,
    ejecutar_busqueda_masiva_catalogo,
    controlar_trafico_continuo,
    obtener_resumen_ecommerce,
    configurar_politica_green_it,
    comparar_cuello_botella_io_en_vivo,
    _TRAFFIC_DAEMON,
)
from app.schemas import (
    ProductoCreate,
    OrdaRequest,
    SanitizarLoteRequest,
    EcommerceCrudRequest,
    BusquedaMasivaRequest,
    GreenItPolicyRequest,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

STATIC_INDEX = Path(__file__).resolve().parent / "static" / "index.html"

app = FastAPI(
    title="Farma HPC Gateway — Micro-Batching, Búsqueda Masiva MPI & Analítica",
    version="6.0.0",
)


@app.get("/", include_in_schema=False)
def serve_dashboard():
    return FileResponse(
        STATIC_INDEX,
        headers={"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"},
    )


@app.get("/health", tags=["Infraestructura"])
def health_check():
    return {"status": "online", "service": "Farma HPC Unified Gateway", "daemon_trafico": _TRAFFIC_DAEMON}


@app.get("/infraestructura/telemetria", tags=["Infraestructura"])
def obtener_telemetria():
    load_1m = os.getloadavg()[0] if hasattr(os, "getloadavg") else 0.0
    cb_activo = time.monotonic() < getattr(db_module, "_slave_down_until", 0.0)
    return {
        "cpu_cores": os.cpu_count() or 2,
        "load_1m": round(load_1m, 2),
        "circuit_breaker_activo": cb_activo,
        "daemon_trafico": _TRAFFIC_DAEMON,
    }


@app.get("/infraestructura/cpu-real", tags=["Infraestructura"])
def obtener_cpu_real_esclavo():
    res = get_real_slave_cpu_per_core()
    res["daemon_activo"] = _TRAFFIC_DAEMON["activo"]
    res["olas_enviadas"] = _TRAFFIC_DAEMON["olas_enviadas"]
    return res


@app.get("/ecommerce/estado", tags=["Gateway Micro-Batching & Búsqueda Masiva"])
def estado_ecommerce_gateway():
    try:
        data = obtener_resumen_ecommerce()
        data["daemon_trafico"] = _TRAFFIC_DAEMON
        return data
    except psycopg2.Error as exc:
        raise HTTPException(status_code=503, detail=f"Error en PostgreSQL: {exc}") from exc


@app.post("/ecommerce/green-it/modo", tags=["Gateway Micro-Batching & Búsqueda Masiva"])
def cambiar_politica_green_it(payload: GreenItPolicyRequest):
    return configurar_politica_green_it(payload.modo_politica)


@app.post("/ecommerce/crud", tags=["Gateway Micro-Batching & Búsqueda Masiva"])
def procesar_crud_ecommerce(payload: EcommerceCrudRequest):
    try:
        return ejecutar_operacion_gateway_crud(payload)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/ecommerce/busqueda-masiva", tags=["Gateway Micro-Batching & Búsqueda Masiva"])
def procesar_busqueda_masiva(payload: BusquedaMasivaRequest, request: Request):
    client_ip = request.client.host if request.client else "100.66.197.8"
    try:
        return ejecutar_busqueda_masiva_catalogo(payload, client_ip=client_ip)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/ecommerce/trafico-continuo", tags=["Gateway Micro-Batching & Búsqueda Masiva"])
def toggle_trafico_continuo(activar: bool = True):
    return controlar_trafico_continuo(activar=activar)


@app.post("/ecommerce/comparar-io", tags=["Gateway Micro-Batching & Búsqueda Masiva"])
def comparar_io_postgresql(tamano_lote: int = 500):
    try:
        return comparar_cuello_botella_io_en_vivo(tamano_lote=tamano_lote)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/productos", tags=["Catálogo (Read Splitting -> Slave)"])
def listar_productos():
    with reader_cursor() as cursor:
        cursor.execute(
            "SELECT id_producto, codigo_barras, nombre, principio_activo, laboratorio, precio_base, stock_actual, categoria FROM productos ORDER BY id_producto DESC LIMIT 200;"
        )
        res = cursor.fetchall()
    return {"total": len(res), "data": res}


@app.get("/analitica/historial", tags=["Supercómputo HPC"])
def listar_historial_orda():
    with reader_cursor() as cursor:
        cursor.execute(
            """
            SELECT id_metrica, modo_ejecucion, nodos_mpi, hilos_openmp,
                   total_transacciones, total_pacientes, orda_acumulado,
                   pxt_promedio, tiempo_secuencial_ms, tiempo_paralelo_ms,
                   speedup, eficiencia, fecha_calculo
            FROM metricas_analiticas_orda
            ORDER BY id_metrica DESC
            LIMIT 15;
            """
        )
        filas = cursor.fetchall()
    return {"total": len(filas), "data": filas}


@app.post("/analitica/calibrar", tags=["Supercómputo HPC"])
def calibrar_metricas_recomendadas(payload: Optional[OrdaRequest] = None):
    ops = payload.operaciones if payload and payload.operaciones else ["ORDA", "PXT", "SANITIZER"]
    return run_empirical_calibration(operaciones=ops)


def _persistir_ejecucion_hpc(metricas: dict, tecnicos_activos: int):
    registro_db = {}
    try:
        with writer_cursor() as (_, cursor):
            modo_tag = f"{metricas['modo_ejecucion']} [{metricas.get('operaciones_ejecutadas', 'ORDA')}]"[:155]
            cursor.execute(
                """
                INSERT INTO metricas_analiticas_orda (
                    modo_ejecucion, nodos_mpi, hilos_openmp,
                    total_transacciones, total_pacientes,
                    orda_acumulado, pxt_promedio,
                    tiempo_secuencial_ms, tiempo_paralelo_ms,
                    speedup, eficiencia
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id_metrica, fecha_calculo;
                """,
                (
                    modo_tag,
                    metricas["nodos_mpi"],
                    metricas["hilos_openmp"],
                    metricas["total_transacciones"],
                    metricas["total_pacientes"],
                    metricas["orda_acumulado"],
                    metricas["pxt_promedio"],
                    metricas["tiempo_secuencial_ms"],
                    metricas["tiempo_paralelo_ms"],
                    metricas["speedup"],
                    metricas["eficiencia"],
                ),
            )
            registro_db = cursor.fetchone()
    except psycopg2.Error as exc:
        registro_db = {"id_metrica": None, "warning": str(exc)}
    return registro_db


@app.post("/analitica/ejecutar-orda", tags=["Supercómputo HPC"])
def ejecutar_computo_paralelo(payload: Optional[OrdaRequest] = None):
    req = payload or OrdaRequest()
    wake_on_lan()
    metricas = run_hpc_engine(
        num_registros=req.num_registros,
        hilos_openmp=req.hilos_openmp,
        tecnicos_activos=req.tecnicos_activos,
        horas_trabajadas=req.horas_trabajadas,
        use_mpi=req.forzar_mpi,
        operaciones=req.operaciones,
    )
    registro_db = _persistir_ejecucion_hpc(metricas, req.tecnicos_activos)
    return {
        "status": "success",
        "modo": metricas["modo_ejecucion"],
        "output": metricas,
        "persistencia": registro_db,
    }
from app.ecommerce_gateway import (
    obtener_telemetria_atacante_wan,
    disparar_ataque_regulado_wan,
    controlar_ataque_continuo_wan,
)
from app.schemas import AtaqueWanRequest


@app.get("/atacante/estado", tags=["Nodo Atacante WAN (100.66.197.8)"])
def estado_nodo_atacante():
    return obtener_telemetria_atacante_wan()


@app.post("/atacante/ejecutar-regulado", tags=["Nodo Atacante WAN (100.66.197.8)"])
def ejecutar_ataque_regulado(payload: AtaqueWanRequest):
    return disparar_ataque_regulado_wan(payload)


@app.post("/atacante/control-continuo", tags=["Nodo Atacante WAN (100.66.197.8)"])
def controlar_ataque_continuo(payload: AtaqueWanRequest):
    return controlar_ataque_continuo_wan(payload)
