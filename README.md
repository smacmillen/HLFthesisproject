# HLFthesisproject

This project was created for my masters thesis (defended June 25, 2021) as a proof-of-concept blockchain-based system for sharing quality data across a supply chain.
The project is based on Hyperledger Fabric 3x and was designed to run on 4 (VPS) servers, each hosting a single orderer node, peer node, and corresponding CAs.  In my implementation, each of the 4 VPS's were located in a different country.

## Disclaimer: 

My degree is in Industrial Engineering, not software engineering.  My knowledge of HLF, Docker, Javascript, Node.js, Golang, Bash, etc. is mostly self-taught.  As a result, please be aware that the code written and used may not be the most efficient or secure. 


## Project Notes:

### vanillaProject:

This directory contains the HLF-related files that are installed on each server.
Two main files are used for initial setup of the HLF nodes on each server:
- bootstapHost.sh - used to setup Org1 and Org2; used as part of the onboard process for Org3 and Org4); used to install/upgrade chaincode (CC) for all 4 orgs
- outsideOrg.sh - used to install HLF nodes on Org3 and Org4

project variables can be found in "vanillaProject/files/scripts/utils.sh"

### webClient:

This directory contains the web-based client application for interacting with the blockchain network.  This application uses Express and Pug.  It was separately installed and run on each organization server.

### client:

This directory contains the original Node.js client application built to interact with the blockchain network

### QRprinter:

This directory contains a simple Node.js application (relying on an external library) to print QR codes for manufacturing lots.  This application was used in conjunction with the original Node.js client, but is not used in the web client application.

