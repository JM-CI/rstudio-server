#!/bin/sh
#SBATCH --time=08:00:00
#SBATCH --signal=USR2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8192
#SBATCH --output=/home/%u/rstudio-server.job.%j

# Source spack stuff for new partitions
source /home/software/spack/share/spack/setup-env.sh
spack load singularity@3.8.5

# Create temporary directory to be populated with directories to bind-mount in the container
# where writable file systems are necessary. Adjust path as appropriate for your computing environment.
#workdir=$(python -c 'import tempfile; print(tempfile.mkdtemp())')
workdir=$RSTUDIO_WORK_DIR

mkdir -p -m 700 ${workdir}/run ${workdir}/tmp ${workdir}/var/lib/rstudio-server ${workdir}/etc/rstudio
cat > ${workdir}/etc/rstudio/database.conf <<END
provider=sqlite
directory=/var/lib/rstudio-server
END

# Set OMP_NUM_THREADS to prevent OpenBLAS (and any other OpenMP-enhanced
# libraries used by R) from spawning more threads than the number of processors
# allocated to the job.
#
# Set R_LIBS_USER to a path specific to rocker/rstudio to avoid conflicts with
# personal libraries from any R installation in the host environment

# export R_LIBS_USER=${HOME}/R/rocker-rstudio/4.0

cat > ${workdir}/etc/rstudio/rsession.sh <<END
#!/bin/sh
export OMP_NUM_THREADS=${SLURM_JOB_CPUS_PER_NODE}
exec rsession "\${@}"
END

chmod +x ${workdir}/etc/rstudio/rsession.sh

if [ -d "/mnt/scratcha/" ]
then
    SCRATCH="/mnt/scratcha:/mnt/scratcha,/mnt/scratchb:/mnt/scratchb,/scratcha:/scratcha,/scratchb:/scratchb"
else
    SCRATCH="/mnt/scratchc:/mnt/scratchc,/scratchc:/scratchc"
fi

export SINGULARITY_BIND="${workdir}/run:/run,${workdir}/tmp:/tmp,${workdir}/etc/rstudio:/etc/rstudio,${workdir}/var/lib/rstudio-server:/var/lib/rstudio-server,${SCRATCH},/usr:/mnt/host_usr"
#Now that system libs have been included

# Do not suspend idle sessions.
# Alternative to setting session-timeout-minutes=0 in /etc/rstudio/rsession.conf
# https://github.com/rstudio/rstudio/blob/v1.4.1106/src/cpp/server/ServerSessionManager.cpp#L126
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0

export SINGULARITYENV_USER=$(id -un)
export SINGULARITYENV_PASSWORD=$(openssl rand -base64 15)
# get unused socket per https://unix.stackexchange.com/a/132524
# tiny race condition between the python & singularity commands
readonly PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
cat 1>&2 <<END

To access the rstudio server instance, open a browser and navigate to:

    http://${HOSTNAME}.cri.camres.org:${PORT}

You can login using:

    user: ${SINGULARITYENV_USER}
    pass: ${SINGULARITYENV_PASSWORD}

If you close this terminal or press ^C, this slurm job will terminate.
By default this session will last for eight hours.
END

singularity exec $RSTUDIO_SERVER_IMAGE\
    rserver --www-port ${PORT} \
            --auth-none=0 \
            --auth-pam-helper-path=pam-helper \
            --auth-stay-signed-in-days=30 \
            --auth-timeout-minutes=0 \
            --server-user $SINGULARITYENV_USER \
            --rsession-path=/etc/rstudio/rsession.sh
printf 'rserver exited' 1>&2
