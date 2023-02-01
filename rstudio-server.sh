#!/bin/bash

SBATCH=/home/software/utilities/rstudio-server/rstudio-server.sbatch
IMAGE_DIR=/home/software/images/rstudio-server
export RSTUDIO_WORK_DIR=~/.rstudio-server-cri

# Make the local working dir
if [ ! -d "$RSTUDIO_WORK_DIR"/.config ]
then
    mkdir -p "$RSTUDIO_WORK_DIR"/.config
fi

# Catch block to trigger on SIGINT or TERM EXIT
cleanup() {
    local JOBNO=$1
    echo "Killing slurm job $JOBNO"
    scancel $JOBNO
    exit
}

ARGS="$@"

echo -e "CRUK Rstudio Server\n\nPlease select a base image to run:\n"
select ITEM in $(for image in $IMAGE_DIR/*; do basename $image; done)
do
    echo -e "$ITEM selected, starting slurm job..."
    export RSTUDIO_SERVER_IMAGE="$IMAGE_DIR/$ITEM"
    RES=$(sbatch --output=$RSTUDIO_WORK_DIR/rstudio-server-out.%j --error=$RSTUDIO_WORK_DIR/rstudio-server-err.%j $ARGS $SBATCH)
    JOBNO=${RES##* }
    break
done

# Wait for job to be scheduled
echo -e "Waiting for job $JOBNO to start"
sleep 2s

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
tail -n 50 -f $RSTUDIO_WORK_DIR/rstudio-server-err."$JOBNO"
