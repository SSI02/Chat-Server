#!/bin/bash


if [ $# != 3 ] && [ $# != 4 ]
then
	echo "Usage: $0 <start test case num. Eg: 1> <end testcase num. Eg: 3> <submissions directory> <optional: particular user submission directory>" | tee -a $driver_log
	echo "Eg: $0 1 3 submissions1" | tee -a $driver_log
	echo "Eg: $0 1 3 submissions1  280968_280270_280859" | tee -a $driver_log
	exit -1
fi

result_file="result.log"
old_result_file="result.log.old"
server_ctr=0	#For each run of server, we maintain one logfile. Eg: If server runs, we create
			# log file 0, later if server crashes and runs again, we create log file 1 and so on..
server_file="server_part"
oldlogs="oldlogs"
logs="logs"
server="server_grp"

python_used=0
python_server_name="server.py"

time=300 #secs
pid=""

if [ $# == 3 ]
then
	submissions=$(ls $3)
	submissions=($submissions)
else
	submissions=("$4")
fi

###################################
#Init stuff
###################################
echo -e "Doing initial preparation.." | tee -a $driver_log
g++ -o client_grp client.cpp -lpthread
#./gen_usersdata.sh
echo -e "Preparation done.." | tee -a $driver_log

homedir=$(pwd)
driver_log="$homedir/driver.log"
old_driver_log="$homedir/old_driver.log"
rm $old_driver_log
mv $driver_log $old_driver_log

for i in ${submissions[@]}
do
	cd $homedir

	echo -e "\n\n######################################" | tee -a $driver_log
	datetime=$(date)
	echo "[$datetime] Processing submission: $i" | tee -a $driver_log
	echo "######################################" | tee -a $driver_log


	######################################
	#Enter submission directory
	######################################
	submissiondir="${homedir}/$3/${i}/"
	logsdir="${homedir}/$3/${i}/${logs}/"
	oldlogsdir="${homedir}/$3/${i}/${oldlogs}/"
	cd "$submissiondir"

	#sanity check
	if [ $(pwd) != "${homedir}/$3/${i}" ]
	then
		echo "$i: Failed to enter submission directory" | tee -a $driver_log
	fi

	#backup prev. log files
	rm -rf "$oldlogsdir"
	mv "$logsdir" "$oldlogsdir"
	mkdir "$logsdir"

	######################################
	#Add Makefile if it is missing
	######################################
	makefile=$(ls Makefile 2>/dev/null)
	if [ $? != 0 ]
	then
		echo -e "$i: Makefile missing. Adding it." | tee -a $driver_log
		cp "$homedir/Makefile" "$submissiondir"
		ls
	fi

	######################################
	#Add users.txt
	######################################
	echo -e "$i: Adding custom users.txt" | tee -a $driver_log
	cp "$homedir/users.txt" "$submissiondir"
	ls

	######################################
	#Build server
	######################################
	ls $python_server_name 1>/dev/null 2>/dev/null	#Assuming, if students have used python, then name of their server is always server.py
	if [ $? == 0 ]
	then
		echo "Server programmed in python" | tee -a $driver_log
		server="python3"
		python_used=1
	else
		#we don't know the name given by the students to server in their makefile
		rm server	
		rm server_grp
		make clean
		make 
		if [ $? != 0 ]
		then
			echo -e "$i: Failed to build server" | tee -a $driver_log
			#exit	#debugging
			continue
		fi
		echo -e "$i: Server built successfully" | tee -a $driver_log

		ls server 1>/dev/null 2>/dev/null
		if [ $? == 0 ]
		then
			server="server"
		fi
	fi
	ls
	echo "$i: server name: ${server}" | tee -a $driver_log

	######################################
	#Run server
	######################################
	pkill python3 1>/dev/null 2>/dev/null
	pkill server 1>/dev/null 2>/dev/null
	pkill server_grp 1>/dev/null 2>/dev/null

	echo -e "\nSleeping for $time secs to make sure that server can bind to socket"
	#sleep $time

	echo -e "$i: Starting server" | tee -a $driver_log

	if [ $python_used == 1 ]
	then
		#${server} ${python_server_name} &	
		${server} ${python_server_name} 1>/dev/null 2>/dev/null &	#We won't log server output because for some submissions
							#server is entering infinite loop
							#and printing forever
	else
		#./${server} &	
		./${server} 1>/dev/null 2>/dev/null &	#We won't log server output because for some submissions
							#server is entering infinite loop
							#and printing forever
	fi
	sleep 2		#wait to confirm that server doesn't crash on start
	pid=$(pidof ${server})
	if [ $? != 0 ]
	then
		echo -e "$i: Failed to run server" | tee -a $driver_log
		#exit	#debugging
		continue
	fi
	echo -e "$i: server running with pid: $pid" | tee -a $driver_log

	#####################################
	#Find port number
	#####################################
	port=$(netstat -na --program | grep "$pid" | cut -d':' -f2 | cut -d' ' -f1)
	echo -e "$i: Server is running on port: $port" | tee -a $driver_log
	

	#####################################
	#run tests
	#####################################
	for((j=$1;j<=$2;j=$(($j+1))))
	do
		cd "$homedir"
		./test${j}.sh $port | tee -a "$result_file"
		mv test${j}*.log "$logsdir"	#log files created by the test script
		cd "$submissiondir"

		##############
		#Rerun server
		##############
		pkill ${server} 1>/dev/null 2>/dev/null

		already_slept=0
		skip_submission=0
		while [ 1 == 1 ]
		do

			echo -e "$i: Restarting server" | tee -a $driver_log

			if [ $python_used == 1 ]
			then
				${server} ${python_server_name} 1>/dev/null 2>/dev/null &	#We won't log server output because for some submissions
									#server is entering infinite loop
									#and printing forever
			else
				./${server} 1>/dev/null 2>/dev/null &	#We won't log server output because for some submissions
									#server is entering infinite loop
									#and printing forever
			fi
			sleep 2		#wait to confirm that server doesn't crash on start
			pid=$(pidof ${server})
			if [ $? != 0 ]
			then
				if [ $already_slept == 1 ]
				then
					skip_submission=1
					break
				fi
				echo -e "$i: Failed to run server" | tee -a $driver_log
				echo -e "\nSleeping for $time secs to make sure that server can bind to socket"
				sleep $time
				already_slept=1
			else
				break
			fi
		done
		if [ $skip_submission == 1 ]
		then
			echo -e "$i: Failed to run server. Skipping this submission" | tee -a $driver_log
			continue
		fi
		echo -e "$i: server running with pid: $pid" | tee -a $driver_log
	done

	#####################################
	#Save log files
	#####################################
	pkill ${server} 1>/dev/null 2>/dev/null
	cd "$homedir"
	mv "$result_file" "$logsdir"	#result file
done
