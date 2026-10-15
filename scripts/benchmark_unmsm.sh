#!/usr/bin/env bash
set -euo pipefail

BINARY="/usr/local/bin/motor_hpc_farma"
RECORDS=1000000
TECNICOS=45

echo "=================================================================="
echo "  1. MEDICIÓN DE SPEEDUP (S) Y TIEMPO CON LINUX 'time' (< 3.0s)"
echo "  Registros: ${RECORDS} | Alineación Cache L1: alignas(64)"
echo "=================================================================="

for THREADS in 1 2 4 8 16; do
    echo ""
    echo ">>> Ejecutando con N_hilos = ${THREADS} (OpenMP)..."
    /usr/bin/time -p "${BINARY}" "${RECORDS}" "${THREADS}" "${TECNICOS}"
done

echo ""
echo "=================================================================="
echo "  2. TASA DE FALLOS DE CACHÉ (Objetivo UNMSM: < 5.0% Miss Rate)"
echo "=================================================================="
if command -v perf &> /dev/null; then
    sudo perf stat -e cache-references,cache-misses,L1-dcache-loads,cycles,instructions \
        "${BINARY}" "${RECORDS}" 16 "${TECNICOS}" || true
fi

echo ""
echo "=================================================================="
echo "  3. LATENCIA API GATEWAY CON APACHE BENCHMARK (Objetivo: < 100ms)"
echo "=================================================================="
if command -v ab &> /dev/null; then
    # Petición inicial para activar el Pool y el Circuit Breaker si el Esclavo está apagado
    curl -s "http://127.0.0.1:8000/productos" > /dev/null
    ab -n 200 -c 20 "http://127.0.0.1:8000/productos" | grep -E "Requests per second|Time per request|50%|95%|99%"
fi
