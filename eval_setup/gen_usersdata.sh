#!/bin/bash

i=0
file="users.txt"
rm $file
for((i=0;i<99999;i=$(($i+1))))
do
	echo "u$i:p$i" >> $file
done
