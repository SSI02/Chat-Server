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
tmux send-keys -t chat_server:client1 "alice" Enter
tmux send-keys -t chat_server:client1 "123" Enter

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

function sanity_check {
    local expected_output=$1
    local file=$2

    grep -iFq "$expected_output" "$file"
    if [ $? == 0 ]
    then
        echo "${TEST_NAME}: PASS"
        # Cleanup
        tmux kill-session -t chat_server
        exit 0
    fi
}


sleep 10
sanity_check "failed" "${TEST_NAME}_client1.log"
sanity_check "error" "${TEST_NAME}_client1.log"
echo "${TEST_NAME}: FAIL"

# Cleanup
tmux kill-session -t chat_server
