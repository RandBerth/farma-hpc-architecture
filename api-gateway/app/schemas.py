from typing import List, Optional
from pydantic import BaseModel, Field


class ProductoCreate(BaseModel):
    codigo_barras: str = Field(..., min_length=3, max_length=64)
    nombre: str = Field(..., min_length=2, max_length=255)
    precio_base: float = Field(..., ge=0.0)


class OrdaRequest(BaseModel):
    num_registros: int = Field(default=20000000, ge=1000, le=100000000)
    hilos_openmp: int = Field(default=16, ge=1, le=64)
    tecnicos_activos: int = Field(default=45, ge=1, le=1000)
    horas_trabajadas: float = Field(default=360.0, ge=1.0, le=100000.0)
    forzar_mpi: bool = Field(default=False)
    operaciones: List[str] = Field(default_factory=lambda: ["ORDA"])


class SanitizarLoteRequest(BaseModel):
    num_registros: int = Field(default=10000000, ge=1000, le=100000000)
    hilos_openmp: int = Field(default=16, ge=1, le=64)
    forzar_mpi: bool = Field(default=True)


class EcommerceCrudRequest(BaseModel):
    token_autorizacion: str = Field(default="FARMA-ECOM-2026-AUTH-KEY", min_length=8, max_length=128)
    operacion_crud: str = Field(default="CREATE", pattern="^(CREATE|READ|UPDATE|DELETE)$")
    id_producto: int = Field(default=1, ge=1)
    documento_cliente: str = Field(default="74859612", min_length=8, max_length=64)
    cantidad_por_op: int = Field(default=1, ge=1, le=500)
    tamano_micro_lote: int = Field(default=500, ge=10, le=10000)
    volumen_lote_mpi: int = Field(default=5000000, ge=10000, le=40000000)
    usar_mpi: bool = Field(default=True)
    payload_filtro_raw: Optional[str] = Field(default="MICRO_BATCH_INGESTION_PIPELINE")


class BusquedaMasivaRequest(BaseModel):
    token_autorizacion: str = Field(default="FARMA-ECOM-2026-AUTH-KEY", min_length=8, max_length=128)
    nodo_origen: str = Field(default="DESKTOP-PF7PD6U (100.66.197.8)")
    termino_busqueda: str = Field(default="PARACETAMOL")
    categoria: Optional[str] = Field(default=None)
    id_sucursal: Optional[int] = Field(default=None)
    precio_min: float = Field(default=1.0, ge=0.0)
    precio_max: float = Field(default=250.0, ge=1.0)
    stock_minimo: int = Field(default=50, ge=0)
    consultas_agrupadas: int = Field(default=600, ge=10, le=5000)
    volumen_scoring_mpi: int = Field(default=18000000, ge=500000, le=60000000)
    usar_mpi: bool = Field(default=True)


class GreenItPolicyRequest(BaseModel):
    modo_politica: str = Field(default="AUTO_PROGRESIVO", pattern="^(AUTO_PROGRESIVO|SOLO_ESCLAVO_ACTIVO|FORZAR_ECO_MAESTRO)$")


class AtaqueWanRequest(BaseModel):
    activar: bool = Field(default=True)
    preset: str = Field(default="HARD")
    workers: int = Field(default=3, ge=1, le=8)
    num_olas: int = Field(default=6, ge=1, le=30)
    consultas_por_ola: int = Field(default=1200, ge=50, le=5000)
    volumen_mpi: int = Field(default=28000000, ge=1000000, le=60000000)
