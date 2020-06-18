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
echo "Press ^C or close terminal to cancel job"
trap "catch $JOBNO" ERR EXIT SIGINT SIGTERM KILL
sleep 5
TIMELIMIT=$(sacct -j $JOBNO --format=timelimitraw --noheader | tr -d " \t\n\r") 
echo "Your job will be terminated in $TIMELIMIT minutes"
echo "MAKE SURE YOU SAVE YOUR WORK"
tail -f "$HOME"/rstudio-"$JOBNO".out
#while true
#do
#	ELAPSED=$(sacct -j $JOBNO --format=elapsedraw --noheader | tr -d " \t\n\r")
#	echo $ELAPSED
#	REMAIN=$(( $TIMELIMITSECS - $ELAPSED ))
#	echo $REMAIN
#	if [ $REMAIN -lt 60 ]
#	then
#		echo "Your session will end in less than a minute"
#		echo "SAVE YOUR SESSION NOW IF YOU WANT TO KEEP IT"
#		tput bel
#		sleep 60
#		exit
#	fi
#	sleep 1
#done
