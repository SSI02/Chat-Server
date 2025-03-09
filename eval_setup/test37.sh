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
COUNT=50
j=50
for((i=1;i<=$COUNT;i=$(($i+1))))
do
	num=$i
	user="u$i"
	pass="p$i"
	tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
	tmux send-keys -t chat_server:client$num "$user" Enter
	tmux send-keys -t chat_server:client$num "$pass" Enter
done

for((i=1;i<=$COUNT;i=$(($i+1))))
do
	j=$(($COUNT+$i))
	num=$j
	user="u$j"
	tmux new-window -d -n client$num "$CLIENT_EXEC $PORT > ${TEST_NAME}_client$num.log 2>&1"
	tmux send-keys -t chat_server:client$num "$user" Enter
done

for((i=1;i<=$COUNT;i=$(($i+1))))
do
	j=$(($COUNT+$i))
	pass="p$j"
	tmux send-keys -t chat_server:client$j "$pass" Enter &
	tmux send-keys -t chat_server:client$i "/exit" Enter &
done
wait	#wait for all child backgroud jobs to finish

sleep 10
for((i=1;i<$COUNT;i=$(($i+1))))
do
	j=$(($COUNT+$i))
	k=$(($j+1))
	MESSAGE="Hello to u$k"
	tmux send-keys -t chat_server:client$j "/msg u$k $MESSAGE" Enter
done


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

sleep 60
for((i=1;i<$COUNT;i=$(($i+1))))
do
	j=$(($COUNT+$i))
	k=$(($j+1))
	MESSAGE="Hello to u$k"
	sanity_check "$MESSAGE" "${TEST_NAME}_client$k.log"
done
echo "${TEST_NAME}: PASS"

# Cleanup
tmux kill-session -t chat_server
