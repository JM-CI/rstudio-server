#!/bin/bash

SBATCH=/home/software/utilities/rstudio-server/rstudio-server.sbatch
WORK_DIR=~/.rstudio-server-cri

# Make the local working dir
if [ ! -d "$WORK_DIR"/.config ]
then
    mkdir -p "$WORK_DIR"/.config
fi

# Catch block to trigger on SIGINT or TERM EXIT
cleanup() {
    local JOBNO=$1
    echo "Killing slurm job $JOBNO"
    scancel $JOBNO
    exit
}

ARGS="$@"

echo -e "Starting rstudio server..."
RES=$(sbatch --output=$WORK_DIR/rstudio-server-out.%j --error=$WORK_DIR/rstudio-server-err.%j $ARGS $SBATCH)
JOBNO=${RES##* }
#touch $WORK_DIR/rstudio-server-err."$JOBNO"

while true
do
    sleep 1s
    STATUS=$(squeue -j $JOBNO -t PD,R -h -o %t)
    if [ "$STATUS" = "R" ]
    then
        break
    elif [ "$STATUS" != "PD" ]
    then
        echo "Job neither running nor pending, aborting"
        cleanup $JOBNO
        exit 1
    fi
done
echo "Job $JOBNO started"
trap "cleanup $JOBNO" ERR EXIT SIGINT SIGTERM KILL
tail -n 50 -f $WORK_DIR/rstudio-server-err."$JOBNO" 
