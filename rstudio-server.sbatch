#!/bin/bash

#SBATCH -J rstudio-server
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=YOUR.EMAIL@cruk.cam.ac.uk
#SBATCH --no-requeue
#SBATCH -p general
#SBATCH -o rstudio-%j.out

export RSTUDIO_PASSWORD=$(openssl rand -base64 15)
export SINGULARITY_BIND="/mnt/scratcha,/mnt/scratchb"
# Load singularity module for a more up to date version
module load singularity-3.4.1-gcc-9.2.0-w62nicu
# Get a random port
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

cat << EOF
Connect to http://${HOSTNAME}.cri.camres.org:${PORT} using the credentials:
user: ${USER}
pass: ${RSTUDIO_PASSWORD}
EOF

singularity run --app rserver /home/software/images/singularity-rstudio-server.img \
--www-port ${PORT} \
--auth-none 0 \
--auth-pam-helper rstudio_auth

printf "rserver exited" 1>&2
