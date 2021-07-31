#!/bin/bash
# This is a simple script to setup a single host for a Fabric network
# Written by Simeon MacMillen
# 2021-2-12

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
	echoOrange "removing app wallets:"
	sudo rm -rf $appDir/wallet
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

	local FILE=organizations/peerOrganizations/${orgAddress}/connection-${org}.yaml
	echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM $DOMAIN)" > $FILE
	errorCheck ${FUNCNAME[0]} $LINENO
	yamlErrorCheck $FILE $LINENO $0

	#create alternate connection profile with localhost for non-docker client use:
	FilePath=$ProjectDir/organizations/peerOrganizations/${orgAddress} 
	jq '.peers."peer0.'${orgAddress}'".url = "grpcs://localhost:'${peer_LISTENPORT}'" | .certificateAuthorities."ca.'${orgAddress}'".url = "https://localhost:'${peerPort}'"' $FilePath/connection-${org}.json>$FilePath/alt-connection-${org}.json 
	errorCheck ${FUNCNAME[0]} $LINENO
}
# start nodes
function startNodes() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	docker-compose -f $ProjectDir/docker/docker-compose-nodes.yaml -f $ProjectDir/docker/docker-compose-couch.yaml up -d 2>&1
	errorCheck ${FUNCNAME[0]} $LINENO
}
# create Channel Genesis Block
function createGenesis() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	if [ $bootstrapMethod = "none" ]; then
		configtxgen -profile $ChannelProfile1 -outputBlock genesis_block.pb -channelID $ChannelID  --configPath $ProjectDir/config
		errorCheck ${FUNCNAME[0]} $LINENO
	elif [ $bootstrapMethod = "system" ]; then 
		mkdir -p $ProjectDir/config 
		configtxgen -profile $ChannelProfile1 -outputBlock genesis.block -channelID $ChannelID --configPath $ProjectDir/config
		errorCheck ${FUNCNAME[0]} $LINENO
	else
		echo "Unexpected bootstrapMethod value"
	fi
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
# list channels
function channelList() {
	set -x
	osnadmin channel list --channelID $ChannelID  -o $ordererAdminListenAddress --ca-file $ORDERER_CA --client-cert $ORDERER_ADMIN_TLS_SIGN_CERT --client-key $ORDERER_ADMIN_TLS_PRIVATE_KEY
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO $0
}
# get genesis block from other org
function getGenesis() {
	echoBlue "Running Function ${FUNCNAME[0]}"
  echo "Getting Genesis block from other org"
	# first pick which genesis block is needed:
  if [ $bootstrapMethod = "none" ]; then
		local DIR=$genesisBlock
  elif [ $bootstrapMethod = "system" ]; then
		local DIR=$ordererGenesisBlock
  else
    echo "Unexpected bootstrapMethod value"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0
  fi
	# next get the selected block:
	rsync -r -P ${x_Host1}:~/vanillaProject/$DIR $ProjectDir/$DIR
	# automatically  wait up to $maxWait seconds in case other org is not yet ready
	# after $maxWait seconds will wait for manual input to continue
	res=$?
	maxWait=10 # max time to wait in seconds
	while [ $res -eq 23 ]; do  #rsync exit code 23 denotes incomplete transfer
		echoOrange "The Genesis Block was not found at $x_ORG1.  Waiting 2 seconds before retrying."
		sleep 2
		waitTimer=$(expr $waitTimer + 2)
		rsync -r -P ${x_Host1}:~/vanillaProject/$DIR $ProjectDir/$DIR
		res=$?
		if [ $waitTimer -ge $maxWait ]; then
			echo -e "${RED}ERROR${NC} After waiting $maxWait seconds, the genesis block was not found at $x_Host1."
			waitToContinue $LINENO "Please ensure that $x_ORG1 has already created the genesis block before proceeding."
			rsync -r -P ${x_Host1}:~/vanillaProject/$DIR $ProjectDir/$DIR
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
	res=$?
	maxWait=10 # max time to wait in seconds
	while [ ! $res -eq 0 ]; do
		echoOrange "Error joining peer to channel.  Waiting 2 seconds before retrying."
		sleep 2
		waitTimer=$(expr $waitTimer + 2)
		peer channel join -b $genesisBlock --tls
		res=$?
		if [ $waitTimer -ge $maxWait ]; then
			echo -e "${RED}ERROR${NC}: Unable to join peer to channel after $(expr $waitTimer / 2) attempts."
			altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
		fi
	done
	errorCheck ${FUNCNAME[0]} $LINENO
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# fetch latest channel block
function peerChannelFetch() {
	echoBlue "Running Function ${FUNCNAME[0]}"

	peer channel fetch newest mychannel.block -c $ChannelID --orderer localhost:${orderer_LISTENPORT} --tls --cafile $ORDERER_CA
	errorCheck ${FUNCNAME[0]} $LINENO
}
#---------------- Chaincode functions---------------------------------
# get version of chaincode currently committed to peer
function getCCversionAUTO(){
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	export CORE_PEER_ADDRESS=localhost:${peer_LISTENPORT}
	export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/tls/ca.crt
	#read installed chaincode version and sequence:
	export RETURNVAL=$(peer lifecycle chaincode -C $ChannelID querycommitted | sed -n "/$CHAINCODE_NAME/{p}")
	errorCheck ${FUNCNAME[0]} $LINENO
	getVersion=$(echo $RETURNVAL | grep -o -P '(?<=Version: ).*(?=, Sequence)')
	getSequence=$(echo $RETURNVAL | grep -o -P '(?<=Sequence: ).*(?=, Endorsement)')
	echo -e "The currently installed chaincode \"${CHAINCODE_NAME}\" is at ${GREEN}Version ${getVersion} ${NC}and ${GREEN}Sequence ${getSequence}${NC}"
	echo "Auto-incrementing for current install..."
	#auto-increment chaincode version and sequence:
	CC_VERSION=$(expr $getVersion + 1)
	SEQ=$(expr $getSequence + 1) #Integer only!
	echo -e "Installing Chaincode \"${CHAINCODE_NAME}\" at ${ORANGE}Version ${CC_VERSION} ${NC}and ${ORANGE}Sequence ${SEQ}${NC}."
	errorCheck ${FUNCNAME[0]} $LINENO
}
# package CC
function packageCC(){
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	mkdir -p $CC_PATH
	set -x
	peer lifecycle chaincode package $CC_PATH/${CHAINCODE_NAME}_${CC_VERSION}.tar.gz --path $CC_PATH/../source --lang $CC_LANG --label ${CHAINCODE_NAME}_${CC_VERSION}
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO $0
	ls -l $CC_PATH/
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# install CC
function installCC(){
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	#setVAR #troubleshooting: set variables
	set -x
	peer lifecycle chaincode install $CC_PATH/${CHAINCODE_NAME}_${CC_VERSION}.tar.gz
	res=$?
	{ set +x; } 2>/dev/null 
	#altErrorCheck $res ${FUNCNAME[0]} $LINENO $0 #will error if already installed
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# get installed CC ID
function getChaincodeID() {
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	#setVAR #troubleshooting: set variables
	#find line matching desired chaincode name: ${CHAINCODE_NAME}_${CC_VERSION}:
	input=$(peer lifecycle chaincode queryinstalled  | sed -n "/${CHAINCODE_NAME}_${CC_VERSION}/{p}")
	#strip text to get chaincode ID:
	ccID=$( echo $input | sed "s/^.*\(${CHAINCODE_NAME}.*,\).*\$/\1/" | sed 's/.$//')
	returnedVer=$(echo $input | sed 's/^.*_//') #get value after last underscore
	if [[ $returnedVer != $CC_VERSION ]] #validate against expected version #
	then 
		echo -e "${ORANGE}Problem getting correct Chaincode ID${NC}"
		echo "List of installed chaincodes:"
		peer lifecycle chaincode queryinstalled
		echo -e "${RED}CC version retrieved ($returnedVer) does not match desired version ($CC_VERSION). Terminating Program.${NC}"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi
	export NEW_CC_PACKAGE_ID=$ccID
	errorCheck ${FUNCNAME[0]} $LINENO
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# approve for my org
function approveForOrg(){
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	export CORE_PEER_ADDRESS=localhost:${peer_LISTENPORT}
	export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/tls/ca.crt
	#setVAR #troubleshooting: set variables
	set -x
	peer lifecycle chaincode approveformyorg -o localhost:${orderer_LISTENPORT}  --ordererTLSHostnameOverride orderer.${orgAddress} --channelID $ChannelID --name ${CHAINCODE_NAME} --version ${CC_VERSION} --collections-config $COLLECTIONS --signature-policy $SIG_POLICY --package-id $NEW_CC_PACKAGE_ID --sequence ${SEQ} --tls --cafile $ORDERER_CA 
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO $0
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# check if ready to commit
function checkIfReadyToCommit(){
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	#setVAR #troubleshooting: set variables
	sleep 1
	set -x
	peer lifecycle chaincode checkcommitreadiness -o orderer.${orgAddress}:${orderer_LISTENPORT} --channelID $ChannelID --tls --cafile $ORDERER_CA --name ${CHAINCODE_NAME} --version ${CC_VERSION} --sequence ${SEQ} --signature-policy $SIG_POLICY --collections-config $COLLECTIONS --output json 
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO $0
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# commit CC - docker version
function commitCC() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	#function run inside docker to allow for proper hostname resolution of other containers on network
	#dockerCommitCC.sh file and provided vars must be modified as necessary depending on number of organizations in channel
	set -x
	docker exec -it \
		-e x_org1_address=$x_org1_address \
		-e x_org1_peer_LISTENPORT=$x_org1_peer_LISTENPORT \
		-e org1Address=$org1Address \
		-e org2Address=$org2Address \
		-e org3Address=$org3Address \
		-e org4Address=$org4Address \
		-e ChannelID=$ChannelID \
		-e CHAINCODE_NAME=$CHAINCODE_NAME \
		-e CC_VERSION=$CC_VERSION \
		-e SEQ=$SEQ \
		-e COLLECTIONS_NAME="collections_config.json" \
		-e SIG_POLICY=$SIG_POLICY \
		cli ./dockerCommitCC.sh #run script inside container
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO $0
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# get packaged chaincode from master node
function getCCPackage() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	mkdir -p $CC_PATH
	rsync -P ${x_Host1}:~/vanillaProject/CC/$CHAINCODE_NAME/pkg/${CHAINCODE_NAME}_${CC_VERSION}.tar.gz $CC_PATH
	# automatically  wait up to $maxWait seconds in case other org is not yet ready
	# after $maxWait seconds will wait for manual input to continue
	res=$?
	maxWait=10 # max time to wait in seconds
	while [ $res -eq 23 ]; do  #rsync exit code 23 denotes incomplete transfer
		echoOrange "The chaincode package was not found at $x_ORG1.  Waiting 2 seconds before retrying."
		sleep 2
		waitTimer=$(expr $waitTimer + 2)
		rsync -P ${x_Host1}:~/vanillaProject/CC/$CHAINCODE_NAME/pkg/${CHAINCODE_NAME}_${CC_VERSION}.tar.gz $CC_PATH
		res=$?
		if [ $waitTimer -ge $maxWait ]; then
			echo -e "${RED}ERROR${NC} After waiting $maxWait seconds, the chaincode package was not found at $x_Host1."
			waitToContinue $LINENO "Please ensure that $x_ORG1 has already packaged the chaincode before proceeding."
			rsync -P ${x_Host1}:~/vanillaProject/CC/$CHAINCODE_NAME/pkg/${CHAINCODE_NAME}_${CC_VERSION}.tar.gz $CC_PATH
			errorCheck ${FUNCNAME[0]} $LINENO
			break
		fi
	done

}
# query committed chaincode
function queryCommitted() {
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	peer lifecycle chaincode -C $ChannelID querycommitted
	errorCheck ${FUNCNAME[0]} $LINENO $0
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# generate environmental variable file for javascript client application use:
function generateJsEnv() {
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	echo -e "\
		ORG = $ORG \n\
		org = $org \n\
		ChannelID = $ChannelID \n\
		CHAINCODE_NAME = $CHAINCODE_NAME \n\
		CORE_PEER_LOCALMSPID = $CORE_PEER_LOCALMSPID \n\
		ProjectName = $ProjectName \n\
		appName = $appName \n\
		orgAddress = $orgAddress \n\
		x_org1_address = $x_org1_address \n\
		x_org1 = $x_org1 \n\
		" > $appDir/.env
	[ -f $appDir/.env ]
	errorCheck ${FUNCNAME[0]} $LINENO $0
	cp $appDir/.env $HOME/NonDockerClient/
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
# update CC
function upgradeCC(){  #can use to update collections config 
	echo -e "${BLUE}Running function ${FUNCNAME[0]}${NC}"
	#setVAR #troubleshooting: set variables
	export CORE_PEER_ADDRESS=localhost:${peer_LISTENPORT}
	export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/tls/ca.crt
	#local COLL=config/updated_collections_config.json
	#local SP=$SIG_POLICY  ##OR use new sig policy below:
	#orgName=${1^^}
	#local SP=$(echo $SIG_POLICY | head -c -3 )\',\'${orgName}MSP.member\'\)
	set -x
	peer chaincode upgrade -o localhost:${orderer_LISTENPORT}  --ordererTLSHostnameOverride orderer.${orgAddress} --channelID $ChannelID --name $CHAINCODE_NAME --version $CC_VERSION --signature-policy $SIG_POLICY  --collections-config $COLLECTIONS --tls --cafile $ORDERER_CA -c '{"Args":["init"]}'
	res=$?
	{ set +x; } 2>/dev/null 
	#altErrorCheck $res ${FUNCNAME[0]} $LINENO $0 #will error if already installed
	echo -e "${GREEN}${FUNCNAME[0]} completed${NC}"
}
#---------------- Organization on-boarding functions---------------------------------
# fetch channel config block
function fetchConfig() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	errorCheck ${FUNCNAME[0]} $LINENO
	peer channel fetch config config_block.pb -c $ChannelID --orderer localhost:${orderer_LISTENPORT} --tls --cafile $ORDERER_CA
	errorCheck ${FUNCNAME[0]} $LINENO
}
# convert config to json
function pbToJSON() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
	jq .data.data[0].payload.data.config config_block.json > config.json
	errorCheck ${FUNCNAME[0]} $LINENO
}
# fetch org definition
function fetchOrgDef() {
	# $1 = username $2 = orgID (e.g. S11)
	echoBlue "Running Function ${FUNCNAME[0]}"
	rsync -P $1@${2,,}.scm.cloudns.asia:~/vanillaProject/TMP/${2^^}MSP.json  $ProjectDir/TMP/

	# automatically  wait up to $maxWait seconds in case other org is not yet ready
	# after $maxWait seconds will wait for manual input to continue
	res=$?
	maxWait=10 # max time to wait in seconds
	while [ $res -eq 23 ]; do  #rsync exit code 23 denotes incomplete transfer
		echoOrange "The organization definition was not found at $2.  Waiting 2 seconds before retrying."
		sleep 2
		waitTimer=$(expr $waitTimer + 2)
		rsync -P $1@${2,,}.scm.cloudns.asia:~/vanillaProject/TMP/${2^^}MSP.json  $ProjectDir/TMP/
		res=$?
		if [ $waitTimer -ge $maxWait ]; then
			echo -e "${RED}ERROR${NC} After waiting $maxWait seconds, the org def was not found at $2."
			waitToContinue $LINENO "Please ensure that $2 has already created the org def file before proceeding."
			rsync -P $1@${2,,}.scm.cloudns.asia:~/vanillaProject/TMP/${2^^}MSP.json  $ProjectDir/TMP/
			errorCheck ${FUNCNAME[0]} $LINENO
			break
		fi
	done

	errorCheck ${FUNCNAME[0]} $LINENO
}
# append org definition
function appendOrgDef() {
	#NOTE: this function cannot be called the same for both ORG and ORDERER ORG due to orderer naming case difference
	echoBlue "Running Function ${FUNCNAME[0]}"
	jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'${1^^}MSP'":.[1]}}}}}' config.json ${1^^}MSP.json > modified_config.json
	errorCheck ${FUNCNAME[0]} $LINENO
}
# encode json in pb
function encodeToPB() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	configtxlator proto_encode --input config.json --type common.Config --output config.pb
	errorCheck ${FUNCNAME[0]} $LINENO
	configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
	errorCheck ${FUNCNAME[0]} $LINENO
}
# calculate deltas
function calculateDeltas() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	configtxlator compute_update --channel_id $ChannelID --original config.pb --updated modified_config.pb --output ${1,,}_update.pb
	errorCheck ${FUNCNAME[0]} $LINENO
}
# decode delta to json
function decodeDelta() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	configtxlator proto_decode --input ${1,,}_update.pb --type common.ConfigUpdate --output ${1,,}_update.json
	errorCheck ${FUNCNAME[0]} $LINENO
}
# add envelope back to decoded delta:
function reEnvelope() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	echo '{"payload":{"header":{"channel_header":{"channel_id":"'${ChannelID}'", "type":2}},"data":{"config_update":'$(cat ${1,,}_update.json)'}}}' | jq . > ${1,,}_update_in_envelope.json
	errorCheck ${FUNCNAME[0]} $LINENO
}
# convert envelope back to pb
function envelopeToPB() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	configtxlator proto_encode --input ${1,,}_update_in_envelope.json --type common.Envelope --output ${1,,}_update_in_envelope.pb
	errorCheck ${FUNCNAME[0]} $LINENO
}
# sign update as current org
function signConfigUpdate() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	#this command works fine for onboarding peers:
	peer channel signconfigtx -f ${1,,}_update_in_envelope.pb

	#Try adding tls, certs, etc.:
	#peer channel signconfigtx -f ${1,,}_update_in_envelope.pb -o localhost:${orderer_LISTENPORT} --ordererTLSHostnameOverride orderer.${orgAddress} --tls --cafile $ORDERER_CA --certfile $ORDERER_ADMIN_TLS_SIGN_CERT --keyfile $ORDERER_ADMIN_TLS_PRIVATE_KEY
	errorCheck ${FUNCNAME[0]} $LINENO
}
# append ORDERER org definition
function appendOrgDef_ORDERER() {
	#NOTE: this function cannot be called the same for both ORG and ORDERER ORG due to orderer naming case difference
	##Note: not sure if the NAMEMSP should be orderer name (s41orderer) or id (S41OrdererMSP)?
	echoBlue "Running Function ${FUNCNAME[0]}"
	#1 add organization definition:
	echo "Adding orderer organization Profile to config block:"
	local orgID=${1,,}
	local PORT=$2
	jq -s '.[0] * {"channel_group":{"groups":{"Orderer":{"groups": {"'$orgID'orderer":.[1]}}}}}' config.json ${orgID}orderer.json > config1.json
	errorCheck ${FUNCNAME[0]} $LINENO

	#2 add client_tls_cert, server_tls_cert, host, port:
	echo "Adding orderer to Consenters List:"
	#convert cert to base64 and remove line breaks:
	local cert=`base64 $ProjectDir/organizations/ordererOrganizations/${orgID}.scm.com/orderers/orderer.${orgID}.scm.com/tls/server.crt | sed ':a;N;$!ba;s/\n//g'`
	#insert values into config:
	cat config1.json | jq '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters += [{"client_tls_cert": "'$cert'", "host": "orderer.'$orgID'.scm.com", "port": '$PORT', "server_tls_cert": "'$cert'"}] ' > config2.json
	errorCheck ${FUNCNAME[0]} $LINENO


	#TODO: delete this line when/if enabling step 3:
#cp config2.json modified_config.json


#	#3 add orderer endpoint url:port
	echo "Adding orderer endpoint:"
	jq '.channel_group.values.OrdererAddresses.value.addresses += ["orderer.'$orgID'.scm.com:'$PORT'"]' config2.json > modified_config.json
	errorCheck ${FUNCNAME[0]} $LINENO
}
# fetch org ORDERER definition
function fetchOrgDef_ORDERER() {
	# $1 = username $2 = orgID (e.g. S11)
	echoBlue "Running Function ${FUNCNAME[0]}"
	rsync -P $1@${2,,}.scm.cloudns.asia:~/vanillaProject/TMP/${2,,}orderer.json  $ProjectDir/TMP/
	errorCheck ${FUNCNAME[0]} $LINENO
}
#-----files from alternate server---
# get config Update pb
function getConfigUpdatePB() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	rsync -P ${1,,}@${2,,}.scm.cloudns.asia:~/$ProjectName/TMP/${3,,}_update_in_envelope.pb $ProjectDir/TMP/
	errorCheck ${FUNCNAME[0]} $LINENO

}
# sign and update channel (as last org required to make update)
function channelUpdate() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	peer channel update -f $ProjectDir/TMP/${1,,}_update_in_envelope.pb -c ${ChannelID} -o localhost:${orderer_LISTENPORT} --ordererTLSHostnameOverride orderer.${orgAddress} --tls --cafile $ORDERER_CA --certfile $ORDERER_ADMIN_TLS_SIGN_CERT --keyfile $ORDERER_ADMIN_TLS_PRIVATE_KEY
	errorCheck ${FUNCNAME[0]} $LINENO
}
# onboard new Peer organization (as first org: process config updates)
function onboardPeerConfigUpdate() {
	echoBlue "Running Function ${FUNCNAME[0]}"

	local user=$1
	local orgName=${2,,}

	mkdir -p $ProjectDir/TMP
	cd $ProjectDir/TMP && rm *

	# first for peer:

	echo "setting up new peer org:"
	fetchConfig
	pbToJSON
	fetchOrgDef $user $orgName # for orderer, use $user ${orgName}orderer
	appendOrgDef $orgName
	encodeToPB
	calculateDeltas $orgName
	decodeDelta $orgName
	reEnvelope $orgName
	envelopeToPB $orgName
	signConfigUpdate $orgName

	errorCheck ${FUNCNAME[0]} $LINENO
	cd $ProjectDir
}
# onboard new Orderer organization (as first org: process config updates)
function onboardOrdererConfigUpdate() {
	echoBlue "Running Function ${FUNCNAME[0]}"

	local user=${1,,} 
	local orgName=${2,,}
	local PORT=$3

	mkdir -p $ProjectDir/TMP
	cd $ProjectDir/TMP && rm *

	echo "setting up new orderer org:"

	#get the latest channel configuration block:
	peer channel fetch config config_block.pb -c $ChannelID --orderer localhost:${orderer_LISTENPORT} --tls --cafile $ORDERER_CA
	errorCheck ${FUNCNAME[0]} $LINENO

	#convert to JSON and strip config of all non-relevant parts:
	configtxlator proto_decode --input config_block.pb --type common.Block --output config_block.json
	jq .data.data[0].payload.data.config config_block.json > config.json

	# get the new Orderer org definition:
	rsync -P $user@$orgName.scm.cloudns.asia:~/vanillaProject/TMP/${orgName}orderer.json  $ProjectDir/TMP/
	errorCheck ${FUNCNAME[0]} $LINENO

	# update config with new Orderer org definition:
	appendOrgDef_ORDERER $orgName $PORT

	#translate config.json back to protobuf:
	configtxlator proto_encode --input config.json --type common.Config --output config.pb
	errorCheck ${FUNCNAME[0]} $LINENO
	configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
	errorCheck ${FUNCNAME[0]} $LINENO

	#calculate delta:
	configtxlator compute_update --channel_id $ChannelID --original config.pb --updated modified_config.pb --output ${orgName}_update.pb
	errorCheck ${FUNCNAME[0]} $LINENO

	#convert delta protobuf back into json:
	configtxlator proto_decode --input ${orgName}_update.pb --type common.ConfigUpdate --output ${orgName}_update.json
	errorCheck ${FUNCNAME[0]} $LINENO

	#wrap update in envelope:
	echo '{"payload":{"header":{"channel_header":{"channel_id":"'${ChannelID}'", "type":2}},"data":{"config_update":'$(cat ${orgName}_update.json)'}}}' | jq . > ${orgName}_update_in_envelope.json
	errorCheck ${FUNCNAME[0]} $LINENO

	#convert envelope & contents to protobuf:
	configtxlator proto_encode --input ${orgName}_update_in_envelope.json --type common.Envelope --output ${orgName}_update_in_envelope.pb
	errorCheck ${FUNCNAME[0]} $LINENO

	#Now ready for signoff
	local CORE_PEER_LOCALMSPID=$orderer_MSPID #switch cli to use orderer org ID
	local CORE_PEER_MSPCONFIGPATH=$ordererAdminMSPDir #sign as orderer admin
	peer channel signconfigtx -f ${orgName}_update_in_envelope.pb
	errorCheck ${FUNCNAME[0]} $LINENO
	cd $ProjectDir
}
# onboard organization (as final org to approve) #requires 3 arguments
function onboardingFinalApprove() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	#usage: onboardingFinalApprove orgType fromUser fromOrg
	#example usage: onboardingFinalApprove peer S11 andy
	#example usage: onboardingFinalApprove orderer S12 hans

	#ensure arguments are provided:
	if [ ! -n "$3" ]; then
		echo "${RED}ERROR:${NC} Function is missing input arguments"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi

	mkdir -p $ProjectDir/TMP
	cd $ProjectDir/TMP

	#new org:
	local newOrg=${xOrg,,}
	local newUser=$xUser
	#copy signed config update from this org:
	local fromOrg=${Org1,,}
	local fromUser=$user1

	echo "Get signed config update to onboard new organization:"
	rsync -P ${fromUser}@${fromOrg}.scm.cloudns.asia:~/$ProjectName/TMP/${newOrg}_update_in_envelope.pb $ProjectDir/TMP/
	errorCheck ${FUNCNAME[0]} $LINENO

	#For last organization to approve:
	#set ORG Identitty to Orderer if necessary (default is Peer ID from utils.sh)
	if [ -n "$1" ] && [ "$1" = "orderer" ]; then
		local CORE_PEER_LOCALMSPID=$orderer_MSPID
		local CORE_PEER_MSPCONFIGPATH=$ordererAdminMSPDir
	fi
	peer channel update -f $ProjectDir/TMP/${newOrg}_update_in_envelope.pb -c ${ChannelID} -o localhost:${orderer_LISTENPORT} --ordererTLSHostnameOverride orderer.${orgAddress} --tls --cafile $ORDERER_CA --certfile $ORDERER_ADMIN_TLS_SIGN_CERT --keyfile $ORDERER_ADMIN_TLS_PRIVATE_KEY
	errorCheck ${FUNCNAME[0]} $LINENO

	cd $ProjectDir


}
# onboard organization (as non-final org to approve) #requires 3 arguments 
function onboardingNextApprove() {
	echoBlue "Running Function ${FUNCNAME[0]}"
	#usage: onboardingNextApprove orgType fromUser fromOrg
	#example usage: onboardingNextApprove peer S11 andy
	#example usage: onboardingNextApprove orderer S12 hans

	#ensure arguments are provided:
	if [ ! -n "$3" ]; then
		echo "${RED}ERROR:${NC} Function is missing input arguments"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi

	mkdir -p $ProjectDir/TMP
	cd $ProjectDir/TMP
	errorCheck ${FUNCNAME[0]} $LINENO

	#new org:
	local newOrg=${xOrg,,}
	local newUser=$xUser
	#copy signed config update from this org:
	local fromOrg=${3,,}
	local fromUser=${2}

	echo "Get signed config update to onboard new organization:"
	rsync -P ${fromUser}@${fromOrg}.scm.cloudns.asia:~/$ProjectName/TMP/${newOrg}_update_in_envelope.pb $ProjectDir/TMP/
	errorCheck ${FUNCNAME[0]} $LINENO

	#set ORG Identitty to Orderer if necessary (default is Peer ID from utils.sh)
	if [ -n "$1" ] && [ "$1" = "orderer" ]; then
		local CORE_PEER_LOCALMSPID=$orderer_MSPID
		local CORE_PEER_MSPCONFIGPATH=$ordererAdminMSPDir
	fi
	#sign config update:
	echo "Signing Config Update:"
	peer channel signconfigtx -f ${newOrg}_update_in_envelope.pb

	errorCheck ${FUNCNAME[0]} $LINENO
	cd $ProjectDir


}

#---------------- User Scripts---------------------------------
# bootstrap organization
function setupOrg() {
	if [ $ORG = "$Org1" ] || [ $ORG = "$Org2" ]; then
		echoBlue "Running Function ${FUNCNAME[0]} as $ORG"
	else
		echoOrange "Skipping ${FUNCNAME[0]} as $ORG"
		return
	fi
	checkForBinaries
	deleteFiles
	#waitToContinue $LINENO "Ensure other orgs have deleted files before continuing"
	getFiles
	editFiles
	createOverlayNetwork
	startCAs
	setupCAusers
	generateCCP
	generateJsEnv
	#waitToContinue $LINENO "Please ensure that other org is ready to receive certs."
	verifyExtOrgOnline
	#getExtCerts
	getExtCerts $x1user $x_ORG1
	addExternalOrgs
	#waitToContinue $LINENO "Please ensure that external certs are copied before proceeding"
	if [ $OrgMaster = "yes" ]; then
		echoOrange "Organization configuration set to \"Master\"."
		createGenesis  #only one org will create the genesis block
	elif [ $OrgMaster = "no" ]; then 
		echoOrange "Organization configuration set to \"normal\" (non-Master)."
		#waitToContinue $LINENO "Please ensure that genesis block has been created before proceeding"
		getGenesis
	else
		echoRed "Organization Master Setting not detected.  Please correct in utils.sh"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi
	startNodes
	addOrdererToChannel  #only for non-system bootstrap 
	channelList
	joinPeerToChannel
}
# onboard Org3 Orderer + Peer
function onboardOrg3() {
	if [ $ORG = "$Org1" ] || [ $ORG = "$Org2" ]; then
		echoBlue "Running Function ${FUNCNAME[0]} as $ORG"
	else
		echoOrange "Skipping ${FUNCNAME[0]} as $ORG"
		return
	fi


	xOrg=$Org3
	xUser=$user3

	waitToContinue $LINENO "Before continuing, please have $xOrg setup nodes using \"outsideOrg.sh\" script."

	echoBlue "Getting new organization certificates:"
	getExtCerts $xUser ${xOrg,,}

	waitToContinue $LINENO "Next up: add $xOrg orderer organization"
	if [ $ORG = "$Org1" ]; then
		onboardOrdererConfigUpdate $xUser $xOrg $orderer_LISTENPORT
		waitToContinue $LINENO "Have $Org2 approve and $xOrg join before proceeding"
	elif [ $ORG = "$Org2" ]; then
		waitToContinue $LINENO "Have $Org1 create and sign transaction before proceeding"
		onboardingFinalApprove orderer $user1 $Org1
		echoOrange "Next have $xOrg complete channel join process"
	else
		echoOrange "Unexpected ORG value:$ORG"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi

	waitToContinue $LINENO "Next up: add $xOrg peer organization"
	if [ $ORG = "$Org1" ]; then
		onboardPeerConfigUpdate $xUser $xOrg
		waitToContinue $LINENO "Have $Org2 approve and $xOrg join before proceeding"
	elif [ $ORG = "$Org2" ]; then
		waitToContinue $LINENO "Have $Org1 create and sign transaction before proceeding"
		onboardingFinalApprove peer $user1 $Org1
		echoOrange "Next have $xOrg complete channel join process"
	else
		echoOrange "Unexpected ORG value:$ORG"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi

	rm -r $ProjectDir/TMP
	errorCheck ${FUNCNAME[0]} $LINENO
}
# onboard Org4 Orderer + Peer  EXPERIMENTAL (NOT FULLY TESTED YET)
function onboardOrg4() {
	if [ $ORG = "$Org1" ] || [ $ORG = "$Org2" ] || [ $ORG = "$Org3" ]; then
		echoBlue "Running Function ${FUNCNAME[0]} as $ORG"
	else
		echoOrange "Skipping ${FUNCNAME[0]} as $ORG"
		return
	fi
	
	xOrg=$Org4
	xUser=$user4

	waitToContinue $LINENO "Before continuing, please have $xOrg setup nodes using \"outsideOrg.sh\" script."

	echoBlue "Getting new organization certificates:"
	getExtCerts $xUser ${xOrg,,}

	waitToContinue $LINENO "Next up: add $xOrg orderer organization"
	if [ $ORG = "$Org1" ]; then
		onboardOrdererConfigUpdate $xUser $xOrg $orderer_LISTENPORT
		waitToContinue $LINENO "Have $Org2 and $Org3 both approve and $xOrg join before proceeding"
	elif [ $ORG = "$Org2" ]; then
		waitToContinue $LINENO "Have $Org1 create and sign transaction before proceeding"
		onboardingNextApprove orderer $user1 $Org1
		echoOrange "Next have $Org3 sign-off on update"
	elif [ $ORG = "$Org3" ]; then
		waitToContinue $LINENO "Have $Org1 create and $Org2 sign transaction before proceeding"
		onboardingFinalApprove orderer $user2 $Org2
		echoOrange "Next have $xOrg complete channel join process"
	else
		echoOrange "Unexpected ORG value:$ORG"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi

	waitToContinue $LINENO "Next up: add $xOrg peer organization"
	if [ $ORG = "$Org1" ]; then
		onboardPeerConfigUpdate $xUser $xOrg
		waitToContinue $LINENO "Have $Org2 and $Org3 approve and $xOrg join before proceeding"
	elif [ $ORG = "$Org2" ]; then
		waitToContinue $LINENO "Have $Org1 create and sign transaction before proceeding"
		onboardingNextApprove peer $user1 $Org1
		echoOrange "Next have $Org3 sign-off on update"
	elif [ $ORG = "$Org3" ]; then
		waitToContinue $LINENO "Have $Org1 create and $Org2 sign transaction before proceeding"
		onboardingFinalApprove peer $user2 $Org2
		echoOrange "Next have $xOrg complete channel join process"
	else
		echoOrange "Unexpected ORG value:$ORG"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi

	rm -r $ProjectDir/TMP
	errorCheck ${FUNCNAME[0]} $LINENO
}
# install/upgrade chaincode
function installUpgradeCC() {
	getCCversionAUTO
	if [ $OrgMaster = "yes" ]; then
		echoOrange "Organization configuration set to \"Master\"."
		packageCC
	elif [ $OrgMaster = "no" ]; then 
		echoOrange "Organization configuration set to \"normal\" (non-Master)."
		getCCPackage
		#packageCC
	else
		echoRed "Organization Master Setting not detected.  Please correct in utils.sh"
		altErrorCheck 1 ${FUNCNAME[0]} $LINENO $0 #exits and prints line number
	fi
	installCC
	getChaincodeID
	approveForOrg
	waitToContinue $LINENO "Now ready to check if other org has approved:"
	checkIfReadyToCommit
		waitToContinue $LINENO "Please ensure that other org is ready"
	if [ $OrgMaster = "yes" ]; then
		commitCC
	fi
	queryCommitted
}


#setupOrg #start Org1 and Org2
#onboardOrg3
#onboardOrg4
#waitToContinue $LINENO "Next up: install CC!"
installUpgradeCC

