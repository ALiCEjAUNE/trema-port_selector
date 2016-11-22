#! /bin/bash

echo -n "Enter time period (sec) : "
read ans

while true
do
  for i in 1 2 3
  do
  sleepenh $ans
#   VAR=`jot -r 1 1 3`
#   echo $VAR
  echo $i | nc -u 192.168.0.241 50000 -w 0
#   echo "1" | nc -w 0 -u 192.168.0.241 50000
#   VAR=$(($VAR+1))
  done
done
