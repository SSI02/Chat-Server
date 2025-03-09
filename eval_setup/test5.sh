#!/bin/bash

if [ $# != 1 ] 
then
	echo "Usage: $0 <server port num>"
	exit -1
fi

#echo "Script name: $0 <----------"

CLIENT_EXEC="./client_grp"
PORT=$1
TEST_NAME=$(echo $0 | rev | cut -d'/' -f1 | rev | cut -d'.' -f1)

# Cleanup existing session (if it exists)
tmux kill-session -t chat_server 1>/dev/null 2>/dev/null

#start session
tmux new-session -d -s chat_server

#start clients and login
num=1
user="u101"
pass="p101"
tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
tmux send-keys -t chat_server:client$num "$user" Enter
tmux send-keys -t chat_server:client$num "$pass" Enter

num=2
user="u131"
pass="p131"
tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
tmux send-keys -t chat_server:client$num "$user" Enter
tmux send-keys -t chat_server:client$num "$pass" Enter

num=3
user="u151"
pass="p151"
tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
tmux send-keys -t chat_server:client$num "$user" Enter
tmux send-keys -t chat_server:client$num "$pass" Enter

num=4
user="u191"
pass="p191"
tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
tmux send-keys -t chat_server:client$num "$user" Enter
tmux send-keys -t chat_server:client$num "$pass" Enter

#Perform actions
MESSAGE="Trump's 25% tariff threat on steel, aluminium imports"
tmux send-keys -t chat_server:client1 "/broadcast $MESSAGE" Enter

function check_output {
    local expected_output=$1
    local file=$2

    grep -iFq "$expected_output" "$file"
    if [ $? != 0 ]
    then
	    return -1
    else
	    return 0
    fi
}

function success_check {
	ret_val=$1
	dump_result=$2
	if [ $ret_val != 0 ]
	then
		echo "${TEST_NAME}: FAIL"
		# Cleanup
		tmux kill-session -t chat_server
		exit 0
	fi

	if [ $dump_result == 1 ]
	then
		echo "${TEST_NAME}: PASS"
		# Cleanup
		tmux kill-session -t chat_server
		exit 0
	fi
}

sleep 10
check_output "$MESSAGE" "${TEST_NAME}_client2.log"
success_check $? 0
check_output "$MESSAGE" "${TEST_NAME}_client3.log"
success_check $? 0
check_output "$MESSAGE" "${TEST_NAME}_client4.log"
success_check $? 1

# Cleanup
tmux kill-session -t chat_server
