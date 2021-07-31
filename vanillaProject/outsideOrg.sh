#!/bin/bash
# This is a simple script to setup an additional host for a Fabric network
# This script is part of the on-boarding process for a new host
# Written by Simeon MacMillen
# 2021-3-17

# Variables are all defined in utils.sh file
source ./files/scripts/utils.sh  #import formatting, helper functions, VARIABLES
source ./files/scripts/CAsetup.sh  #import functions for CA user registration, enrollment

#---------------FUNCTIONS--------------------------
# 					helper functions
#----CCP file generation----
function one_line_pem {
	echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}
function json_ccp {
	local PP=$(one_line_pem $4)
	local CP=$(one_line_pem $5)
	sed -e "s/\${ORG}/$1/" \
		-e "s/\${org}/${1,,}/" \
		-e "s/\${P0PORT}/$2/" \
		-e "s/\${CAPORT}/$3/" \
		-e "s#\${PEERPEM}#$PP#" \
		-e "s#\${CAPEM}#$CP#" \
		-e "s/\${DOMAIN}/$6/" \
		organizations/ccp-template.json
	errorCheck ${FUNCNAME[0]} $LINENO
	}
function yaml_ccp {
	local PP=$(one_line_pem $4)
	local CP=$(one_line_pem $5)
	sed -e "s/\${ORG}/$1/" \
		-e "s/\${org}/${1,,}/" \
		-e "s/\${P0PORT}/$2/" \
		-e "s/\${CAPORT}/$3/" \
		-e "s#\${PEERPEM}#$PP#" \
		-e "s#\${CAPEM}#$CP#" \
		-e "s/\${DOMAIN}/$6/" \
		organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
	errorCheck ${FUNCNAME[0]} $LINENO
	}
#---config.tx edit---#
function addOrdererHelper() {
# This function is used to add a new orderer to the configtx.yaml file.  It takes the org name and org port.  
# It can be called multiple times with unique values to add multiple orderers to the configtx.yaml file.
# Example usage: ordererAdd s11 $orderer_LISTENPORT

if [ -n "$4" ]; then
	echo "Incorrect number of arguments.  Expected 2 arguments, but received $# arguments.  Stopping script"
	altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
elif [ ! -n "$3" ]; then
	echo "Expected 2 arguments, but received $# argument(s): $1  Stopping script"
	altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
fi

local org_name=${1,,} # converts $1 to lowercase 
local ORG_NAME=${1^^} # converts $1 to uppercase (note: does not work on Bash 3.x or older)
local org_Address="${org_name}.${DOMAIN}.com"
local org_Port=$2
local FILE=$3

# Add new Organization:
echo -e "Adding ${BLUE}$org_name orderer${NC} org to $FILE"
#get yaml template and substitute actual values:
cp $ProjectDir/files/templates/newOrderer.yaml ./OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
chmod +w OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
sed -i "s/<org_name>/${org_name}/g" OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
sed -i "s/<ORG_NAME>/${ORG_NAME}/g" OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
sed -i "s/<org_Address>/${org_Address}/g" OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
sed -i "s/<org_Port>/${org_Port}/g" OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO

local length=$(yq eval '.Organizations | length' $FILE) #get array length 
A=$(cat OrgProfile.yaml) B=$length yq eval -i '.Organizations[env(B)] = env(A)' $FILE
rm OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO

# Add Orderer Consenters:
echo -e "Adding ${BLUE}$org_name orderer${NC} org to list of Consenters"
echo "Host: orderer.${org_Address}" > new.yaml
echo "Port: ${org_Port}" >> new.yaml
echo "ClientTLSCert: ../organizations/ordererOrganizations/${org_Address}/orderers/orderer.${org_Address}/tls/server.crt" >> new.yaml
echo "ServerTLSCert: ../organizations/ordererOrganizations/${org_Address}/orderers/orderer.${org_Address}/tls/server.crt" >> new.yaml
errorCheck ${FUNCNAME[0]} $LINENO

local length=$(yq eval '.Orderer.EtcdRaft.Consenters | length' $FILE) #get array length
A=$(cat new.yaml) B=$length yq eval -i '.Orderer.EtcdRaft.Consenters[env(B)] = env(A)' $FILE
rm new.yaml
errorCheck ${FUNCNAME[0]} $LINENO

# Add Orderer Addresses:
echo -e "Adding ${BLUE}$org_name orderer${NC} org to list of Orderers"
local length=$(yq eval '.Orderer.Addresses | length' $FILE) #get array length
A=orderer.${org_Address}:${org_Port} B=$length yq eval -i '.Orderer.Addresses[env(B)] = env(A)' $FILE
errorCheck ${FUNCNAME[0]} $LINENO


# Add new orderer Org to Channel Profile:
profName=$ChannelProfile1 # Channel Profile Name
echo -e "Adding ${BLUE}$org_name orderer ${NC}org to $ChannelProfile1 Channel Profile"
local length=$(A=$profName yq eval '.Profiles.[env(A)].Orderer.Organizations | length' $FILE) #get array length 
A=$profName B=$length C="${org_name}orderer" yq eval -i '.Profiles.[env(A)].Orderer.Organizations[env(B)] alias = env(C)' $FILE
errorCheck ${FUNCNAME[0]} $LINENO
yamlErrorCheck $FILE $LINENO

}
function addPeerHelper() {
if [ -n "$4" ]; then
	echo "Incorrect number of arguments.  Expected 2 arguments, but received $# arguments.  Stopping script"
	altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
elif [ ! -n "$3" ]; then
	echo "Expected 2 arguments, but received $# argument(s): $1  Stopping script"
	altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
fi

local org_name=${1,,} # converts $1 to lowercase 
local ORG_NAME=${1^^} # converts $1 to uppercase (note: does not work on Bash 3.x or older)
local org_Address="${org_name}.${DOMAIN}.com"
local org_Port=$2
local FILE=$3


# First, add new organization to top-level org list:
echo -e "Adding ${BLUE}$ORG_NAME peer ${NC}org to $FILE"
#get yaml template and substitute actual values:
cp $ProjectDir/files/templates/newPeer.yaml ./OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
chmod +w OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
sed -i "s/<ORG>/${ORG_NAME}/g" OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
sed -i "s/<org_Address>/${org_Address}/g" OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO
sed -i "s/<org_Port>/${org_Port}/g" OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO

local length=$(yq eval '.Organizations | length' $FILE) #get array length 
A=$(cat OrgProfile.yaml) B=$length yq eval -i '.Organizations[env(B)] = env(A)' $FILE
rm OrgProfile.yaml
errorCheck ${FUNCNAME[0]} $LINENO

# Second, add new org to Profile Application section:
# Add new Peer Org to Channel Profile:
profName=$ChannelProfile1 # Channel Profile Name
echo -e "Adding ${BLUE}$org_name peer${NC} org to $ChannelProfile1 Channel Profile"
local length=$(A=$profName yq eval '.Profiles.[env(A)].Application.Organizations | length' $FILE) #get array length 
A=$profName B=$length C=$ORG_NAME yq eval -i '.Profiles.[env(A)].Application.Organizations[env(B)] alias = env(C)' $FILE
errorCheck ${FUNCNAME[0]} $LINENO
yamlErrorCheck $FILE $LINENO
}

# Check for required binaries:
function checkForBinaries() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	echo "Checking for required binaries on system:"
	for NAME in docker docker-compose python yq jq peer go node npm
	do
		echo "Checking for $NAME..."
		command -v $NAME &>/dev/null
		if [ "$?" -ne 0  ]; then
			echo -e "${RED}ERROR${NC}: $NAME is not installed on your system.  Please install and try again."
			echo "NOTE: for yq, node, npm, please do not install through apt install. Refer to ProjectConfiguration notes"
			altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
		fi
	done
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# Delete files
function deleteFiles() {
	echoBlue "Running ${FUNCNAME[0]}"
	echo "removing system files:"
	sudo rm -rf $ProjectDir/config $ProjectDir/docker $ProjectDir/organizations *.pb *.block
	errorCheck ${FUNCNAME[0]} $LINENO
	echoOrange "removing docker containers:"
	docker rm -f $(docker ps -aq)
	echoOrange "removing docker volumes:"
	docker volume rm $(docker volume ls -q)
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# get required templates
function getFiles() {
	echoBlue "Running ${FUNCNAME[0]}"
	mkdir -p $ProjectDir/{config,organizations,docker} # create directories if needed
	cp $ProjectDir/files/templates/{core.yaml,configtx.yaml,orderer.yaml} $ProjectDir/config/
	errorCheck ${FUNCNAME[0]} $LINENO
	cp $ProjectDir/files/templates/docker-compose* $ProjectDir/docker/
	errorCheck ${FUNCNAME[0]} $LINENO
	cp -v $ProjectDir/files/templates/{ccp-template.json,ccp-template.yaml} $ProjectDir/organizations
	errorCheck ${FUNCNAME[0]} $LINENO
	cp -v $ProjectDir/files/collections_config.json $ProjectDir/config/ #NOTE: this is a static file, not a template!
	errorCheck ${FUNCNAME[0]} $LINENO
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# edit files as required
function editFiles() {
	#IMPORTANT NOTE: This function uses yq VERSION 4 (v4 is syntactically very different from v3)
	echoBlue "Running Function ${FUNCNAME[0]}"

	echo "Editing docker-compose-ca.yaml"
	local File=$ProjectDir/docker/docker-compose-ca.yaml 
	sed -i "s/<NETWORK_NAME>/${externalNetwork}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<peerCA_containerName>/${peerCA_containerName}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<CA_VER>/${CA_VER}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<peerCA_name>/${peerCA_name}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<peerPort>/${peerPort}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<org>/${org}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<ordererCA_containerName>/${ordererCA_containerName}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<ordererCA_name>/${ordererCA_name}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<ordererPort>/${ordererPort}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $File $LINENO $0

	echo "Editing docker-compose-nodes.yaml"
	local File=$ProjectDir/docker/docker-compose-nodes.yaml
	sed -i "s/<orgAddress>/${orgAddress}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<NETWORK_NAME>/${externalNetwork}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<FABRIC_VER>/${FABRIC_VER}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<orderer_LISTENPORT>/${orderer_LISTENPORT}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<ORG>/${ORG}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<orderer_Admin_ListenPort>/${orderer_Admin_ListenPort}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<peer_CC_Port>/${peer_CC_Port}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<peer_LISTENPORT>/${peer_LISTENPORT}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<x_org1_address>/${x_org1_address}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<x_org1_peer_LISTENPORT>/${x_org1_peer_LISTENPORT}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	if [ $bootstrapMethod = "system" ]; then
		V="../system-genesis-block/genesis.block:/var/hyperledger/orderer/orderer.genesis.block"
		A="orderer.${orgAddress}" V=$V yq eval -i '.services.[env(A)].volumes += env(V)' $File
	fi
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $File $LINENO $0

	echo "Editing docker-compose-couch.yaml"
	local File=$ProjectDir/docker/docker-compose-couch.yaml
	sed -i "s/<NETWORK_NAME>/${externalNetwork}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<ORG>/${ORG}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<COUCH_VER>/${COUCH_VER}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<COUCH_PORT>/${COUCH_PORT}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	sed -i "s/<orgAddress>/${orgAddress}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $File $LINENO $0

	echo "Editing configtx.yaml"
	local File=$ProjectDir/config/configtx.yaml 
	sed -i "s/<CHANNEL_NAME>/${ChannelProfile1}/g" $File
	errorCheck ${FUNCNAME[0]} $LINENO
	echo "adding primary org:"
	addOrdererHelper $ORG $orderer_LISTENPORT $File
	errorCheck ${FUNCNAME[0]} $LINENO
	addPeerHelper $ORG $peer_LISTENPORT $File
	errorCheck ${FUNCNAME[0]} $LINENO
	echo "adding secondary org:"
	addOrdererHelper $x_ORG1 $x_org1_orderer_LISTENPORT $File
	errorCheck ${FUNCNAME[0]} $LINENO
	addPeerHelper $x_ORG1 $x_org1_peer_LISTENPORT $File
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $File $LINENO $0

	echo "Editing core.yaml"
	local File=$ProjectDir/config/core.yaml
	yq eval -i '.peer.tls.enabled = true' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	yq eval -i '.peer.tls.clientAuthRequired = true' $File  # require client-side cert
	errorCheck ${FUNCNAME[0]} $LINENO
	yq eval -i '.peer.id = "Tom"' $File #set id of peer node ##   <<----------------------------edit
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$externalNetwork yq eval -i '.peer.networkId = env(A)' $File # <<-------------------------edit
	errorCheck ${FUNCNAME[0]} $LINENO
	#add peer client tls certs:
	local TLSDir=${ProjectDir}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/tls
	A="$TLSDir/server.crt" yq eval -i '.peer.tls.cert.file = env(A)' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	A="$TLSDir/server.key" yq eval -i '.peer.tls.key.file = env(A)' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	A="$TLSDir/ca.crt" yq eval -i '.peer.tls.rootcert.file = env(A)' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	A="$TLSDir/ca.crt" yq eval -i '.peer.tls.clientRootCAs.files = env(A)' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$CORE_PEER_LOCALMSPID yq eval -i '.peer.localMspId = env(A)' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	A="$TLSDir/server.crt" yq eval -i '.peer.tls.clientCert.file = env(A)' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	A="$TLSDir/server.key" yq eval -i '.peer.tls.clientKey.file = env(A)' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $File $LINENO $0

	echo "Editing orderer.yaml"
	local File=$ProjectDir/config/orderer.yaml
	## new file (not used in previous setup)
	yq eval -i 'del(.Kafka)' $File # delete kafka section since RAFT is planned to be used instead
	errorCheck ${FUNCNAME[0]} $LINENO
	#recommended edits per https://hyperledger-fabric.readthedocs.io/en/latest/deployorderer/ordererchecklist.html
	yq eval -i '.General.ListenAddress = "0.0.0.0"' $File #default is 127.0.0.1
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$orderer_LISTENPORT yq eval -i '.General.ListenPort = env(A)' $File #default is 7050
	errorCheck ${FUNCNAME[0]} $LINENO
	yq eval -i '.General.TLS.Enabled = true' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$ordererTLSKey yq eval -i '.General.TLS.PrivateKey = env(A)' $File # set Orderer TLS cert private key
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$ordererTLSCertificate yq eval -i '.General.TLS.Certificate = env(A)' $File # set Orderer TLS cert public key
	errorCheck ${FUNCNAME[0]} $LINENO
	yq eval -i 'del(.General.TLS.RootCAs)' $File # remove TLS RootCA section - typically unset for normal use
	errorCheck ${FUNCNAME[0]} $LINENO
	yq eval -i '.General.TLS.ClientAuthRequired = true' $File # require client-side cert #<<-----------------edit?
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$ORDERER_CA yq eval -i '.General.TLS.ClientRootCAs = env(A)' $File
	errorCheck ${FUNCNAME[0]} $LINENO
	yq eval -i '.ChannelParticipation.Enabled = true' $File # required if BootstrapMethod set to "none"
	errorCheck ${FUNCNAME[0]} $LINENO
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$ordererMSPDir yq eval -i '.General.LocalMSPDir = env(A)' $File #path to ordering node's local MSP
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$orderer_MSPID yq eval -i '.General.LocalMSPID = env(A)' $File # set orderer MSP ID
	errorCheck ${FUNCNAME[0]} $LINENO
	# Admin:
	yq eval -i '.Admin.TLS.Enabled = true' $File # Additional settings include cert, privateKey, etc.
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$ORDERER_ADMIN_TLS_SIGN_CERT yq eval -i '.Admin.TLS.Certificate = env(A)' $File # TLS cert
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$ORDERER_ADMIN_TLS_PRIVATE_KEY yq eval -i '.Admin.TLS.PrivateKey = env(A)' $File # TLS key
	errorCheck ${FUNCNAME[0]} $LINENO
	yq eval -i '.Admin.TLS.ClientAuthRequired = true' $File # require client-side cert
	errorCheck ${FUNCNAME[0]} $LINENO
	A=$ORDERER_CA yq eval -i '.Admin.TLS.ClientRootCAs = env(A)' $File # CA root cert
	errorCheck ${FUNCNAME[0]} $LINENO
	#ChannelParticipation
	yq eval -i '.ChannelParticipation.Enabled = true' $File # must be "true" if not using system channel genesis block
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $File $LINENO $0
	if [ $bootstrapMethod = "system" ]; then
		echoOrange "Using system bootstrap option"
		yq eval -i '.General.BootstrapMethod = "file"' $File #set to "file" if system channel required, "none" otherwise
		errorCheck ${FUNCNAME[0]} $LINENO
		A="$ProjectDir/ordererGenesisBlock" yq eval -i '.General.BootstrapFile = env(A)' $File
		errorCheck ${FUNCNAME[0]} $LINENO
	fi
	yamlErrorCheck $File $LINENO $0
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"

}
# Startup Docker CAs
function startCAs() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	mkdir -p organizations
	#note that docker-compose file is configured to require $CA_VER value to run
	docker-compose -f $ProjectDir/docker/docker-compose-ca.yaml up -d 2>&1
	errorCheck ${FUNCNAME[0]} $LINENO
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# Register, enroll users
function setupCAusers() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	# wait for TLS files to appear:

	maxWait=5 # max time to wait in seconds
	echo "waiting for the Peer Node TLS certfile"
	while [ ! -f $peerTLS_certFile ]; do 
		sleep 1
		waitTimer=$(expr $waitTimer + 1)
		if [ $waitTimer -ge $maxWait ]; then
			echo -e "${RED}ERROR${NC} After waiting $maxWait seconds, the Peer Node TLS cert was not found at $peerTLS_certFile."
			echo "This file should have been created in the previous step."
			echo "Please check the function and try again."
			altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
		fi
	done

	# call individual sub-functions here
	createOrg #setup Org Peer CA
	errorCheck ${FUNCNAME[0]} $LINENO $0
	createOrderer #setup Orderer CA
	errorCheck ${FUNCNAME[0]} $LINENO $0
	PeerCAerrorCheck #check for created files
	errorCheck ${FUNCNAME[0]} $LINENO $0
	OrdererCAerrorCheck #check for created files 
	errorCheck ${FUNCNAME[0]} $LINENO $0
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# Check to see if Docker Swarm is initialized
function initSwarm() {
  echoBlue "Running ${FUNCNAME[0]}"
	docker swarm ca &>/dev/null  #will return error if swarm is not initialized
	if [ "$?" -ne 0 ]; then
		echo "No swarm cert found - checking again in 2 seconds"
		sleep 2
		docker swarm ca &>/dev/null  #will return error if swarm is not initialized
	fi
	if [ "$?" -ne 0 ]; then
		echoBlue "Docker swarm is not initialized."
		if [ $OrgMaster = "yes" ]; then
			echoBlue "Initializing Docker swarm as leader:"
			docker swarm init
			errorCheck ${FUNCNAME[0]} $LINENO $0
			echoBlue "Getting token to add other nodes as managers to swarm:"
			docker swarm join-token manager
			echoOrange "Please follow the instructions to add each other organizations to the swarm"
			echoOrange "When completed, please re-run this script."
			exit 0
		elif [ $OrgMaster = "no" ]; then 
			echoOrange "Organization configuration set to \"normal\" (non-leader)."
			echoOrange "Please follow the instructions from the swarm leader to add your organization to the swarm"
			echoOrange "When completed, please re-run this script."
			exit 1
		else
			echoRed "Organization Master Setting not detected.  Please correct in utils.sh"
			altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
		fi
	else
		echoGreen "Docker swarm already initialized"
	fi
  errorCheck ${FUNCNAME[0]} $LINENO $0
}
# setup Docker Swarm overlay network
function createOverlayNetwork() {
  echoBlue "Running ${FUNCNAME[0]}"  
	initSwarm #call sub-function
	docker network inspect $externalNetwork &>/dev/null #see if network is already up
	if [ "$?" -eq 0 ]; then
		echoGreen "Network $externalNetwork is already up."
	else
		docker network create -d overlay --attachable $externalNetwork
		errorCheck ${FUNCNAME[0]} $LINENO $0
		echoGreen "Overlay network \"$externalNetwork\" created"
	fi
}
# check if other org is visible over Docker swarm network
function verifyExtOrgOnline() { #verify that the external org is online (sanity check)
  echoBlue "Running ${FUNCNAME[0]}"
	echo "Checking to see if $x_ORG1 is online and connected to $externalNetwork."
	docker node ls --format "{{.Hostname}}" | grep ${x_ORG1} &> /dev/null
	if [ $? -eq 0 ]; then
		echo -e "${GREEN}[OK]${NC}: $x_ORG1 is online and connected to $externalNetwork."
	else
		echo -e "${RED}ERROR${NC}: $x_ORG1 was not detected as member of $externalNetwork."
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0
	fi
}
# Generate CCP files for Org
function generateCCP() {
	local P0PORT=$peer_LISTENPORT
	local CAPORT=$peerPort
	local PEERPEM=organizations/peerOrganizations/${orgAddress}/tlsca/tlsca.${orgAddress}-cert.pem
	local CAPEM=organizations/peerOrganizations/${orgAddress}/ca/ca.${orgAddress}-cert.pem

	# may need to edit name in ccp files (currently set to: name: test-network-${org} ) # <<--------------------edit??

	local FILE=organizations/peerOrganizations/${orgAddress}/connection-${org}.json
	echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM $DOMAIN)" > $FILE
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $FILE $LINENO $0

	local FILE=organizations/peerOrganizations/${orgAddress}/connection-${org}.yaml
	echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM $DOMAIN)" > $FILE
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $FILE $LINENO $0

	#create alternate connection profile with localhost for non-docker client use:
	FilePath=$ProjectDir/organizations/peerOrganizations/${orgAddress} 
	jq '.peers."peer0.'${orgAddress}'".url = "grpcs://localhost:'${peer_LISTENPORT}'" | .certificateAuthorities."ca.'${orgAddress}'".url = "https://localhost:'${peerPort}'"' $FilePath/connection-${org}.json>$FilePath/alt-connection-${org}.json 
	errorCheck ${FUNCNAME[0]} $LINENO
}
# generate json org definition used to join to channel
function generateOrgDef() {
  echoBlue "Running ${FUNCNAME[0]}"
	mkdir -p $ProjectDir/TMP
	local orgName=$1  #must match organization name in configtx.yaml!
	configtxgen -printOrg ${1} > $ProjectDir/TMP/${1}.json
	errorCheck ${FUNCNAME[0]} $LINENO
}
# start nodes
function startNodes() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	docker-compose -f $ProjectDir/docker/docker-compose-nodes.yaml -f $ProjectDir/docker/docker-compose-couch.yaml up -d 2>&1
	errorCheck ${FUNCNAME[0]} $LINENO
}
# get crypto for partner organizations
function getExtCerts() {
	#MODIFY FUNCTION TO TAKE TWO INPUTS: $1 user (e.g. san) $2 org (e.g. S11)
	echoBlue "Running Function ${FUNCNAME[0]}"


	if [ ! -n "$2" ]; then
		echoOrange "This function requires two arguments.  Please correct and resubmit."
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO
	fi


	local O1=${2^^}
	local o1=${2,,}
	local user=$1
	local ADDRESS="${o1}.${DOMAIN}.com"
	local HOST=${user}@${o1}.${DOMAIN}.cloudns.asia

	echoBlue "Getting orderer certs from $O1:"
	local xDIR1="organizations/ordererOrganizations/${ADDRESS}/orderers/orderer.${ADDRESS}/tls"
	local xDIR2="organizations/ordererOrganizations/${ADDRESS}/msp"
	# create directories:
	mkdir -p $ProjectDir/{$xDIR1,$xDIR2}
	errorCheck ${FUNCNAME[0]} $LINENO
	# get orderer certs
	rsync -P ${HOST}:~/vanillaProject/$xDIR1/{server.crt,ca.crt} $ProjectDir/$xDIR1/

	# automatically  wait up to $maxWait seconds in case other org is not yet ready
	# after $maxWait seconds will wait for manual input to continue
	res=$?
	maxWait=10 # max time to wait in seconds
	while [ $res -eq 23 ]; do  #rsync exit code 23 denotes incomplete transfer
		echoOrange "The server and ca certificates were not found at $O1.  Waiting 2 seconds before retrying."
		sleep 2
		waitTimer=$(expr $waitTimer + 2)
		rsync -P ${HOST}:~/vanillaProject/$xDIR1/{server.crt,ca.crt} $ProjectDir/$xDIR1/
		res=$?
		if [ $waitTimer -ge $maxWait ]; then
			echo -e "${RED}ERROR${NC} After waiting $maxWait seconds, the $ADDRESS certs were not found."
			waitToContinue $LINENO "Please ensure that $O1 is ready to receive certs."
			rsync -P ${HOST}:~/vanillaProject/$xDIR1/{server.crt,ca.crt} $ProjectDir/$xDIR1/
			errorCheck ${FUNCNAME[0]} $LINENO
			break
		fi
	done

	errorCheck ${FUNCNAME[0]} $LINENO
	rsync -r -P ${HOST}:~/vanillaProject/$xDIR2/{config.yaml,cacerts,signcerts,tlscacerts} $ProjectDir/$xDIR2/
	errorCheck ${FUNCNAME[0]} $LINENO

	echoBlue "Getting peer certs from $O1:"
	local xDIR3="organizations/peerOrganizations/${ADDRESS}/msp"
	# create directories:
	mkdir -p $ProjectDir/$xDIR3
	errorCheck ${FUNCNAME[0]} $LINENO
	# get peer certs
	rsync -r -P ${HOST}:~/vanillaProject/$xDIR3/{config.yaml,cacerts,signcerts,tlscacerts} $ProjectDir/$xDIR3/
	errorCheck ${FUNCNAME[0]} $LINENO

}
# get genesis block from other org
function getGenesis() {
	echoBlue "Running Function ${FUNCNAME[0]}"
  echo "Getting Genesis block from other org"
	local O1=${2^^}
	local o1=${2,,}
	local user=$1
	local ADDRESS="${o1}.${DOMAIN}.com"
	local HOST=${user}@${o1}.${DOMAIN}.cloudns.asia
	local FileName=$genesisBlock

 	# next get the selected block:
	rsync -r -P ${HOST}:~/vanillaProject/$FileName $ProjectDir/$FileName
	# automatically  wait up to $maxWait seconds in case other org is not yet ready
	# after $maxWait seconds will wait for manual input to continue
	res=$?
	maxWait=10 # max time to wait in seconds
	while [ $res -eq 23 ]; do  #rsync exit code 23 denotes incomplete transfer
		echoOrange "The Genesis Block was not found at $O1.  Waiting 2 seconds before retrying."
		sleep 2
		waitTimer=$(expr $waitTimer + 2)
		rsync -r -P ${HOST}:~/vanillaProject/$FileName $ProjectDir/$FileName
		res=$?
		if [ $waitTimer -ge $maxWait ]; then
			echo -e "${RED}ERROR${NC} After waiting $maxWait seconds, the genesis block was not found at $HOST."
			waitToContinue $LINENO "Please ensure that $O1 has already created the genesis block before proceeding."
			rsync -r -P ${HOST}:~/vanillaProject/$FileName $ProjectDir/$FileName
			errorCheck ${FUNCNAME[0]} $LINENO
			break
		fi
	done

}
# join peer to channel
function joinPeerToChannel() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	export CORE_PEER_ADDRESS=localhost:${peer_LISTENPORT}
	export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/tls/ca.crt

	peer channel join -b $genesisBlock --tls
	errorCheck ${FUNCNAME[0]} $LINENO
}
# add orderer to channel
function addOrdererToChannel() {
	echoBlue "Running Function ${FUNCNAME[0]}"

	if [ ! $bootstrapMethod = "none" ]; then
		echoOrange "This function is only compatable with \"none\" bootstrap option.  Stopping function"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi
	
	set -x
	osnadmin channel join --channelID $ChannelID  --config-block $genesisBlock -o $ordererAdminListenAddress --ca-file $ORDERER_CA --client-cert $ORDERER_ADMIN_TLS_SIGN_CERT --client-key $ORDERER_ADMIN_TLS_PRIVATE_KEY
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO $0

}
# configure Gossip setting for new peer:
function configureGossip() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	export CORE_PEER_GOSSIP_USELEADERELECTION=true
	export CORE_PEER_GOSSIP_ORGLEADER=false
}
# list channels
function channelList() {
	set -x
	osnadmin channel list --channelID $ChannelID  -o $ordererAdminListenAddress --ca-file $ORDERER_CA --client-cert $ORDERER_ADMIN_TLS_SIGN_CERT --client-key $ORDERER_ADMIN_TLS_PRIVATE_KEY
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO $0
}
# Add Anchor Peer
function addAnchorPeer() {
	#NOTE: this function can only be called after the orderer is brought up
	echoBlue "Running Function ${FUNCNAME[0]}"

	mkdir -p $ProjectDir/TMP
	cd $ProjectDir/TMP && rm *

	#get latest channel configuration block:  (same as fetchConfig)
	peer channel fetch config config_block.pb -c $ChannelID --orderer localhost:${orderer_LISTENPORT} --tls --cafile $ORDERER_CA
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#strip config of all non-relevant parts:
	configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
	jq .data.data[0].payload.data.config config_block.json > config.json
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#update config with new org anchor peer:
	jq '.channel_group.groups.Application.groups.'$ORG'MSP.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.'${org}'.'${DOMAIN}'.com","port": '$peer_LISTENPORT'}]},"version": "0"}}' config.json > modified_anchor_config.json
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#translate config.json back to protobuf:
	configtxlator proto_encode --input config.json --type common.Config --output config.pb
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#translate modified_anchor_config.json into protobuf:
	configtxlator proto_encode --input modified_anchor_config.json --type common.Config --output modified_anchor_config.pb
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#calculate delta:
	configtxlator compute_update --channel_id $ChannelID --original config.pb --updated modified_anchor_config.pb --output anchor_update.pb
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#convert delta protobuf back into json:
	configtxlator proto_decode --input anchor_update.pb --type common.ConfigUpdate --output anchor_update.json
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#wrap update in envelope:
	echo '{"payload":{"header":{"channel_header":{"channel_id":"'$ChannelID'", "type":2}},"data":{"config_update":'$(cat anchor_update.json)'}}}' | jq . > anchor_update_in_envelope.json
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#convert envelope & contents to protobuf:
	configtxlator proto_encode --input anchor_update_in_envelope.json --type common.Envelope --output anchor_update_in_envelope.pb
	errorCheck ${FUNCNAME[0]} $LINENO
	
	#Now ready for signoff (by new Org Peer)
	peer channel update -f anchor_update_in_envelope.pb -c $ChannelID -o localhost:$orderer_LISTENPORT --ordererTLSHostnameOverride orderer.${orgAddress} --tls --cafile $ORDERER_CA
	errorCheck ${FUNCNAME[0]} $LINENO

	cd $ProjectDir

}

# Startup Sequence
function startupSeq() {
	echoBlue "Running ${FUNCNAME[0]}"
	deleteFiles
	getFiles
	editFiles
	createOverlayNetwork
	startCAs
	setupCAusers
	generateCCP
	generateOrgDef $CORE_PEER_LOCALMSPID  # was S41MSP
	generateOrgDef $ordererName   #was s41orderer
	startNodes

}
# Onboard Sequence for Org3
function joinOrg3ToChannelSeq() {
	waitToContinue $LINENO "Before proceeding, please ensure that $Org1 and $Org2 have generated certs."
	getExtCerts $user1 $Org1
	getExtCerts $user2 $Org2
	getGenesis $user1 $Org1
	#wait for other nodes to get orgDef, package channel config update, sign, and deliver
	#Orderer:
	echoBlue "Beginning Orderer Join Process"
	waitToContinue $LINENO "Orderer: Now, wait for other orgs to get files, process config update, sign, and approve"
	addOrdererToChannel
	sleep 1
	channelList
	#Peer
	echoBlue "Beginning Peer Join Process"
	waitToContinue $LINENO "Peer: Now, wait for other orgs to get files, process config update, sign, and approve"
	joinPeerToChannel
	configureGossip
	waitToContinue $LINENO "Next: Add Anchor Peer Update:"
	addAnchorPeer

}
# Onboard Sequence for Org4  #same as for Org3, except also pulls Org3 certs
function joinOrg4ToChannelSeq() {
	waitToContinue $LINENO "Before proceeding, please ensure that $Org1, $Org2, and $Org3 have generated certs."
	getExtCerts $user1 $Org1
	getExtCerts $user2 $Org2
	getExtCerts $user3 $Org3
	getGenesis $user1 $Org1
	#wait for other nodes to get orgDef, package channel config update, sign, and deliver
	#Orderer:
	echoBlue "Beginning Orderer Join Process"
	waitToContinue $LINENO "Orderer: Wait for other orgs to get files, process config update, sign, and approve"
	addOrdererToChannel
	sleep 1
	channelList
	#Peer
	echoBlue "Beginning Peer Join Process"
	waitToContinue $LINENO "Peer: Wait for other orgs to get files, process config update, sign, and approve"
	joinPeerToChannel
	configureGossip
	waitToContinue $LINENO "Next: Add Anchor Peer Update:"
	addAnchorPeer

}



startupSeq #start own node
if [ $ORG = "$Org3" ]; then
	joinOrg3ToChannelSeq #get external certs, join peer, update anchor peer, join orderer node
elif [ $ORG = "$Org4" ]; then
	waitToContinue $LINENO "Ensure $Org3 has finished joining before proceeding"
	joinOrg4ToChannelSeq #get external certs, join peer, update anchor peer, join orderer node
else
	echo "Unexpected ORG value:$ORG"
	altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
fi

