import logging
import time
from contextlib import contextmanager
from typing import Generator, Tuple, Any
import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from app.config import settings

logger = logging.getLogger("farma_hpc.database")

_master_pool: pool.ThreadedConnectionPool | None = None
_slave_pool: pool.ThreadedConnectionPool | None = None
_slave_down_until: float = 0.0
SLAVE_COOLDOWN_SECONDS: float = 30.0


def _get_master_pool() -> pool.ThreadedConnectionPool:
    global _master_pool
    if _master_pool is None:
        _master_pool = pool.ThreadedConnectionPool(
            minconn=2,
            maxconn=25,
            dsn=settings.master_db_url,
            cursor_factory=RealDictCursor,
        )
    return _master_pool


def _get_slave_pool() -> pool.ThreadedConnectionPool:
    global _slave_pool
    if _slave_pool is None:
        _slave_pool = pool.ThreadedConnectionPool(
            minconn=1,
            maxconn=25,
            dsn=settings.slave_db_url,
            cursor_factory=RealDictCursor,
            connect_timeout=1,
        )
    return _slave_pool


@contextmanager
def writer_cursor() -> Generator[Tuple[Any, Any], None, None]:
    """Obtiene conexión del Pool Maestro para escrituras transaccionales."""
    master_pool = _get_master_pool()
    conn = master_pool.getconn()
    try:
        with conn.cursor() as cursor:
            yield conn, cursor
        conn.commit()
    except psycopg2.Error:
        conn.rollback()
        raise
    finally:
        master_pool.putconn(conn)


@contextmanager
def reader_cursor() -> Generator[Any, None, None]:
    """Lee del Pool Esclavo; si está apagado (Green IT), activa Circuit Breaker y usa el Pool Maestro en <1ms."""
    global _slave_down_until
    now = time.monotonic()

    if now >= _slave_down_until:
        try:
            slave_pool = _get_slave_pool()
            conn = slave_pool.getconn()
            try:
                with conn.cursor() as cursor:
                    yield cursor
                return
            finally:
                slave_pool.putconn(conn)
        except psycopg2.Error as exc:
            _slave_down_until = now + SLAVE_COOLDOWN_SECONDS
            logger.warning(
                "Nodo Esclavo en ahorro de energía (%s). Circuit Breaker activo por %ds -> Usando Pool Maestro.",
                exc,
                int(SLAVE_COOLDOWN_SECONDS),
            )

    master_pool = _get_master_pool()
    conn = master_pool.getconn()
    try:
        with conn.cursor() as cursor:
            yield cursor
    finally:
        master_pool.putconn(conn)
