#!/usr/bin/bash
#	Author: 		Anthony E. Nocentino
#	Email:			aen@centinosystems.com
#	Description:		One liner using SSH remote command execution to get the top to processes from a remote computer.
ssh -l demo server2.domain.local "ps -aux --no-headers | sort -nrk 3 | head"
