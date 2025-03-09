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

MESSAGE1="On 20 December 2004, £26.5 million was stolen from the Northern Bank in Belfast, Northern Ireland"
MESSAGE2="Having taken family members of two bank officials hostage, an armed gang forced the workers to help them steal banknotes."
MESSAGE3="It was one of the largest bank robberies in the United Kingdom."
MESSAGE4="The police and the British and Irish governments claimed that the Provisional Irish Republican Army was responsible, which was denied."
tmux send-keys -t chat_server:client1 "/create_group CS425" Enter
sleep 2
tmux send-keys -t chat_server:client2 "/broadcast  $MESSAGE1" Enter
tmux send-keys -t chat_server:client3 "/join_group CS888" Enter
tmux send-keys -t chat_server:client2 "/broadcast  $MESSAGE2" Enter
tmux send-keys -t chat_server:client3 "/join_group CS425" Enter
tmux send-keys -t chat_server:client2 "/broadcast  $MESSAGE3" Enter



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

function negative_check {
    local not_expected_output=$1
    local file=$2

    grep -iFq "$not_expected_output" "$file"
    if [ $? == 0 ]
    then
        echo "${TEST_NAME}: FAIL"
        # Cleanup
        tmux kill-session -t chat_server
        exit 0
    fi
}

function count_check {
    local expected_output=$1
    local file=$2
    local expected_count=$3

    count=$(grep -iF "$expected_output" "$file" | wc -l)
    echo "count: $count, expected count: $expected_count"
    if [ $count != $expected_count ]
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
sanity_check "welcome" "${TEST_NAME}_client1.log"
sanity_check "welcome" "${TEST_NAME}_client2.log"
sanity_check "welcome" "${TEST_NAME}_client3.log"
sanity_check "welcome" "${TEST_NAME}_client4.log"
sanity_check "CS425" "${TEST_NAME}_client1.log"
sanity_check "$MESSAGE1" "${TEST_NAME}_client1.log"
sanity_check "$MESSAGE1" "${TEST_NAME}_client3.log"
sanity_check "$MESSAGE1" "${TEST_NAME}_client4.log"
sanity_check "$MESSAGE2" "${TEST_NAME}_client1.log"
sanity_check "$MESSAGE2" "${TEST_NAME}_client3.log"
sanity_check "$MESSAGE2" "${TEST_NAME}_client4.log"
sanity_check "$MESSAGE3" "${TEST_NAME}_client1.log"
sanity_check "$MESSAGE3" "${TEST_NAME}_client3.log"
sanity_check "$MESSAGE3" "${TEST_NAME}_client4.log"
sanity_check "join" "${TEST_NAME}_client3.log"
check_output "fail" "${TEST_NAME}_client3.log"
check_output "error" "${TEST_NAME}_client3.log"
check_output "exist" "${TEST_NAME}_client3.log"
check_output "not" "${TEST_NAME}_client3.log"
echo "${TEST_NAME}: FAIL"

# Cleanup
tmux kill-session -t chat_server
