#!/bin/bash
# This script can be used to start a dockerized client script for the SCM project
# Written by Simeon MacMillen
# 2021-3-23

ProjectName=vanillaProject
ORANGE='\033[0;33m'
BG='\033[0;100m'
NC='\033[0m'

# start Docker:
function startDocker() {

#Check for updates:
docker pull smacmillen/scm-client

#get variables
source ~/$ProjectName/files/scripts/utils.sh

docker run \
	-e ORG="$ORG" \
	-e org="$org" \
	-e ChannelID="$ChannelID" \
	-e CHAINCODE_NAME="$CHAINCODE_NAME" \
	-e CORE_PEER_LOCALMSPID="$CORE_PEER_LOCALMSPID" \
	-e ProjectName="$ProjectName" \
	-e appName="$appName" \
	-e orgAddress="$orgAddress" \
	-v ~/vanillaProject/config/:/app/config/ \
	-v ~/vanillaProject/organizations/:/app/organizations/ \
	-v $PWD/wallet:/app/wallet/ \
	-v $PWD/public:/app/public/ \
	-v $PWD/scripts:/app/scripts/ \
	-v $PWD/views:/app/views/ \
	-v $PWD/app.js:/app/app.js \
	--network supply-chain-network \
	-p 3001:3001 \
	-it smacmillen/scm-client:latest
}

# Alternate Options:
# To open a terminal instead of running the app:
#	-it smacmillen/scm-client:webApp0.0.1 /bin/sh
#
# to start Docker using an external app, add this line:
#	-v $PWD/app.js:/app/app.js \
#
# to run in dev mode:
#	-it smacmillen/scm-client:webApp0.0.1 /bin/bash -c "source /usr/local/nvm/nvm.sh && npm run dev app.js"
#
# port mapping:
# -p container port: host port
# 3001:80 = container port(3001), host port(80)

clear
while true
do
	echo "Starting Program..."
	echo -e "Cleaning up docker containers...."
	docker container prune -f &>/dev/null
	echo -e "Starting Docker Container for App... (This may take a while)"
	startDocker
	exitCode=$?
	if [ "$exitCode" -eq "0" ]; then
		exit
	elif [ "$exitCode" -eq "130" ]; then
		echo "Program killed by user"
		exit
	elif [ "$exitCode" -eq "137" ]; then
		echo "Docker Container Killed."
		echo "Restarting Program..."
		sleep 1
	else
		echo "Program exited with code $exitCode"
		exit
	fi
done
