#!/bin/bash
#	Author: 		Anthony E. Nocentino
#	Email:			aen@centinosystems.com
#	Description:		A very small script that can be used to get processes from several computers. In the demo I show getting processes from 
#				three computers, two linux and one windows. This one fails when logging into windows since Windows doesn't understand the ps command
#				$name holds a list computers coming from the file myhosts.
while read name
do
	#echo "Getting top 10 processes from" $name
	ssh -l demo $name -n "ps -aux --no-headers | sort -nrk 3 | head"
done < myhosts

