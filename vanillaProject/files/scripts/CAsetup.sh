#!/bin/bash
# This simple script provides the code for registering and enrolling CA users

#common function:
function registerUser() {  #arguments:
  echoBlue "Registering $ID_type $userName"
  set -x
  fabric-ca-client register --caname $CA_name --id.name $userName --id.secret $password --id.type $ID_type --tls.certfiles $TLS_certFile
	res=$?
  { set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO
}
#org helper functions:
function enroll_CA_admin() {
	# Note: unlike normal users, the CA admin does not need to be manually registered prior to enrollment
  echoBlue "Enrolling the CA admin"
  mkdir -p organizations/peerOrganizations/${orgAddress}/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/${orgAddress}/

  set -x
  fabric-ca-client enroll -u https://admin:adminpw@localhost:${Port} --caname ${CA_name} --tls.certfiles $TLS_certFile
	res=$?
  { set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-${Port}-${CA_name}.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-${Port}-${CA_name}.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-${Port}-${CA_name}.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-${Port}-${CA_name}.pem
    OrganizationalUnitIdentifier: orderer" > ${peerCONFIG_YAML}

	yamlErrorCheck $peerCONFIG_YAML $LINENO

}
function generatePeer_TLScerts() {
  echoBlue "Generating the peer0-tls certificates"
  set -x
  fabric-ca-client enroll -u $CA_server_url --caname ${CA_name} -M $TLS_dir --enrollment.profile tls --csr.hosts $CSR_hosts --csr.hosts localhost --tls.certfiles $TLS_certFile
	res=$?
  { set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO

  cp "${TLS_dir}/tlscacerts/"* "${TLS_dir}/ca.crt"
	altErrorCheck $? ${FUNCNAME[0]} $LINENO
  cp "${TLS_dir}/signcerts/"* "${TLS_dir}/server.crt"
	altErrorCheck $? ${FUNCNAME[0]} $LINENO
  cp "${TLS_dir}/keystore/"* "${TLS_dir}/server.key"
	altErrorCheck $? ${FUNCNAME[0]} $LINENO

  mkdir -p "${PWD}/organizations/peerOrganizations/${orgAddress}/msp/tlscacerts"
  cp "${TLS_dir}/tlscacerts/"* "${PWD}/organizations/peerOrganizations/${orgAddress}/msp/tlscacerts/ca.crt"
	altErrorCheck $? ${FUNCNAME[0]} $LINENO

  mkdir -p "${PWD}/organizations/peerOrganizations/${orgAddress}/tlsca"
  cp "${TLS_dir}/tlscacerts/"* "${PWD}/organizations/peerOrganizations/${orgAddress}/tlsca/tlsca.${orgAddress}-cert.pem"
	altErrorCheck $? ${FUNCNAME[0]} $LINENO

  mkdir -p "${PWD}/organizations/peerOrganizations/${orgAddress}/ca"
  cp "${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/msp/cacerts/"* "${PWD}/organizations/peerOrganizations/${orgAddress}/ca/ca.${orgAddress}-cert.pem"
	altErrorCheck $? ${FUNCNAME[0]} $LINENO

}
#orderer helper functions
function enrollCA_OrdererAdmin() {
	echoBlue "Enrolling the CA admin"
	mkdir -p organizations/ordererOrganizations/${orgAddress}

	export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/${orgAddress}

	set -x
	fabric-ca-client enroll -u https://admin:adminpw@localhost:${ordererPort} --caname ${ordererCA_name} --tls.certfiles $TLS_certFile
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO

  echo "NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-${ordererPort}-${ordererCA_name}.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-${ordererPort}-${ordererCA_name}.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-${ordererPort}-${ordererCA_name}.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-${ordererPort}-${ordererCA_name}.pem
    OrganizationalUnitIdentifier: orderer" > $ordererCONFIG_YAML

  yamlErrorCheck $ordererCONFIG_YAML $LINENO

}
function generateOrderer_TLScerts() {
	echoBlue "Generating the orderer-tls certificates"
	set -x
	fabric-ca-client enroll -u $CA_server_url --caname ${ordererCA_name} -M $TLS_dir --enrollment.profile tls --csr.hosts $CSR_hosts --csr.hosts localhost --tls.certfiles $TLS_certFile
	res=$?
	{ set +x; } 2>/dev/null
	altErrorCheck $res ${FUNCNAME[0]} $LINENO

		cp "${TLS_dir}/tlscacerts/"* "${TLS_dir}/ca.crt"
		altErrorCheck $? ${FUNCNAME[0]} $LINENO
		cp "${TLS_dir}/signcerts/"* "${TLS_dir}/server.crt"
		altErrorCheck $? ${FUNCNAME[0]} $LINENO
		cp "${TLS_dir}/keystore/"* "${TLS_dir}/server.key"
		altErrorCheck $? ${FUNCNAME[0]} $LINENO

		mkdir -p "${PWD}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp/tlscacerts"
		cp "${TLS_dir}/tlscacerts/"* "${PWD}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp/tlscacerts/tlsca.${orgAddress}-cert.pem"
		altErrorCheck $? ${FUNCNAME[0]} $LINENO

		mkdir -p "${PWD}/organizations/ordererOrganizations/${orgAddress}/msp/tlscacerts"
		cp "${TLS_dir}/tlscacerts/"* "${PWD}/organizations/ordererOrganizations/${orgAddress}/msp/tlscacerts/tlsca.${orgAddress}-cert.pem"
		altErrorCheck $? ${FUNCNAME[0]} $LINENO

	}
#generate org and orderer:
function createOrg() {
  echoOrange "Beginning to Setup Peer CA"

	#set variables
	local TLS_certFile=$peerTLS_certFile
	local Port=$peerPort
  local CA_name=$peerCA_name

  echoOrange "Step 1: enroll Org CA admin"
		enroll_CA_admin

  echoOrange "Step 2a: Register the Peer"
	#step 2:
		# peer0: register
			local userName=peer0
			local password=peer0pw
			local ID_type=peer
			registerUser

    echoOrange "Step 2b: Generate the Peer Node MSP"
		# peer0: generate MSP
			local CA_server_url="https://${userName}:${password}@localhost:${Port}"
			local MSP_dir="${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/msp" 
			local CSR_hosts=peer0.${orgAddress} #comma-separated list of CSR hosts 
			# other options are available, see: 
			# https://hyperledger-fabric-ca.readthedocs.io/en/release-1.4/clientcli.html#fabric-ca-client-s-cli
			set -x
			fabric-ca-client enroll -u $CA_server_url --caname $CA_name -M $MSP_dir --csr.hosts $CSR_hosts --tls.certfiles $TLS_certFile
			res=$?
			{ set +x; } 2>/dev/null
      altErrorCheck $res ${FUNCNAME[0]} $LINENO

			cp $peerCONFIG_YAML "${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/msp/config.yaml"
      altErrorCheck $? ${FUNCNAME[0]} $LINENO

  echoOrange "Step 2c: Generate the Peer Node TLS certs"
	# generate Org Peer TLS certs     # note: requires userName and pw variables from peer0
	TLS_dir="${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/tls" 
	generatePeer_TLScerts

	# register other users:

		# user1: register
			userName=user1
			password=user1pw
			ID_type=client
      echoOrange "Step 3a: register other users ($userName)"
			registerUser

		# user1: generate MSP
      echoOrange "Step 3b: generate MSP for other users ($userName)"
			CA_server_url="https://${userName}:${password}@localhost:${Port}"
			MSP_dir="${PWD}/organizations/peerOrganizations/${orgAddress}/users/User1@${orgAddress}/msp" 
			echoBlue "Generating the user msp"
			set -x
			fabric-ca-client enroll -u $CA_server_url --caname ${CA_name} -M $MSP_dir --tls.certfiles $TLS_certFile
			res=$?
			{ set +x; } 2>/dev/null
      altErrorCheck $res ${FUNCNAME[0]} $LINENO

			cp $peerCONFIG_YAML "${PWD}/organizations/peerOrganizations/${orgAddress}/users/User1@${orgAddress}/msp/config.yaml"
      altErrorCheck $? ${FUNCNAME[0]} $LINENO

		# orgAdmin: register
			userName=org1admin
			password=org1adminpw
			ID_type=admin
      echoOrange "Step 3c: register other users ($userName)"
			registerUser
		# orgAdmin: generate MSP
      echoOrange "Step 3d: generate MSP for other users ($userName)"
			CA_server_url="https://${userName}:${password}@localhost:${Port}"
			MSP_dir="${PWD}/organizations/peerOrganizations/${orgAddress}/users/Admin@${orgAddress}/msp" 
			echoBlue "Generating the org admin msp"
			set -x
			fabric-ca-client enroll -u $CA_server_url --caname ${CA_name} -M $MSP_dir --tls.certfiles $TLS_certFile
			res=$?
			{ set +x; } 2>/dev/null
      altErrorCheck $res ${FUNCNAME[0]} $LINENO

			cp $peerCONFIG_YAML "${PWD}/organizations/peerOrganizations/${orgAddress}/users/Admin@${orgAddress}/msp/config.yaml"
      altErrorCheck $? ${FUNCNAME[0]} $LINENO

}
function createOrderer() {
  echoOrange "Beginning to Setup Orderer CA"

	#set variables
	local TLS_certFile=$ordererTLS_certFile
	local Port=$ordererPort
  local CA_name=$ordererCA_name

  echoOrange "Step 1: enroll Org CA admin"
	enrollCA_OrdererAdmin

  echoOrange "Step 2a: Register the Orderer"
	#step 2:
	# orderer: register
	local userName=orderer
	local password=ordererpw
	local ID_type=orderer
	registerUser

  echoOrange "Step 2b: Generate the Orderer Node MSP"
	# orderer: generate MSP
	local CA_server_url="https://${userName}:${password}@localhost:${Port}"
	local MSP_dir="${PWD}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp" 
	#local CSR_hosts="orderer.${orgAddress}" #comma-separated list of CSR hosts  
	local CSR_hosts="orderer.${orgAddress},orderer.${x_org1_address}" #comma-separated list of CSR hosts  
	# other options are available, see: 
	# https://hyperledger-fabric-ca.readthedocs.io/en/release-1.4/clientcli.html#fabric-ca-client-s-cli
	set -x
	fabric-ca-client enroll -u $CA_server_url --caname ${ordererCA_name} -M $MSP_dir --csr.hosts $CSR_hosts --csr.hosts localhost --tls.certfiles $TLS_certFile
	res=$?
	{ set +x; } 2>/dev/null
  altErrorCheck $res ${FUNCNAME[0]} $LINENO

	cp $ordererCONFIG_YAML "${PWD}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp/config.yaml"
  altErrorCheck $? ${FUNCNAME[0]} $LINENO

    echoOrange "Step 2c: Generate the Orderer Node TLS certs"
		# generate orderer Node TLS certs
		TLS_dir="${PWD}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/tls"
		generateOrderer_TLScerts


		#----- register other users: -------#

		# orderer admin: register
		userName=ordererAdmin
		password=ordererAdminpw
		ID_type=admin
    echoOrange "Step 3a: register other users ($userName)"
		registerUser

    echoOrange "Step 3b: generate MSP for other users ($userName)"
		# ordererAdmin: generate MSP
		CA_server_url="https://${userName}:${password}@localhost:${Port}"
    MSP_dir="${PWD}/organizations/ordererOrganizations/${orgAddress}/users/Admin@${orgAddress}/msp/"
		echoBlue "Generating the admin msp"
		set -x
		fabric-ca-client enroll -u $CA_server_url --caname ${ordererCA_name} -M $MSP_dir --tls.certfiles $TLS_certFile
    res=$?
		{ set +x; } 2>/dev/null
    altErrorCheck $res ${FUNCNAME[0]} $LINENO

    cp $ordererCONFIG_YAML "${PWD}/organizations/ordererOrganizations/${orgAddress}/users/Admin@${orgAddress}/msp/config.yaml"
    altErrorCheck $? ${FUNCNAME[0]} $LINENO

    echoOrange "Step 3c: generate TLS certs for user ($userName)"
    TLS_dir="${PWD}/organizations/ordererOrganizations/${orgAddress}/users/Admin@${orgAddress}/tls/"
    set -x
    fabric-ca-client enroll -u $CA_server_url --caname $CA_name -M $TLS_dir --enrollment.profile tls --csr.hosts $CSR_hosts --csr.hosts localhost --tls.certfiles $TLS_certFile
    res=$?
    { set +x; } 2>/dev/null
    altErrorCheck $res ${FUNCNAME[0]} $LINENO

    cp "${TLS_dir}/tlscacerts/"* "${TLS_dir}/ca.crt"
    altErrorCheck $? ${FUNCNAME[0]} $LINENO
    cp "${TLS_dir}/signcerts/"* "${TLS_dir}/server.crt"
    altErrorCheck $? ${FUNCNAME[0]} $LINENO
    cp "${TLS_dir}/keystore/"* "${TLS_dir}/server.key"
    altErrorCheck $? ${FUNCNAME[0]} $LINENO
		}

# errorcheck
function PeerCAerrorCheck(){
	echoBlue "checking for existance of created files from Peer CA setup:"
	TLS_certFile=$peerTLS_certFile
	#bash array of files to check:
	fileList=(
		#CA admin files:
		$TLS_certFile
		$peerCONFIG_YAML
		#TLS cert files:
		"${TLS_dir}/ca.crt"
		"${TLS_dir}/server.crt"
		"${TLS_dir}/server.key"
		"${PWD}/organizations/peerOrganizations/${orgAddress}/msp/tlscacerts/ca.crt"
		"${PWD}/organizations/peerOrganizations/${orgAddress}/tlsca/tlsca.${orgAddress}-cert.pem"
		"${PWD}/organizations/peerOrganizations/${orgAddress}/ca/ca.${orgAddress}-cert.pem"
		#Peer 0:
		"${PWD}/organizations/peerOrganizations/${orgAddress}/peers/peer0.${orgAddress}/msp/config.yaml"
		#user1:
		"${PWD}/organizations/peerOrganizations/${orgAddress}/users/User1@${orgAddress}/msp/config.yaml"
		#org admin:
		"${PWD}/organizations/peerOrganizations/${orgAddress}/users/Admin@${orgAddress}/msp/config.yaml"
	)

	MISSING=0
	for i in ${!fileList[@]} #iterate through array
	do
		if [ ! -f ${fileList[$i]} ] #check for existance of each element
		then 
			echoOrange "${fileList[$i]} not found"
			MISSING=1
		else 
			echo -e "${GREEN}[OK]${NC}: ${fileList[$i]}"
		fi
	done
	if [ $MISSING -eq 1 ]
	then
		echoRed "Some files were not found"
		exit 1
	fi
}
function OrdererCAerrorCheck(){
	echoBlue "checking for existance of created files from Orderer CA setup:"
	TLS_certFile=$TLS_certFile
	#bash array of files to check:
	fileList=(
		#CA admin files:
		$TLS_certFile
		$ordererCONFIG_YAML
		#TLS cert files:
		"${TLS_dir}/ca.crt"
		"${TLS_dir}/server.crt"
		"${TLS_dir}/server.key"
		"${PWD}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp/tlscacerts/tlsca.${orgAddress}-cert.pem"
		"${PWD}/organizations/ordererOrganizations/${orgAddress}/msp/tlscacerts/tlsca.${orgAddress}-cert.pem"
		#orderer:
		"${PWD}/organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp/config.yaml"
		#orderer admin:
		"${PWD}/organizations/ordererOrganizations/${orgAddress}/users/Admin@${orgAddress}/msp/config.yaml"
	)

	MISSING=0
	for i in ${!fileList[@]} #iterate through array
	do
		if [ ! -f ${fileList[$i]} ] #check for existance of each element
		then 
			echoOrange "${fileList[$i]} not found"
			MISSING=1
		else 
			echo -e "${GREEN}[OK]${NC}: ${fileList[$i]}"
		fi
	done
	if [ $MISSING -eq 1 ]
	then
		echoRed "Some files were not found"
		exit 1
	fi
}

