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
user="u1"
pass="p1"
tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
tmux send-keys -t chat_server:client$num "$user" Enter
tmux send-keys -t chat_server:client$num "$pass" Enter

num=2
user="u2"
pass="p2"
tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
tmux send-keys -t chat_server:client$num "$user" Enter
tmux send-keys -t chat_server:client$num "$pass" Enter

num=3
user="u3"
pass="p3"
tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
tmux send-keys -t chat_server:client$num "$user" Enter
tmux send-keys -t chat_server:client$num "$pass" Enter

num=4
user="u4"
pass="p4"
tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
tmux send-keys -t chat_server:client$num "$user" Enter
tmux send-keys -t chat_server:client$num "$pass" Enter

#Perform actions
MESSAGE1="Hello u2"
tmux send-keys -t chat_server:client1 "/msg u2 $MESSAGE1" Enter

MESSAGE2="Hello u3"
tmux send-keys -t chat_server:client1 "/msg u3 $MESSAGE2" Enter

MESSAGE3="Hello u4"
tmux send-keys -t chat_server:client1 "/msg u4 $MESSAGE3" Enter


function sanity_check {
    local expected_output=$1
    local file=$2

    grep -iFq "$expected_output" "$file"
    if [ $? != 0 ]
    then
        echo "${TEST_NAME}: FAIL"
        # Cleanup
        tmux kill-session -t chat_server
        exit 0
    fi
}

function check_output {
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
sanity_check "welcome" "${TEST_NAME}_client2.log"
sanity_check "welcome" "${TEST_NAME}_client3.log"
sanity_check "welcome" "${TEST_NAME}_client4.log"
#check_output "fail" "${TEST_NAME}_client2.log"
#check_output "error" "${TEST_NAME}_client2.log"
#check_output "exist" "${TEST_NAME}_client2.log"
#check_output "not" "${TEST_NAME}_client2.log"
sanity_check "$MESSAGE1" "${TEST_NAME}_client2.log"
sanity_check "$MESSAGE2" "${TEST_NAME}_client3.log"
sanity_check "$MESSAGE3" "${TEST_NAME}_client4.log"
echo "${TEST_NAME}: PASS"

# Cleanup
tmux kill-session -t chat_server
