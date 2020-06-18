#!/bin/bash

catch() {
	local JOBNO=$1
	echo "Killing slurm job"
	scancel $JOBNO
	# Necessary to bury the output as this seems to get exectued more than
	# once on a sigint for example...
	rm "$HOME"/rstudio-"$JOBNO".out > /dev/null 2>&1
	exit
}

ARGS="$@"
echo "Starting slurm job"
RES=$(sbatch $ARGS /home/software/utilities/rstudio-server/rstudio-server.sbatch)
JOBNO=${RES##* }
echo "Job number: $JOBNO"
echo "Waiting for JOBID $JOBNO to start"
while true; do
    sleep 1s
    # Check job status
    STATUS=$(squeue -j $JOBNO -t PD,R -h -o %t)
    if [ "$STATUS" = "R" ]
    then
        break
    elif [ "$STATUS" != "PD" ]
    then
        echo "Job is not Running or Pending. Aborting"
        scancel $JOBNO
        exit 1
    fi
trap "catch $JOBNO" ERR EXIT SIGINT SIGTERM KILL
sleep 5
TIMELIMIT=$(sacct -j $JOBNO --format=timelimitraw --noheader | tr -d " \t\n\r")
echo "Press ^C or close terminal to cancel job"
echo "Your job will be terminated in $TIMELIMIT minutes"
echo "MAKE SURE YOU SAVE YOUR WORK"
tail -f "$HOME"/rstudio-"$JOBNO".out
