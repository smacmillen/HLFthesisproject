//
package main

import (
	"scm/chaincode"
	"fmt"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)


func main() {
	supplyChaincode, err := contractapi.NewChaincode(&chaincode.SmartContract{})
	if err != nil {
		fmt.Printf("Error starting supplyChain chaincode: %v", err)
	}

	if err := supplyChaincode.Start(); err != nil {
		fmt.Printf("Error starting supplyChain chaincode: %v", err)
	}
}
