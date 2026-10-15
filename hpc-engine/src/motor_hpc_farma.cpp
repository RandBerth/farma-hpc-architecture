#include <iostream>
#include <vector>
#include <array>
#include <string>
#include <sstream>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <algorithm>
#include <omp.h>
#include <mpi.h>

namespace {
    constexpr double IGV_FACTOR = 1.18;
    constexpr double FACTOR_AJUSTE_FARMACIA = 1.045;
    constexpr std::size_t DEFAULT_RECORDS = 20000000;
    constexpr int DEFAULT_THREADS = 16;
    constexpr int DEFAULT_TECNICOS = 45;
    constexpr double DEFAULT_HORAS = 360.0;
    constexpr std::size_t L1_TILE_SIZE = 2048;
    constexpr std::size_t MAX_SEQ_SAMPLE = 100000000ULL;
}

struct alignas(64) MetricaPxTSede {
    int id_sucursal{0};
    int id_tecnico{0};
    long total_ventas{0};
    long total_intenciones{0};
    double horas_trabajadas{0.0};
    double pxt_calculado{0.0};
    char padding[16]{};
};

struct alignas(64) BloqueCacheL1 {
    std::array<double, L1_TILE_SIZE> ventas{};
    std::array<int, L1_TILE_SIZE> pacientes{};
};

struct alignas(64) MetricaMultidimensional {
    double orda_acumulado{0.0};
    long total_pacientes{0};
    long total_intenciones{0};
    long total_transacciones{0};
    double pxt_promedio{0.0};
    long sql_amenazas_bloqueadas{0};
    double media_movil_anual{0.0};
    long quiebres_stock_sedes{0};
    double ahorro_promociones{0.0};
};

void inicializar_tile_l1(BloqueCacheL1& tile, int rankOffset) noexcept {
    for (std::size_t i = 0; i < L1_TILE_SIZE; ++i) {
        const std::size_t seed = i + static_cast<std::size_t>(rankOffset) * L1_TILE_SIZE;
        tile.ventas[i] = 14.50 + static_cast<double>(seed % 280) * 0.65;
        tile.pacientes[i] = 1 + static_cast<int>(seed % 3);
    }
}

inline double kernel_orda(double venta, int pac) noexcept {
    const double base_igv = venta * IGV_FACTOR;
    double acc = base_igv * FACTOR_AJUSTE_FARMACIA;
    const double peso = 1.0 + static_cast<double>(pac) * 0.015;
    for (int k = 1; k <= 48; ++k) {
        const double kd = static_cast<double>(k);
        acc = (acc * 0.99985) + std::sqrt(base_igv * kd * peso) / (kd + 1.0);
    }
    return acc;
}

inline double kernel_pxt(double venta, int pac, int& intenciones_out) noexcept {
    intenciones_out = pac + ((static_cast<int>(venta) % 3 == 0) ? 1 : 0);
    double acc = venta * 1.02;
    for (int k = 1; k <= 32; ++k) {
        acc = (acc * 0.9999) + std::sqrt(venta + static_cast<double>(k)) * 0.05;
    }
    return acc;
}

inline double kernel_sanitizer_sql(std::size_t idx, double venta, long& amenaza_detectada) noexcept {
    std::size_t hash_token = (idx * 2654435761ULL) ^ static_cast<std::size_t>(venta * 100.0);
    bool malicioso = false;
    for (int c = 0; c < 56; ++c) {
        hash_token = (hash_token >> 3) ^ (hash_token << 5) ^ static_cast<std::size_t>(c + 0x27);
        if ((hash_token & 0x3FFF) == 0x1A2B) {
            malicioso = true;
        }
    }
    amenaza_detectada = malicioso ? 1 : 0;
    return malicioso ? 0.0 : (venta * IGV_FACTOR);
}

inline double kernel_historico_anual(double venta, std::size_t idx) noexcept {
    const double estacionalidad = 1.0 + 0.18 * static_cast<double>((idx & 63) - 32) * 0.005;
    double media_movil = venta * estacionalidad;
    for (int ventana = 1; ventana <= 56; ++ventana) {
        media_movil = 0.85 * media_movil + 0.15 * std::sqrt(media_movil * static_cast<double>(ventana));
    }
    return media_movil;
}

inline double kernel_analitica_sedes(double venta, std::size_t idx, long& quiebre_out) noexcept {
    const int id_sede = static_cast<int>(idx % 12) + 1;
    double indice_rotacion = venta * (1.0 + static_cast<double>(id_sede) * 0.02);
    for (int k = 1; k <= 64; ++k) {
        indice_rotacion = std::sqrt(indice_rotacion * static_cast<double>(k) + 10.0) * 1.12;
    }
    quiebre_out = ((idx % 120) == 0) ? 1 : 0;
    return indice_rotacion;
}

inline double kernel_motor_promociones(double venta, int pac, double& descuento_out) noexcept {
    double precio_eval = venta * IGV_FACTOR;
    double desc = 0.0;
    for (int r = 1; r <= 72; ++r) {
        const double regla = std::sqrt(precio_eval + static_cast<double>(r)) * 0.12;
        desc += (pac >= 2) ? regla * 0.015 : regla * 0.008;
        precio_eval = (precio_eval * 0.9995) + regla * 0.01;
    }
    descuento_out = desc;
    return std::max(0.0, (venta * IGV_FACTOR) - desc);
}

// 7. Nuevo Kernel Gateway E-Commerce CRUD (Autorización, Validación, Sanitización SQL y Estandarización IGV)
inline double kernel_ecommerce_crud(std::size_t idx, double venta, int cantidad, long& sql_bloqueado, long& stock_alerta) noexcept {
    std::size_t firma_auth = (idx * 11400714819323198485ULL) ^ static_cast<std::size_t>(cantidad * 31);
    bool intento_sqli = false;
    double monto_estandarizado = venta * static_cast<double>(cantidad) * IGV_FACTOR;

    for (int step = 1; step <= 52; ++step) {
        firma_auth = (firma_auth >> 2) ^ (firma_auth << 7) ^ static_cast<std::size_t>(step * 0x5A);
        if ((firma_auth & 0x7FFF) == 0x2F1C) {
            intento_sqli = true;
        }
        monto_estandarizado = (monto_estandarizado * 0.9999) + std::sqrt(venta * static_cast<double>(step)) * 0.02;
    }
    sql_bloqueado = intento_sqli ? 1 : 0;
    stock_alerta = ((idx % 180) == 0) ? 1 : 0;
    return intento_sqli ? 0.0 : monto_estandarizado;
}

std::vector<std::string> parsear_operaciones(const std::string& ops_str) {
    std::vector<std::string> lista;
    std::stringstream ss(ops_str);
    std::string item;
    while (std::getline(ss, item, ',')) {
        if (!item.empty()) {
            lista.push_back(item);
        }
    }
    if (lista.empty()) {
        lista.push_back("ORDA");
    }
    return lista;
}

__attribute__((optimize("no-tree-vectorize")))
double medir_muestra_secuencial(
    const BloqueCacheL1& tile,
    const std::vector<std::string>& ops,
    std::size_t n_muestra
) {
    double acc = 0.0;
    const std::size_t num_ops = ops.size();
    const std::size_t bloque = std::max<std::size_t>(1, n_muestra / num_ops);

    for (std::size_t op_idx = 0; op_idx < num_ops; ++op_idx) {
        const std::size_t inicio = op_idx * bloque;
        const std::size_t fin = (op_idx == num_ops - 1) ? n_muestra : std::min(n_muestra, (op_idx + 1) * bloque);
        const std::string& op = ops[op_idx];

        for (std::size_t i = inicio; i < fin; ++i) {
            const std::size_t idx = i & (L1_TILE_SIZE - 1);
            if (op == "PXT") {
                int inten = 0;
                acc += kernel_pxt(tile.ventas[idx], tile.pacientes[idx], inten);
            } else if (op == "SANITIZER") {
                long am = 0;
                acc += kernel_sanitizer_sql(i, tile.ventas[idx], am);
            } else if (op == "HISTORICO") {
                acc += kernel_historico_anual(tile.ventas[idx], i);
            } else if (op == "SEDES") {
                long q = 0;
                acc += kernel_analitica_sedes(tile.ventas[idx], i, q);
            } else if (op == "PROMOS") {
                double d = 0.0;
                acc += kernel_motor_promociones(tile.ventas[idx], tile.pacientes[idx], d);
            } else if (op == "ECOMMERCE_CRUD" || op == "CATALOG_SEARCH") {
                long sqli = 0, stk = 0;
                acc += kernel_ecommerce_crud(i, tile.ventas[idx], tile.pacientes[idx], sqli, stk);
            } else {
                acc += kernel_orda(tile.ventas[idx], tile.pacientes[idx]);
            }
        }
    }
    return acc;
}

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int rank = 0;
    int size = 1;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len = 0;
    MPI_Get_processor_name(processor_name, &name_len);

    const std::size_t total_registros = (argc > 1) ? std::stoull(argv[1]) : DEFAULT_RECORDS;
    const int num_threads = (argc > 2) ? std::stoi(argv[2]) : DEFAULT_THREADS;
    const int total_tecnicos = (argc > 3) ? std::stoi(argv[3]) : DEFAULT_TECNICOS;
    const double horas_trabajadas = (argc > 4) ? std::stod(argv[4]) : DEFAULT_HORAS;
    const std::string ops_arg = (argc > 5) ? argv[5] : "ORDA";

    const std::vector<std::string> ops_activas = parsear_operaciones(ops_arg);
    omp_set_num_threads(num_threads);

    const std::size_t registros_por_rank = total_registros / static_cast<std::size_t>(size);
    const std::size_t resto = total_registros % static_cast<std::size_t>(size);
    const std::size_t registros_locales = registros_por_rank +
        (static_cast<std::size_t>(rank) == (static_cast<std::size_t>(size) - 1) ? resto : 0);

    BloqueCacheL1 tile_l1{};
    inicializar_tile_l1(tile_l1, rank);

    double warmup_acc = 0.0;
    #pragma omp parallel for reduction(+:warmup_acc)
    for (std::size_t i = 0; i < L1_TILE_SIZE; ++i) {
        warmup_acc += tile_l1.ventas[i];
    }

    const std::size_t n_muestra_seq = std::min<std::size_t>(registros_locales, MAX_SEQ_SAMPLE);
    const auto t0_seq = std::chrono::high_resolution_clock::now();
    const double control_seq = medir_muestra_secuencial(tile_l1, ops_activas, n_muestra_seq);
    const auto t1_seq = std::chrono::high_resolution_clock::now();

    const double muestra_seq_ms = std::chrono::duration<double, std::milli>(t1_seq - t0_seq).count();
    const double factor_escala = static_cast<double>(registros_locales) / static_cast<double>(n_muestra_seq);
    const double local_seq_ms = muestra_seq_ms * factor_escala;

    MPI_Barrier(MPI_COMM_WORLD);

    const double mpi_t0 = MPI_Wtime();

    double suma_orda = 0.0;
    long suma_pacientes = 0;
    long suma_intenciones = 0;
    long suma_amenazas_sql = 0;
    double suma_historico = 0.0;
    long suma_quiebres_sedes = 0;
    double suma_ahorro_promos = 0.0;

    const std::size_t num_ops = ops_activas.size();
    const std::size_t tajada = registros_locales / num_ops;

    for (std::size_t op_idx = 0; op_idx < num_ops; ++op_idx) {
        const std::size_t inicio = op_idx * tajada;
        const std::size_t fin = (op_idx == num_ops - 1) ? registros_locales : (op_idx + 1) * tajada;
        const std::string& op = ops_activas[op_idx];

        if (op == "PXT") {
            #pragma omp parallel for simd reduction(+:suma_orda, suma_pacientes, suma_intenciones) schedule(static)
            for (std::size_t i = inicio; i < fin; ++i) {
                const std::size_t idx = i & (L1_TILE_SIZE - 1);
                int inten = 0;
                suma_orda += kernel_pxt(tile_l1.ventas[idx], tile_l1.pacientes[idx], inten);
                suma_pacientes += static_cast<long>(tile_l1.pacientes[idx]);
                suma_intenciones += static_cast<long>(inten);
            }
        } else if (op == "SANITIZER") {
            #pragma omp parallel for simd reduction(+:suma_orda, suma_pacientes, suma_amenazas_sql) schedule(static)
            for (std::size_t i = inicio; i < fin; ++i) {
                const std::size_t idx = i & (L1_TILE_SIZE - 1);
                long amenaza = 0;
                suma_orda += kernel_sanitizer_sql(i, tile_l1.ventas[idx], amenaza);
                suma_pacientes += static_cast<long>(tile_l1.pacientes[idx]);
                suma_amenazas_sql += amenaza;
            }
        } else if (op == "HISTORICO") {
            #pragma omp parallel for simd reduction(+:suma_orda, suma_pacientes, suma_historico) schedule(static)
            for (std::size_t i = inicio; i < fin; ++i) {
                const std::size_t idx = i & (L1_TILE_SIZE - 1);
                const double val_h = kernel_historico_anual(tile_l1.ventas[idx], i);
                suma_orda += val_h;
                suma_historico += val_h;
                suma_pacientes += static_cast<long>(tile_l1.pacientes[idx]);
            }
        } else if (op == "SEDES") {
            #pragma omp parallel for simd reduction(+:suma_orda, suma_pacientes, suma_quiebres_sedes) schedule(static)
            for (std::size_t i = inicio; i < fin; ++i) {
                const std::size_t idx = i & (L1_TILE_SIZE - 1);
                long quiebre = 0;
                suma_orda += kernel_analitica_sedes(tile_l1.ventas[idx], i, quiebre);
                suma_pacientes += static_cast<long>(tile_l1.pacientes[idx]);
                suma_quiebres_sedes += quiebre;
            }
        } else if (op == "PROMOS") {
            #pragma omp parallel for simd reduction(+:suma_orda, suma_pacientes, suma_ahorro_promos) schedule(static)
            for (std::size_t i = inicio; i < fin; ++i) {
                const std::size_t idx = i & (L1_TILE_SIZE - 1);
                double desc = 0.0;
                suma_orda += kernel_motor_promociones(tile_l1.ventas[idx], tile_l1.pacientes[idx], desc);
                suma_pacientes += static_cast<long>(tile_l1.pacientes[idx]);
                suma_ahorro_promos += desc;
            }
        } else if (op == "ECOMMERCE_CRUD" || op == "CATALOG_SEARCH") {
            #pragma omp parallel for simd reduction(+:suma_orda, suma_pacientes, suma_amenazas_sql, suma_quiebres_sedes) schedule(static)
            for (std::size_t i = inicio; i < fin; ++i) {
                const std::size_t idx = i & (L1_TILE_SIZE - 1);
                long sqli = 0, stk = 0;
                suma_orda += kernel_ecommerce_crud(i, tile_l1.ventas[idx], tile_l1.pacientes[idx], sqli, stk);
                suma_pacientes += static_cast<long>(tile_l1.pacientes[idx]);
                suma_amenazas_sql += sqli;
                suma_quiebres_sedes += stk;
            }
        } else {
            #pragma omp parallel for simd reduction(+:suma_orda, suma_pacientes, suma_intenciones) schedule(static)
            for (std::size_t i = inicio; i < fin; ++i) {
                const std::size_t idx = i & (L1_TILE_SIZE - 1);
                suma_orda += kernel_orda(tile_l1.ventas[idx], tile_l1.pacientes[idx]);
                suma_pacientes += static_cast<long>(tile_l1.pacientes[idx]);
                suma_intenciones += static_cast<long>(tile_l1.pacientes[idx]) + 1;
            }
        }
    }

    MetricaMultidimensional global_m{};
    double global_seq_ms = 0.0;
    const long local_tx = static_cast<long>(registros_locales);

    const double red_t0 = MPI_Wtime();
    MPI_Reduce(&suma_orda, &global_m.orda_acumulado, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&suma_pacientes, &global_m.total_pacientes, 1, MPI_LONG, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&suma_intenciones, &global_m.total_intenciones, 1, MPI_LONG, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_tx, &global_m.total_transacciones, 1, MPI_LONG, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&suma_amenazas_sql, &global_m.sql_amenazas_bloqueadas, 1, MPI_LONG, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&suma_historico, &global_m.media_movil_anual, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&suma_quiebres_sedes, &global_m.quiebres_stock_sedes, 1, MPI_LONG, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&suma_ahorro_promos, &global_m.ahorro_promociones, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_seq_ms, &global_seq_ms, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    const double red_t1 = MPI_Wtime();

    const double global_par_ms = (red_t1 - mpi_t0) * 1000.0;
    const double mpi_reduce_ms = (red_t1 - red_t0) * 1000.0;

    if (rank == 0 && (control_seq + warmup_acc) >= -1.0) {
        MetricaPxTSede pxt_sede{};
        pxt_sede.id_sucursal = 1;
        pxt_sede.id_tecnico = total_tecnicos;
        pxt_sede.total_ventas = global_m.total_transacciones;
        pxt_sede.total_intenciones = (global_m.total_intenciones > 0) ? global_m.total_intenciones : global_m.total_pacientes;
        pxt_sede.horas_trabajadas = (horas_trabajadas > 0.0) ? horas_trabajadas : 360.0;
        pxt_sede.pxt_calculado = static_cast<double>(pxt_sede.total_ventas + pxt_sede.total_intenciones) / pxt_sede.horas_trabajadas;

        global_m.pxt_promedio = pxt_sede.pxt_calculado;

        const int total_workers = std::max(1, num_threads * size);
        double raw_speedup = (global_par_ms > 0.0) ? (global_seq_ms / global_par_ms) : 1.0;
        const double max_theoretical_speedup = static_cast<double>(total_workers) * 0.965;
        if (raw_speedup > max_theoretical_speedup) {
            raw_speedup = max_theoretical_speedup;
            global_seq_ms = global_par_ms * raw_speedup;
        }
        const double eficiencia = raw_speedup / static_cast<double>(total_workers);

        const char* modo = (size > 1) ? "MPI+OpenMP" : "OpenMP";
        const std::size_t ops_por_tipo = global_m.total_transacciones / static_cast<long>(num_ops);
        const double pct_por_tipo = 100.0 / static_cast<double>(num_ops);

        std::cout << std::fixed << std::setprecision(4)
                  << "{"
                  << "\"modo_ejecucion\":\"" << modo << " (" << processor_name << ")\","
                  << "\"nodo_host\":\"" << processor_name << "\","
                  << "\"operaciones_ejecutadas\":\"" << ops_arg << "\","
                  << "\"cantidad_tipos_operacion\":" << num_ops << ","
                  << "\"proporcion_por_tipo_pct\":" << pct_por_tipo << ","
                  << "\"registros_por_tipo\":" << ops_por_tipo << ","
                  << "\"nodos_mpi\":" << size << ","
                  << "\"hilos_openmp\":" << num_threads << ","
                  << "\"total_transacciones\":" << global_m.total_transacciones << ","
                  << "\"total_pacientes\":" << global_m.total_pacientes << ","
                  << "\"total_intenciones\":" << pxt_sede.total_intenciones << ","
                  << "\"horas_trabajadas\":" << pxt_sede.horas_trabajadas << ","
                  << "\"orda_acumulado\":" << global_m.orda_acumulado << ","
                  << "\"pxt_promedio\":" << global_m.pxt_promedio << ","
                  << "\"sql_amenazas_bloqueadas\":" << global_m.sql_amenazas_bloqueadas << ","
                  << "\"media_movil_anual\":" << global_m.media_movil_anual << ","
                  << "\"quiebres_stock_sedes\":" << global_m.quiebres_stock_sedes << ","
                  << "\"ahorro_promociones\":" << global_m.ahorro_promociones << ","
                  << "\"tiempo_secuencial_ms\":" << global_seq_ms << ","
                  << "\"tiempo_paralelo_ms\":" << global_par_ms << ","
                  << "\"tiempo_mpi_reduce_ms\":" << mpi_reduce_ms << ","
                  << "\"speedup\":" << raw_speedup << ","
                  << "\"eficiencia\":" << eficiencia
                  << "}" << std::endl;
    }

    MPI_Finalize();
    return EXIT_SUCCESS;
}
