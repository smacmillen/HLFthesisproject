#!/bin/bash
# This script can be used to start a dockerized client script for the SCM project
# Written by Simeon MacMillen
# 2021-3-23

ProjectName=vanillaProject
ORANGE='\033[0;33m'
BG='\033[0;100m'
NC='\033[0m'

# start Docker using externally mounted app
function startDockerExternal() {
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
	-v ~/client/wallet:/app/wallet/ \
	-v ~/client/QRcodes:/app/QRcodes/ \
	-v ~/client/app.js:/app/app.js \
	--network supply-chain-network \
	-it smacmillen/scm-client:1.0.3
}

# start Docker using internal, self-contained app
function startDockerInternal() {
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
	-v ~/client/wallet:/app/wallet/ \
	-v ~/client/QRcodes:/app/QRcodes/ \
	--network supply-chain-network \
	-it smacmillen/scm-client
}

# use this function to open up a terminal in the docker container (for troubleshooting)
function startDockerTerminal() {

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
	-v ~/client/wallet:/app/wallet/ \
	-v ~/client/QRcodes:/app/QRcodes/ \
	--network supply-chain-network \
	-it smacmillen/scm-client  /bin/sh
}

echo "Starting Program... (this may take a few moments)"
#the following is a loop enabling automatic restart on exit
	i=1
#while true
while ( "$i" -le "2" )
	x=3
do
	clear
	echo -e "${BG}Starting App${NC} [         0%         ]${NC}"
	echo -e "Cleaning up docker containers...."
	docker container prune -f &>/dev/null
	clear
	echo -e "${BG}Starting App${NC} [==      10%         ]${NC}"
	echo -e "Starting Docker Container for App... (This may take a while)"

	startDockerExternal
	#startDockerInternal
	exitCode=$?
	if [ "$exitCode" -eq "0" ]; then
		exit
	elif [ "$exitCode" -eq "130" ]; then
		echo "Program killed by user"
	else
		echo "Program exited with code $exitCode"
	fi
	i=$(expr $i + 1)
	echo "Restarting Program..."
done
