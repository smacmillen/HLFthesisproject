#!/bin/bash
# this file contains the commands necessary to commit chaincode via a docker container as part of the bootstrap.sh sequence

A=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations
B=/etc/hyperledger/fabric

echo "creating soft link between $A and $B:"
set -x
ln -s $A $B
set +x

# Use this section to troubleshoot any variables:

#echo "--------------------------------------------"
#echo "verifying environment variables:"
#echo "orgAddress: $orgAddress"
#echo "orderer_LISTENPORT: $orderer_LISTENPORT"
#echo "SIG_POLICY: $SIG_POLICY"
#echo "x_org1_address: $x_org1_address"
#echo "peer_LISTENPORT: $peer_LISTENPORT"
#echo "x_org1_peerPort: $x_org1_peerPort"
#echo "--------------------------------------------"

echo "Attempting to commit chaincode:"
set -x
peer lifecycle chaincode commit \
	-o orderer.${orgAddress}:${orderer_LISTENPORT} \
	--channelID $ChannelID \
	--tls \
	--cafile organizations/ordererOrganizations/${orgAddress}/orderers/orderer.${orgAddress}/msp/tlscacerts/tlsca.${orgAddress}-cert.pem \
	--name $CHAINCODE_NAME \
	--version $CC_VERSION \
	--sequence $SEQ \
	--signature-policy $SIG_POLICY \
	--collections-config /etc/hyperledger/fabric/config/$COLLECTIONS_NAME \
	--peerAddresses peer0.${org1Address}:${peer_LISTENPORT} \
	--tlsRootCertFiles organizations/peerOrganizations/${org1Address}/msp/tlscacerts/ca.crt \
	--peerAddresses peer0.${org2Address}:${peer_LISTENPORT} \
	--tlsRootCertFiles organizations/peerOrganizations/${org2Address}/msp/tlscacerts/ca.crt \
	--peerAddresses peer0.${org3Address}:${peer_LISTENPORT} \
	--tlsRootCertFiles organizations/peerOrganizations/${org3Address}/msp/tlscacerts/ca.crt \
	--peerAddresses peer0.${org4Address}:${peer_LISTENPORT} \
	--tlsRootCertFiles organizations/peerOrganizations/${org4Address}/msp/tlscacerts/ca.crt
set +x
