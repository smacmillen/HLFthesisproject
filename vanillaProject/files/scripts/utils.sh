#!/bin/bash
# A handly toolbox of useful functions
# Written by Simeon MacMillen
# 2021-2-12


#---- Project Variables ----#
export ProjectName=vanillaProject
export ProjectDir=$HOME/$ProjectName
export CA_VER=1.4.9
export FABRIC_VER=2.3.1
export COUCH_VER=3.1.1

bootstrapMethod="none"  # set to "system" or "none" (note: "none" option only supported in Fabric 2.3.1 and greater)
OrgMaster="yes"

#---------------------------
# 		Organizations 			 #
Org1=OEM 
Org2=S11 
Org3=S12
Org4=S21 
Org5=S31   #x
Org6=S41   #x

user1=mina
user2=andy
user3=hans
user4=wei
user5=jane  #x
user6=san   #x
#---------------------------



#--- EXTERNAL ORG Info: ---#
x1name=$Org2
x1user=$user2
#---------------------------

#Peer Logging Level:
pLL=INFO #INFO or #DEBUG.  DEBUG = more detail
#Orderer Logging Level:
oLL=INFO #INFO or #DEBUG.  DEBUG = more detail


DOMAIN=scm
externalNetwork=supply-chain-network

ChannelProfile1=MultiOrgChannel
ChannelID=scm1   #IMPORTANT: channel names must be all lowercase, and match [a-z][a-z0-9.-]*

H=$(hostnamectl status --static)  #get machine hostname
ORG=${H^^}        #UPPERCASE NAME
org=${ORG,,}  #lowercase name
orgAddress="${org}.${DOMAIN}.com"   # was "org1.example.com"
export FABRIC_CFG_PATH=$ProjectDir/config


org1Address="${Org1,,}.${DOMAIN}.com"
org2Address="${Org2,,}.${DOMAIN}.com"
org3Address="${Org3,,}.${DOMAIN}.com"
org4Address="${Org4,,}.${DOMAIN}.com"


#############################  Peer Settings  ###############################
peerPort=7054
peer_LISTENPORT=7051
peer_CC_Port=7052
peerCA_name=ca-${org}   # was "ca-org1"
peerCA_containerName="ca_${org}"  # was "ca_org1"
peerCONFIG_YAML="${PWD}/organizations/peerOrganizations/${orgAddress}/msp/config.yaml" 
peerTLS_certFile="${PWD}/organizations/fabric-ca/${org}/tls-cert.pem" #list of comma-separated pem trusted cert files 
export CORE_PEER_LOCALMSPID="${ORG}MSP"
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${orgAddress}/users/Admin@${orgAddress}/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:${peer_LISTENPORT}
##################################################################################

#############################  Orderer Settings  ###############################
ordererPort=9054
orderer_LISTENPORT=7050
orderer_Admin_ListenPort=7053
ordererCA_name=ca-${org}-orderer  # was "ca-orderer"
ordererCA_containerName="ca_${org}_orderer" # was "ca_orderer" 
ordererName=${org}orderer
ordererCONFIG_YAML="${PWD}/organizations/ordererOrganizations/${orgAddress}/msp/config.yaml" 
ordererTLS_certFile="${PWD}/organizations/fabric-ca/${ordererName}/tls-cert.pem"  #was .../ordererOrg/tls-cert.pem
ordererTLSKey=$ProjectDir/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/tls/server.key
ordererTLSCertificate=$ProjectDir/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/tls/signcerts/cert.pem #also known as public certificate or sign certificate
ordererMSPDir=$ProjectDir/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp/
ordererAdminMSPDir=$ProjectDir/organizations/ordererOrganizations/${orgAddress}/users/Admin@${orgAddress}/msp/
orderer_MSPID=${ORG}OrdererMSP
ordererGenesisBlock=genesis.block #only used if system channel is required
genesisBlock=genesis_block.pb #application channel genesis block
ordererAdminListenAddress=localhost:${orderer_Admin_ListenPort}
ORDERER_ADMIN_TLS_SIGN_CERT=${ProjectDir}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/tls/server.crt
ORDERER_ADMIN_TLS_PRIVATE_KEY=${ProjectDir}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/tls/server.key
export ORDERER_CA=${ProjectDir}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp/tlscacerts/tlsca.${orgAddress}-cert.pem
#export ORDERER_GENERAL_LOCALMSPID=${ORG}OrdererMSP
##################################################################################


#############################  External Node Settings  ###############################
#Note: these values are automatically configured.  To edit, please use the variables at top of this document

x_ORG1=${x1name^^}          #UPPERCASE NAME 
x_Host_username=$x1user
x_org1=${x_ORG1,,}  #lowercase name 
x_org1_address="${x_org1}.${DOMAIN}.com"
x_Host1=${x_Host_username}@${x_org1}.${DOMAIN}.cloudns.asia
x_orgTLSRootCert=${PWD}/organizations/peerOrganizations/${x_org1_address}/msp/tlscacerts/ca.crt

#set same for all nodes:
x_org1_ordererPort=9054
x_org1_orderer_LISTENPORT=7050
x_org1_orderer_Admin_ListenPort=7053
x_org1_peerPort=7054
x_org1_peer_LISTENPORT=7051
x_org1_peer_CC_Port=7052



##################################################################################

#############################  Chaincode Settings  ###############################
CHAINCODE_NAME=scm
CC_PATH=$ProjectDir/CC/$CHAINCODE_NAME/pkg
CC_FILE_NAME=supplyChainTest.go
CC_LANG=golang    #valid options may include: go/golang, node, etc.
COLLECTIONS=$ProjectDir/config/collections_config.json
SP1="OR('OEMMSP.member','S11MSP.member')" 
SP2="OR('OEMMSP.member','S11MSP.member','S12MSP.member')" 
SP3="OR('OEMMSP.member','S11MSP.member','S12MSP.member','S21MSP.member')" 
SIG_POLICY=$SP3
#depreciated:
orgName=S41 #for onboarding new org
#COLLECTIONS=$ProjectDir/config/updated_collections_config.json
##################################################################################

#############################  Database Settings  ###############################
COUCH_PORT=5984
##################################################################################



#############################  Client Application ################################
appName=client
appDir=$HOME/$appName

##################################################################################




# Bash formatting codes
RED='\033[0;31m'
NC='\033[0m' #no color (reset font attributes)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
ORANGE='\033[0;33m'


# Helper Functions
function altErrorCheck(){  #similar to errorCheck, but tests provided return value ($1) instead of $?
	#example usage:  AltErrorCheck $res ${FUNCNAME[0]} $LINENO $0
	#example usage:  AltErrorCheck $res
  if [ "$1" -ne 0 ]; then
		if [ -n "$4" ]; then
			echo -e "${RED}ERROR${NC} detected in function ${ORANGE}$2${NC} at line ${ORANGE}$3${NC} of script ${ORANGE}$4${NC}. Stopping script.${NC}"
		elif [ -n "$3" ]; then 
			echo -e "${RED}ERROR${NC} detected in function ${ORANGE}$2${NC} at line ${ORANGE}$3${NC}. Stopping script.${NC}"
		elif [ -n "$2" ]; then 
			echo -e "${RED}ERROR${NC} detected in function ${ORANGE}$2${NC}. Stopping script.${NC}"
		elif [ -n "$1" ]; then 
			echo -e "${RED}ERROR${NC} detected. Stopping script.${NC}"
		else
			echo -e "${ORANGE}Arguments missing for function ${FUNCNAME[0]}.  Please correct and return script!${NC}"
		fi
	 #getLogs
   exit 1
  fi
}
function errorCheck() {  # takes function name and line number as args for a specific error message
	#can also include a third argument with $0 (filename in which error occurred)
	#example usage: errorCheck ${FUNCNAME[0]} $LINENO $0
	#example usage: errorCheck ${FUNCNAME[0]} $LINENO
  if [ "$?" -ne 0 ]; then
		if [ -n "$3" ]; then
			echo -e "${RED}ERROR${NC} detected in function ${ORANGE}$1${NC} at line ${ORANGE}$2${NC} of script ${ORANGE}$3${NC}. Stopping script.${NC}"
		else
			echo -e "${RED}ERROR${NC} detected in function ${ORANGE}$1${NC} at line ${ORANGE}$2${NC}. Stopping script.${NC}"
		fi
		#getLogs
		exit 1
	fi
}
function yamlErrorCheck() {
	#example usage: yamlErrorCheck $File $LINENO $0
	# first validate input
	if [ ! -n "$1" ]; then  # check for missing argument
		echo -e "${RED}ERROR${NC}no argument was provided to yamlErrorCheck.  Terminating script."
		echo "error generated at Line $2 in script $3"
		exit 1
	elif [ ! -f "$1" ]; then # check if file exists
		echo -e "${RED}ERROR${NC}Provided yaml file ($1) does not exist.  Stopping script."
		echo "error generated at Line $2 in script $3"
		exit 1
	fi
	# validate input file
	yq e --exit-status 'tag == "!!map" or tag== "!!seq"' $1 > /dev/null
  if [ "$?" -ne 0 ]; then
		echo -e "${RED}ERROR${NC}Not a valid yaml file - please see errors.  Stopping script."
		echo "error generated at Line $2 in script $3"
		exit 1
	fi
}
function waitToContinue() {
	# use like this:
	# waitToContinue $LINENO $optionalMessage
	echo -e "Paused at Line: ${ORANGE}$1${NC}"
	echo -e "${ORANGE}$2${NC}"
	read -n 1 -s -r -p "$(echo -e 'When ready, press any key to continue: \n\b')" && echo ""
}
getLogs() { 
	echo -e "${ORANGE}Generating logs...${NC}"
	mkdir -p $ProjectDir/logs
	DATE=$(date +"%Y%m%d_%H%M%S") 
	docker logs peer0.${org}.${DOMAIN}.com>& ${ProjectDir}/logs/${ORG}_Peer_${DATE}.log
	docker logs orderer.${org}.${DOMAIN}.com>& ${ProjectDir}/logs/${ORG}_Orderer_${DATE}.log
	sed -i 's|\x1b\[[0-9;]*m||g' ${ProjectDir}/logs/* #strip color formatting codes from logs
	echo -e "Logs generated in $ProjectDir/logs."
}


#----text formatting----#
function echoBlue() {
	echo -e "${BLUE}$1${NC}"
}
function echoRed() {
	echo -e "${RED}$1${NC}"
}
function echoOrange() {
	echo -e "${ORANGE}$1${NC}"
}
function echoGreen() {
	echo -e "${GREEN}$1${NC}"
}

