import os
from dataclasses import dataclass
from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class Settings:
    master_db_url: str = os.getenv(
        "MASTER_DB_URL",
        "postgresql://postgres:postgres@127.0.0.1:5432/farma_hpc"
    )
    slave_db_url: str = os.getenv(
        "SLAVE_DB_URL",
        "postgresql://postgres:postgres@100.94.156.120:5432/farma_hpc"
    )
    slave_ssh_host: str = os.getenv("SLAVE_SSH_HOST", "100.94.156.120")
    slave_ssh_port: int = int(os.getenv("SLAVE_SSH_PORT", "2222"))
    slave_ssh_user: str = os.getenv("SLAVE_SSH_USER", "ronnienodo1")
    wol_mac_address: str = os.getenv("WOL_MAC_ADDRESS", "D8:5E:D3:23:E0:5C")
    wol_broadcast_ip: str = os.getenv("WOL_BROADCAST_IP", "192.168.1.255")
    wol_port: int = int(os.getenv("WOL_PORT", "9"))
    hpc_execution_mode: str = os.getenv("HPC_EXECUTION_MODE", "OPENMP").upper()
    hpc_binary_path: str = os.getenv("HPC_BINARY_PATH", "/usr/local/bin/motor_hpc_farma")
    hpc_omp_threads: int = int(os.getenv("HPC_OMP_THREADS", "16"))
    hpc_dataset_size: int = int(os.getenv("HPC_DATASET_SIZE", "1000000"))
    hpc_tecnicos_activos: int = int(os.getenv("HPC_TECNICOS_ACTIVOS", "45"))
    mpi_np: int = int(os.getenv("MPI_NP", "2"))
    mpi_hostfile: str = os.getenv("MPI_HOSTFILE", "/home/rodrigo/hosts_mpi")


settings = Settings()
