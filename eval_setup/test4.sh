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
tmux new-window -d -n client1 "$CLIENT_EXEC $PORT > ${TEST_NAME}_client1.log 2>&1"
tmux send-keys -t chat_server:client1 "u1005" Enter
tmux send-keys -t chat_server:client1 "p1005" Enter

tmux new-window -d -n client2 "$CLIENT_EXEC $PORT > ${TEST_NAME}_client2.log 2>&1"
tmux send-keys -t chat_server:client2 "u3003" Enter
tmux send-keys -t chat_server:client2 "p3003" Enter

#Perform actions
tmux send-keys -t chat_server:client1 "/msg u3003 Hello World!" Enter

function check_output {
    local expected_output=$1
    local file=$2

    grep -iFq "$expected_output" "$file"
    if [ $? != 0 ]
    then
        echo "${TEST_NAME}: FAIL"
    else
        echo "${TEST_NAME}: PASS"
    fi
}


sleep 10
check_output "Hello World!" "${TEST_NAME}_client2.log"

# Cleanup
tmux kill-session -t chat_server
