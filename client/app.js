// This is a client-facing application for the Hyperledger Fabric Supply Chain Project
// It calls chaincode (written in Go) for this project
//
// Created by Simeon MacMillen (楚昊瑜)
// 2021-2-1


'use strict';

require('dotenv').config(); // required to use .env environment variable file
const { Gateway, Wallets } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const path = require('path');
const { buildCAClient, registerAndEnrollUser, enrollAdmin } = require(`/app/utils/CAUtil.js`);
const { buildCCPOrg1, buildWallet } = require(`/app/utils/AppUtil.js`); 
const prompt = require('prompt-sync')({sigint: true});
//const { BlockDecoder } = require('fabric-common');
//const { exec } = require('child_process');
const fs = require('fs').promises; // used to access files off server
require('colors'); // enable color formatting of strings in terminal
const treeify = require('treeify');
const dateFormat = require("dateformat");
dateFormat.masks.myFormat = 'yyyy.mm.dd'




const channelName = process.env.ChannelID;
const chaincodeName = process.env.CHAINCODE_NAME;
const mspOrg1 = process.env.CORE_PEER_LOCALMSPID;
const walletPath = path.join(__dirname, 'wallet');
const org1UserId = 'appUser';
const Org1UserId = 'appUser1';
let myCollection=''; // global variable to define private data collection
const org1Address=process.env.orgAddress;
const ORG=process.env.ORG;
const org=process.env.org;
const affiliation=''; //this value is used in cert/id generation # previously =`${org}.department1` 
//get collections and convert to js object:
const collections = require(`/app/config/collections_config.json`,'utf8');
let endorsingPeer = '';
let gatewayOrg1;
let contractOrg1;
const QRpath = path.join(__dirname, 'QRcodes');
let availableCollections = []; // global list of collections that this org has access to

async function initContractFromOrg1Identity() {
	console.log(`\n--> Fabric client user & Gateway init: Using ${ORG} identity to ${ORG} Peer`);
	// build an in memory object with the network configuration (also known as a connection profile)
	const ccpOrg1 = buildCCPOrg1();

	// build an instance of the fabric ca services client based on
	// the information in the network configuration
	const caOrg1Client = buildCAClient(FabricCAServices, ccpOrg1, `ca.${org1Address}`);

	// setup the wallet to cache the credentials of the application user, on the app server locally
	const walletPathOrg1 = path.join(__dirname, `wallet/${org}`);
	const walletOrg1 = await buildWallet(Wallets, walletPathOrg1);

	await enrollAdmin(caOrg1Client, walletOrg1, mspOrg1);
	await registerAndEnrollUser(caOrg1Client, walletOrg1, mspOrg1, Org1UserId, affiliation);

	try {
		// Create a new gateway for connecting to Org's peer node.
		const gatewayOrg1 = new Gateway();
		//connect using Discovery enabled
		await gatewayOrg1.connect(ccpOrg1,
			{ wallet: walletOrg1, identity: Org1UserId, discovery: { enabled: true, asLocalhost: false } });

		return gatewayOrg1;
	} catch (err) {
		console.error('Error in connecting to gateway: '+err);
		process.exit(1);
	}
}
async function setup() {
	// build an in memory object with the network configuration (also known as a connection profile)
	const ccp = buildCCPOrg1();

	// build an instance of the fabric ca services client based on
	// the information in the network configuration
	const caClient = buildCAClient(FabricCAServices, ccp, `ca.${org1Address}`);

	// setup the wallet to hold the credentials of the application user
	const wallet = await buildWallet(Wallets, walletPath);

	// in a real application this would be done on an administrative flow, and only once
	await enrollAdmin(caClient, wallet, mspOrg1);

	// in a real application this would be done only when a new user was required to be added
	// and would be part of an administrative flow
	await registerAndEnrollUser(caClient, wallet, mspOrg1, org1UserId, affiliation);
}
async function gateway() {
	// Create a new gateway instance for interacting with the fabric network.
	// In a real application this would be done as the backend server session is setup for
	// a user that has been verified.
	try {
		gatewayOrg1 = await initContractFromOrg1Identity();
		const networkOrg1 = await gatewayOrg1.getNetwork(channelName);
		contractOrg1 = networkOrg1.getContract(chaincodeName);
		//const systemContract = networkOrg1.getContract('qscc');
		contractOrg1.addDiscoveryInterest({ name: chaincodeName, collectionNames: [myCollection] });
		//NOTE: this assumes that each org only has 1 endorsing peer! In practice, this should not be the case
		endorsingPeer = networkOrg1.getChannel().getEndorsers(mspOrg1)[0];
		//endorsingPeer = networkOrg1.getChannel().getEndorser(`peer0.${org1Address}:7051`); //same as above
		//NOTE2: consider expanding this to use the getEndorsers(mspOrg1) which would give an array of all endorsing peers in this org - then pick (randomly?) from these for each session
		//console.log("Endorsing peer set to: " + endorsingPeer)
	} catch (err) {
		failureCallback(err);
	}
	console.clear() //TODO: remove all the text printed to the screen by this function
}
async function addDesignPart(PN, NAME, PPN, NUMDIMS, DIMS, CONTRACT, COLLECTION) {
	let newPart = { partID: PN, partName: NAME, parentPart: PPN, numOfDims: NUMDIMS, dimensions: DIMS, collection: COLLECTION};

	console.log('Adding Assets to work with:\n--> Submit Transaction: AddPart ' + PN);
	//let statefulTxn = CONTRACT.createTransaction('AddPart').setEndorsingPeers([endorsingPeer]);
	let statefulTxn = CONTRACT.createTransaction('AddPart');
	// generate transient:
	let tmapData = Buffer.from(JSON.stringify(newPart));
	statefulTxn.setTransient({
		asset_properties: tmapData
	});
	let result;
	try {
		result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting transaction...")
				result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}


	console.log(`*** New part committed. *** ${result.toString()}`.green); // no return values provided
}



async function queryDesignPart(PN, CONTRACT, COLLECTION) {
	console.log(`Querying Design Part ${PN} in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('ReadPartPrivateDetails', COLLECTION, PN);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('ReadPartPrivateDetails', COLLECTION, PN);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	console.log('*** result: ***'.cyan); //normal JSON
	console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	return;
}
async function addOrder(ON, PN, DueDate, QTY, SUPPLIER, CONTRACT, COLLECTION) {
	let newOrder = { orderID: ON, partID: PN, dueDate: DueDate, quantity: QTY, supplier: SUPPLIER, collection: COLLECTION};
	console.log(`Adding Order ${ON} for Part ${PN}`);
	let statefulTxn = CONTRACT.createTransaction('AddOrder');
	// generate transient:
	let tmapData = Buffer.from(JSON.stringify(newOrder));
	statefulTxn.setTransient({
		asset_properties: tmapData
	});

	let result;
	try {
		result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting transaction...")
				result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}


	console.log(`*** Order committed. ${result.toString()}`.green); // no return values provided
}

async function orderDecision(ON, CONTRACT, COLLECTION) {
	let decision = prompt('Do you wish to accept this order? '.cyan)
	while (decision != 'yes' && decision != 'no') {
		decision =prompt('Please enter either "yes" or "no": '.bgRed);
	}
	let orderDecision;
	if (decision == 'yes') {
		orderDecision='accept';
	} else if (decision == 'no'){
		orderDecision='reject';
	}
	decision = prompt('Do you wish to add any comments? '.cyan)
	while (decision != 'yes' && decision != 'no') {
		decision =prompt('Please enter either "yes" or "no": '.bgRed);
	}
	let comments;
	if (decision == 'yes') {
		comments = prompt('Enter comments:')
	}
	// confirm provided information before submitting
	console.log('Here is a summary of what you entered:'.yellow);
	console.log('  Order ID: ' + ON);
	console.log('  Decision: ' + orderDecision);
	if (typeof comments == 'undefined') {
		console.log('  Comments: none');
	} else {
		console.log('  Comments: ' + comments);
	}

	let confirmOK=prompt('Is this information correct? '.yellow);
	while (confirmOK != 'yes' && confirmOK != 'no') {
		confirmOK=prompt('Please enter either "yes" or "no": '.bgRed);
	}
	if (confirmOK == 'no') {
		console.log('Cancelling decision - please re-run function with correct input'.red);
		return;
	} else {
		console.log('Confirmation received.  Proceeding to submit decision.')
	}
	let transient = { orderID: ON, decision: orderDecision, comments: comments, collection: COLLECTION};
	if (orderDecision=='accept') {
		console.log(`Accepting Order ${ON}`);
	} else {
		console.log(`Rejecting Order ${ON}`);
	}
	let statefulTxn = CONTRACT.createTransaction('AcceptRejectOrder');
	// generate transient:
	let tmapData = Buffer.from(JSON.stringify(transient));
	statefulTxn.setTransient({
		asset_properties: tmapData
	});
	let result;
	try {
		result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting transaction...")
				result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else if (err.toString().includes("does not match Supplier MSPID")) {
			console.log("You are trying to update an order that is not assigned to you.".red);
			return;
		} else {
		console.log('Error detected:\n'.red+ err)
		return;
		}
	}
	console.log(`*** Order committed. ${result.toString()}`.green); // no return values provided
}

async function queryOrder(OrderNum, CONTRACT, COLLECTION) {
	console.log(`Querying Order ${OrderNum} in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('ReadOrderPrivateDetails', COLLECTION, OrderNum);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('ReadOrderPrivateDetails', COLLECTION, OrderNum);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	console.log('*** result: ***'.cyan); //normal JSON
	console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	return;
}
async function queryLot(LotNum, CONTRACT, COLLECTION) {
	console.log(`Querying lot ${LotNum} in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('ReadPartRecord', COLLECTION, LotNum);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('ReadPartRecord', COLLECTION, LotNum);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	console.log('*** result: ***'.cyan); //normal JSON
	console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
}
async function queryWhereUsedPrivate(LotNum, CONTRACT, COLLECTION) {
	console.log(`Querying lot ${LotNum} in collection`.green);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('LotTracePrivate', COLLECTION,LotNum);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('LotTracePrivate', COLLECTION,LotNum);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}

	console.log('*** result: ***'.cyan); //normal JSON
	console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	return
}
async function queryWhereUsedPublic(LotNum, CONTRACT) {
	console.log(`Querying lot ${LotNum} in ledger`.green);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('LotTraceChannel',LotNum);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('LotTraceChannel',LotNum);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}


	console.log('*** result: ***'.cyan); //normal JSON
	console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	return
}
async function buildReverseGenealogyPublic(LotNum, CONTRACT) {
	process.stdout.write(`Checking to see if ${LotNum} is a valid Lot Number...`) // no newline char
	let lot;
	try {
		lot = await CONTRACT.evaluateTransaction('CheckForAsset', LotNum);
		if (lot.toString()=="none") {
			console.log(`\nLot number ${LotNum} does not exist on Channel ledger.`.red)
			return;
		} else if (lot.toString()!="lot record") {
			console.log(`\nProvided ID ${LotNum} is type "${lot.toString()}", not type "lot record".`.red)
			return;
		}
	} catch(err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				process.stdout.write(`Checking to see if ${LotNum} is a valid Lot Number...`) // no newline char
				lot = await CONTRACT.evaluateTransaction('CheckForAsset', LotNum);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	console.log("ok")


	console.log(`Generating Complete Tracking for usage of lot ${LotNum}`.green);

	let tree = await buildTreePublic(LotNum,LotNum,{}, CONTRACT);

	//console.log(JSON.stringify(tree, null, 4)); //prints with indentation
	console.log(treeify.asTree(tree,true)); //prints with indentation
	return
}
async function buildTreePublic(ID, path, tree, CONTRACT) {
	let PartswhereUsed;
	try {
		PartswhereUsed = await CONTRACT.evaluateTransaction('LotTraceChannel', ID);
	} catch (err) {
		//Note: gRPC error handling not required since this function is called from parent after checking connection
		console.log("Error detected: "+err)
	}
	PartswhereUsed=JSON.parse(PartswhereUsed);
	if (PartswhereUsed.length===0) {
		put(tree,path,{})
	} else {
		for (const child of PartswhereUsed) {
			await buildTreePublic(child,`${path}.${child}`, tree, CONTRACT)
		}
	}
	return tree;
}
async function buildPartGenealogy(PartID, CONTRACT) {
	process.stdout.write(`Checking to see if ${PartID} is a valid Part Number...`) // no newline char
	let part;
	try {
		part = await CONTRACT.evaluateTransaction('CheckForAsset', PartID);
		if (part.toString()=="none") {
			console.log(`\nLot number ${PartID} does not exist on Channel ledger.`.red)
			return;
		} else if (part.toString()!="part") {
			console.log(`\nProvided ID ${PartID} is type "${part.toString()}", not type "part".`.red)
			return;
		}
	} catch(err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				process.stdout.write(`Checking to see if ${PartID} is a valid Part Number...`) // no newline char
				part = await CONTRACT.evaluateTransaction('CheckForAsset', PartID);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	console.log("ok")


	console.log(`Generating Part Family Tree for Part ID ${PartID}`.green);

	let tree;
	try {
		tree = await buildPartTree(PartID,PartID,{}, CONTRACT);
	} catch (err) {
		console.log("Error detected: ".red + err)
		return;
	}

	//console.log(JSON.stringify(tree, null, 4)); //prints with indentation
	console.log(treeify.asTree(tree,true)); //prints with indentation
	return;
}
async function buildPartTree(ID, path, tree, CONTRACT) {
	let part;
	try {
		part = await CONTRACT.evaluateTransaction('ReadAsset', ID);
	} catch (err) {
		//Note: gRPC error handling not required since this function is called from parent after checking connection
		console.log("Error detected: "+err)
	}
	let children = JSON.parse(part).childAssets
	if (typeof(children) == 'undefined') {
		put(tree,path,{})
	} else {
		for (const child of children) {
			await buildPartTree(child,`${path}.${child}`, tree, CONTRACT)
		}
	}
	return tree;
}

async function inspectParts(LN, PN, DimID, MEAS, CONTRACT, COLLECTION) {
	// submit transaction
	let newDimData = { partID: PN, lotID: LN, DimensionID: DimID, measurements: MEAS, collection: COLLECTION};
	console.log(`Preparing to record inspection data for Part ${PN}, Dimension ${DimID}`);
	let statefulTxn = CONTRACT.createTransaction('InspectPart');
	// generate transient:
	let tmapData = Buffer.from(JSON.stringify(newDimData));
	statefulTxn.setTransient({
		asset_properties: tmapData
	});
	let result;
	try {
		result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting transaction...")
				result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}

	//check if result is passed or failed and colorize accordingly
	if (result.toString() == "Passed inspection") {
		console.log(`*** Inspection recorded. ***\nResult: ${result.toString()}`.green);
	} else {
		console.log(`*** Inspection recorded ***\n`.yellow,`Result: ${result.toString()}`.Red);
	}

	//console.log(`*** Inspection recorded. ${result.toString()}`.green); // return value IS now provided
}
async function ship(LN, DEST, CONTRACT, COLLECTION) {
	// submit transaction
	let shipInfo= { lotID: LN, destinationOrg: DEST, collection: COLLECTION};
	console.log(`Preparing to record shipping information for Lot ${LN}`);
	let statefulTxn = CONTRACT.createTransaction('ShipParts');
	// generate transient:
	let tmapData = Buffer.from(JSON.stringify(shipInfo));
	statefulTxn.setTransient({
		asset_properties: tmapData
	});
	let result;
	try {
		result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting transaction...")
				result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}


	console.log(`*** Shipment Information recorded. ${result.toString()}`.green); // no return values provided
}
async function receive(LN, QTY, CONTRACT, COLLECTION) {
	// submit transaction
	let receiveInfo= { lotID: LN, quantity: QTY, collection: COLLECTION};
	console.log(`Preparing to receive shipment of ${QTY} parts from Lot ${LN}`);
	let statefulTxn = CONTRACT.createTransaction('ReceiveParts');
	// generate transient:
	let tmapData = Buffer.from(JSON.stringify(receiveInfo));
	statefulTxn.setTransient({
		asset_properties: tmapData
	});

	let result;
	try {
		result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
		} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting transaction...")
				result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}


	console.log(`*** Shipment Successfully Received. ${result.toString()}`.green); // no return values provided
}



// user facing functions:
async function UIaddPart(CONTRACT, COLLECTION) {
	console.log('Please enter the required information:'.cyan)
	let PN = prompt('Part Number: ');
	while (PN == "") {
		PN=prompt('Please enter Part Number: '.bgRed);
	}
	let NAME=prompt('Part Name: ');
	while (NAME == "") {
		NAME=prompt('Please enter Part Name: '.bgRed);
	}
	let PPN=prompt('Parent Part Number (leave blank for none): ');
	let NumDims=Number(prompt('Number of Dimensions: '));
	while (! Number.isInteger(NumDims) || (Number(NumDims) <1)) { //error check for positive integer
		NumDims=Number(prompt('Please enter a positive integer: '.bgRed));
	}
	// get dimensional info
	let dimPreview=[];
	let DIMS = [];
	for (let i=1; i<=NumDims; i++) {
		console.log(`Please enter the following information for Dimension ${i}:`.cyan);
		DIMS.push(i);
		let UCL=await getPositiveNumber('UCL');
		DIMS.push(Number(UCL));
		let LCL=await getPositiveNumber('LCL');
		while (Number(LCL)>Number(UCL)) {
			console.log('ERROR: LCL cannot be greater than UCL. Please enter correct value for LCL.'.red)
			LCL=await getPositiveNumber('LCL');
		}
		DIMS.push(Number(LCL));
		let Target=await getPositiveNumber('Target');
		while (Number(Target) < Number(LCL) || Number(Target) > Number(UCL)) {
			if (Number(Target) < Number(LCL)) {
				console.log(`You entered ${Target}.  This is < LCL value of ${LCL}`)
				console.log('ERROR: Target cannot be less than LCL. Please enter correct value for Target.'.red)
				Target=await getPositiveNumber('Target');
			} else if (Number(Target) > Number(UCL)) {
				console.log(`You entered ${Target}.  This is > UCL value of ${UCL}`)
				console.log('ERROR: Target cannot be greater than UCL. Please enter correct value for Target.'.red)
				Target=await getPositiveNumber('Target');
			}
		}
		DIMS.push(Number(Target));
		let CPK=await getPositiveNumber('CPK');
		DIMS.push(Number(CPK));
		dimPreview[i-1]={'dimID':i,'ucl':Number(UCL),'lcl':Number(LCL),'target':Number(Target),'cpk':Number(CPK)};
	}

	// confirm provided information before submitting
	console.log('Here is a summary of what you entered:'.yellow);
	console.log('  Part ID: ' + PN);
	console.log('  Part Name: ' + NAME);
	console.log('  Part NumDims: ' + NumDims);
	console.log('  Part Parent ID: ' + PPN);
	console.log('  Dimensions: ');
	console.dir(dimPreview);
	console.log('  Collection: ' + COLLECTION);

	let confirmOK=prompt('Is this information correct? '.yellow);
	while (confirmOK != 'yes' && confirmOK != 'no') {
		confirmOK=prompt('Please enter either "yes" or "no": '.bgRed);
	}
	if (confirmOK == 'no') {
		console.log('Cancelling part input'.red);
		return;
	} else {
		console.log('Confirmation received.  Proceeding to submit data.')
	}


	try {
		await addDesignPart(PN, NAME, PPN, NumDims, DIMS, CONTRACT, COLLECTION)
	} catch (err) {
		console.log('Error detected:\n'.red + err)
		return; //stop function here on error (avoid query)
	}
	try {
		await queryDesignPart(PN, CONTRACT, COLLECTION)
	} catch (err) {
		console.log('Error detected:\n'.red + err)
	}
}
async function UIaddOrder(CONTRACT, COLLECTION) {
	console.log('Please enter the required information:'.cyan)
	let Order = prompt('Order Number: ');
	while (Order == "") {
		Order=prompt('Please enter Order Number: '.bgRed);
	}
	let PN = prompt('Part Number: ');
	while (PN == "") {
		PN=prompt('Please enter Part Number: '.bgRed);
	}
	let DueDate = dateFormat(prompt('Due Date: '),"myFormat");
	let QTY = Number(prompt('Quantity: '));
	while (! Number.isInteger(QTY) || (Number(QTY) <1)) { //error check for positive integer
		QTY=Number(prompt('Please enter a positive integer: '.bgRed));
	}
	let SUPPLIER = prompt('Supplier: ')
	while (SUPPLIER == "" || SUPPLIER.length < 3) {
		SUPPLIER=prompt('Please enter a valid Supplier Code: '.bgRed);
	}

	// TEST if supplier is member of current collection
	process.stdout.write(`Checking to see if supplier is a member of the current collection...`) // no newline char
	const isMember = checkMembership(SUPPLIER,COLLECTION)
	if (!isMember) {
		console.log(`\nError: Supplier ${SUPPLIER} is not a member of the current collection ( ${COLLECTION} )`.red)
		return;
	}
	console.log("ok")

	// confirm provided information before submitting
	console.log('Here is a summary of what you entered:'.yellow);
	console.log('  Order ID: ' + Order);
	console.log('  Part ID: ' + PN);
	console.log('  Part DueDate: ' + DueDate);
	console.log('  Part Quantity: ' + QTY);
	console.log('  Supplier: ' + SUPPLIER);

	let confirmOK=prompt('Is this information correct? '.yellow);
	while (confirmOK != 'yes' && confirmOK != 'no') {
		confirmOK=prompt('Please enter either "yes" or "no": '.bgRed);
	}
	if (confirmOK == 'no') {
		console.log('Cancelling order input'.red);
		return;
	} else {
		console.log('Confirmation received.  Proceeding to submit data.')
	}

	try {  
		await addOrder(Order, PN, DueDate, QTY, SUPPLIER, CONTRACT, COLLECTION)
	} catch (err) {
		console.log('Error detected:\n'.red + err)
		return; //stop function here on error (avoid query)
	}
	try {
		await queryOrder(Order, CONTRACT, COLLECTION)
	} catch (err) {
		console.log('Error detected:\n'.red + err)
	}
}
async function UIreviewOrders(CONTRACT, COLLECTION) {
	console.log(`Checking for any orders waiting for ${ORG}\'s approval...`)
	let result;
	// get all new orders waiting for this org's approval:
	try {
		result = await CONTRACT.evaluateTransaction('QueryPrivateAssets',COLLECTION,`{\"selector\":{\"docType\":\"order\",\"supplier\":\"${ORG}\",\"status\":\"new order\"}}`);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryPrivateAssets',COLLECTION,`{\"selector\":{\"docType\":\"order\",\"supplier\":\"${ORG}\",\"status\":\"new order\"}}`);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}

	}
	result = JSON.parse(result);

	let orderQueue = [];
	if (result.length===0) {
		console.log(`There are no orders in collection ${COLLECTION} waiting for your review.`.green)
		return;
	} else {
		// get all order ID's waiting approval
		console.log('The following orders are waiting for your decision:'.yellow);
		for (const entry of result) {
			orderQueue.push(entry.orderID);
			process.stdout.write(entry.orderID) // no newline char
			if (entry != result[result.length-1]) {
				process.stdout.write(", ") // no newline char
			} else {
				console.log('')
			}
		}

		let ON = prompt('Please enter any order ID you wish to disposition: '.cyan)
		if (orderQueue.includes(ON)) {

			// query order to show details:
			try {
				await queryOrder(ON, CONTRACT, COLLECTION)
			} catch (err) {
				console.log('Error detected:\n'.red+ err)
			}

			//process order decision:
			try {
				await orderDecision(ON, CONTRACT, COLLECTION)
			} catch (err) {
				console.log('Error detected:\n'.red+ err)
				return;
			}
		} else {
			console.log('Returning to main menu')
			return;
		}
	}
}
async function UImakeparts(CONTRACT, COLLECTION) {
	//get values
	console.log('Please enter the required information:'.cyan)
	let PN = prompt('Part Number: ');
	while (PN == "") {
		PN=prompt('Please enter Part Number: '.bgRed);
	}
	let ON = prompt('Order Number: ');
	while (ON == "") {
		ON=prompt('Please enter Order Number: '.bgRed);
	}
	let QTY = Number(prompt('Quantity: '));
	while (! Number.isInteger(QTY) || (Number(QTY) <1)) { //error check for positive integer
		QTY=Number(prompt('Please enter a positive integer: '.bgRed));
	}
	console.log('Please enter the quantity of component lots used in this part.  If none, enter \'0\''.cyan)
	let ComponentQty = await getPositiveNumber('Quantity of component lots')
	let ChildLots=[];
	if (ComponentQty > 0) {
		for (let i=1; i<=ComponentQty; i++) {
			let ENTRY=prompt(`Please enter lot number ${i}:`);
			ChildLots.push(ENTRY);
			while (ENTRY == "") {
				ENTRY=prompt(`Please enter lot number ${i}:`.bgRed);
			}
		}
	}

	// validation: check if Part required child components are each satisfied by provided component lots
	//console.log('Checking to see if all required child components are provided...')
	// call ValidateComponents(CONTRACT,PN,ChildLots)

	// confirm provided information before submitting
	console.log('Here is a summary of what you entered:'.yellow);
	console.log('  Part ID: ' + PN);
	console.log('  Order ID: ' + ON);
	console.log('  Lot Quantity: ' + QTY);
	if (ChildLots.length === 0 ) {
		console.log('  ChildLots: none');
	} else {
		console.log('  ChildLots: ' + ChildLots);
	}

	let confirmOK=prompt('Is this information correct? '.yellow);
	while (confirmOK != 'yes' && confirmOK != 'no') {
		confirmOK=prompt('Please enter either "yes" or "no": '.bgRed);
	}
	if (confirmOK == 'no') {
		console.log('Cancelling lot input'.red);
		return;
	} else {
		console.log('Confirmation received.  Proceeding to submit data.')
	}

	// submit transaction
	let newLot = { partID: PN, orderID: ON, quantity: QTY, subcomponents: ChildLots, collection: COLLECTION};
	console.log(`Creating new lot of Part ${PN} for Order ${ON}...`);
	let statefulTxn = CONTRACT.createTransaction('MakePart');
	// generate transient:
	let tmapData = Buffer.from(JSON.stringify(newLot));
	statefulTxn.setTransient({
		asset_properties: tmapData
	});
	
	let result;
	try {
		result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting transaction...")
				result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}

	console.log(`*** New Lot committed. ${result.toString()}`.green); // lot number returned


	// save Lot ID to generate QR code
	const newLotID=result.toString();
	const filePath=path.join(QRpath,newLotID);
	await fs.writeFile(filePath, '');
	console.log('LotID is recorded successfully.');
}
async function UIqueryPart(CONTRACT, COLLECTION) {
	console.log('Please enter the part you wish to query:'.cyan)
	let PN = prompt('Part Number: ');
	while (PN == "") {
		PN=prompt('Please enter Part Number: '.bgRed);
	}
	try {
		await queryDesignPart(PN, CONTRACT, COLLECTION)
	} catch (err) {
		if (err.toString().includes("Unexpected end of JSON input")) {
			console.log(`Part ${PN} does not exist in collection ${COLLECTION}.`.red)
			console.log("Checking to see if it exists in any other collection...")
			//first check if part exists in channel and is correct type
			try {
				let assetType = await CONTRACT.evaluateTransaction('CheckForAsset',PN)
				if (assetType == "none" || assetType != "part") {
					console.log(`Part ${PN} does not exist in any collection.`.red)
					return;
				} else {  // get collection name
					try {
						let OtherColl = await getAssetCollection(PN, CONTRACT);
						console.log(`Part ${PN} exists in other collection ${OtherColl}.`.green)
					} catch (err) {
						console.log('Error detected:\n'.red+ err)
					}
				}
			} catch (err) {
				//Note: gRPC error handling not required here since child function handles error and is called first
				console.log('Error detected:\n'.red+ err)
			}
		} else {
			console.log('Error detected:\n'.red+ err)
		}
	}
}
async function UIqueryOrder(CONTRACT, COLLECTION) {
	console.log('Please enter the order you wish to query:'.cyan)
	let ON = prompt('Order Number: ');
	while (ON == "") {
		ON=prompt('Please enter Order Number: '.bgRed);
	}
	try {
		await queryOrder(ON, CONTRACT, COLLECTION)
	} catch (err) {
		//Note: gRPC error handling not required here since child function (queryOrder) handles error
		if (err.toString().includes("Unexpected end of JSON input")) {
			console.log(`Order ${ON} does not exist in collection ${COLLECTION}.`.red)
			console.log("Checking to see if it exists in any other collection...")
			//first check if order exists in channel and is correct type
			try {
				let assetType = await CONTRACT.evaluateTransaction('CheckForAsset',ON)
				if (assetType == "none" || assetType != "order") {
					console.log(`Order ${ON} does not exist in any collection.`.red)
					return;
				} else {  // get collection name
					try {
						let OtherColl = await getAssetCollection(ON, CONTRACT);
						console.log(`Order ${ON} exists in other collection ${OtherColl}.`.green)
					} catch (err) {
						console.log('Error detected:\n'.red+ err)
					}
				}
			} catch (err) {
				console.log('Error detected:\n'.red+ err)
			}
		} else {
			console.log('Error detected:\n'.red+ err)
		}
	}
}
async function UIqueryLotRecord(CONTRACT, COLLECTION) {
	console.log('Please enter the Lot Number you wish to query:'.cyan)
	let LN = prompt('Lot Number: ');
	while (LN == "") {
		LN=prompt('Please enter Manufacturing Lot Number: '.bgRed);
	}
	try {
		await queryLot(LN, CONTRACT, COLLECTION)
	} catch (err) {
		//Note: gRPC error handling not required here since child function (queryLot) handles error
		if (err.toString().includes("Unexpected end of JSON input")) {
			console.log(`Lot ID ${LN} does not exist in collection ${COLLECTION}.`.red)
			console.log("Checking to see if it exists in any other collection...")
			//first check if lot number exists in channel and is correct type
			try {
				let assetType = await CONTRACT.evaluateTransaction('CheckForAsset',LN)
				if (assetType == "none" || assetType != "lot record") {
					console.log(`Lot ID ${LN} does not exist in any collection.`.red)
					return;
				} else {  // get collection name
					try {
						let OtherColl = await getAssetCollection(LN, CONTRACT);
						console.log(`Lot ID ${LN} exists in other collection ${OtherColl}.`.green)
					} catch (err) {
						console.log('Error detected:\n'.red+ err)
					}
				}
			} catch (err) {
				console.log('Error detected:\n'.red+ err)
			}
		} else {
			console.log('Error detected:\n'.red+ err)
		}
	}
}
async function UIinspectParts(CONTRACT, COLLECTION) {
	//get values
	console.log('Please enter the required information:'.cyan)
	let LN = prompt('Lot Number: ');
	while (LN == "") {
		LN=prompt('Please enter Manufacturing Lot Number: '.bgRed);
	}
	let PN = prompt('Part Number: ');
	while (PN == "") {
		PN=prompt('Please enter Part Number: '.bgRed);
	}
	let DimID = Number(prompt('Dimension Number: '));
	while (! Number.isInteger(DimID) || (DimID <1)) { //error check for positive integer
		DimID=Number(prompt('Please enter a valid dimension number (positive integer): '.bgRed));
	}

	// get measurement data
	console.log('Please type each measurement followed by the enter key.  To finish, type \'f\'.'.cyan);
	let nextValue;
	let MEAS=[];
	while (nextValue == nextValue){
		//nextValue = prompt('Measurement: ');
		nextValue = await getPositiveNumber('Measurement','f');  // error-check for non-positive number values
		if (nextValue == 'f') {
			break;
		} else {
			MEAS.push(Number(nextValue));
		}
	}
	if (MEAS.length == 0) {
		console.log('No data recorded.  Stopping function.'.red)
		return;
	}

	// confirm provided information before submitting
	console.log('Here is a summary of what you entered:'.yellow);
	console.log('  Lot Number: ' + LN);
	console.log('  Part ID: ' + PN);
	console.log('  Dimension ID: ' + DimID);
	console.log('  Measurements: ' + MEAS);

	let confirmOK=prompt('Is this information correct? '.yellow);
	while (confirmOK != 'yes' && confirmOK != 'no') {
		confirmOK=prompt('Please enter either "yes" or "no": '.bgRed);
	}
	if (confirmOK == 'no') {
		console.log('Cancelling inspection'.red);
		return;
	} else {
		console.log('Confirmation received.  Proceeding to submit data.')
	}
	//submit data
	try {  
		await inspectParts(LN, PN, DimID, MEAS, CONTRACT, COLLECTION)
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}
async function UIship(CONTRACT, COLLECTION) {
	console.log('Please enter the required information:'.cyan)
	let LN = prompt('Lot Number: ');
	while (LN == "") {
		LN=prompt('Please enter Manufacturing Lot Number: '.bgRed);
	}
	let DEST = prompt('Destination Organization: ');
	while (DEST == "") {
		DEST=prompt('Please enter Destination Organization: '.bgRed);
	}
	try {
		await ship(LN, DEST, CONTRACT, COLLECTION)
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}
async function UIreceive(CONTRACT, COLLECTION) {
	console.log('Please enter the required information:'.cyan)
	let LN = prompt('Lot Number: ');
	while (LN == "") {
		LN=prompt('Please enter Manufacturing Lot Number: '.bgRed);
	}
	let QTY = Number(prompt('Quantity of parts to receive: '));
	while (! Number.isInteger(QTY) || (QTY <1)) { //error check for positive integer
		QTY=Number(prompt('Please enter a valid quantity (positive integer): '.bgRed));
	}
	// TODO: check if lot exists in collection
	
	// if so, proceed
	try {
		await receive(LN, QTY, CONTRACT, COLLECTION)
	} catch (err) {
		console.log('Error detected:\n'.red + err)
	}
}
async function UIqueryLotWhereUsedPrivate(CONTRACT, COLLECTION) {
	console.log(`Please note that this function will only search for results in the current collection (${COLLECTION})`.yellow)
	console.log('Please enter the Lot Number you wish to query:'.cyan)
	let LN = prompt('Lot Number: ');
	while (LN == "") {
		LN=prompt('Please enter Manufacturing Lot Number: '.bgRed);
	}
	try {
		await queryWhereUsedPrivate(LN, CONTRACT, COLLECTION)
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}
async function UIqueryLotWhereUsedPublic(CONTRACT) {
	console.log('Please enter the Lot Number you wish to query:'.cyan)
	let LN = prompt('Lot Number: ');
	while (LN == "") {
		LN=prompt('Please enter Manufacturing Lot Number: '.bgRed);
	}
	try {
		await queryWhereUsedPublic(LN, CONTRACT)
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}
async function UIgetLotGenealogyChannel(CONTRACT) {
	console.log('Please enter the Lot Number you wish to query:'.cyan)
	let LN = prompt('Lot Number: ');
	while (LN == "") {
		LN=prompt('Please enter Manufacturing Lot Number: '.bgRed);
	}
	try {
		await buildReverseGenealogyPublic(LN, CONTRACT)
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}
async function UIbuildPartFamilyTree(CONTRACT) {
	console.log('Please enter the Part Number for which you wish to query a family tree:'.cyan)
	let PN = prompt('Part Number: ');
	while (PN == "") {
		PN=prompt('Please enter Part Number: '.bgRed);
	}
	try {
		await buildPartGenealogy(PN, CONTRACT)
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}
async function UIgetRecordPublicHistory(CONTRACT) {
	console.log('Please enter the ID you wish to query:'.cyan)
	let LN = prompt('Record ID Number: ');
	while (LN == "") {
		LN=prompt('Please enter an ID Number: '.bgRed);
	}
	try {
		await getRecordPublicHistory(LN, CONTRACT)
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}
async function getRecordPublicHistory(RecordID, CONTRACT) {
	console.log(`Querying Public History for Record ${RecordID} in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('GetPublicHistory', RecordID);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('GetPublicHistory', RecordID);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}

	console.log('*** result: ***'.cyan); //normal JSON
	console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
}
async function UIdeleteAsset(CONTRACT, COLLECTION) {
	console.log('Please enter the ID of the asset you wish to delete:'.cyan)
	let ID = prompt('Asset ID: ');
	while (ID == "") {
		ID=prompt('Please enter Asset ID: '.bgRed);
	}

	// confirm provided information before submitting
	console.log('You entered the following asset:'.yellow);
	console.log('  Asset ID: ' + ID);

	let confirmOK=prompt('Is this correct? '.yellow);
	while (confirmOK != 'yes' && confirmOK != 'no') {
		confirmOK=prompt('Please enter either "yes" or "no": '.bgRed);
	}
	if (confirmOK == 'no') {
		console.log('Cancelling deletion'.red);
		return;
	}
	// Confirm twice to avoid accidental deletion
	console.log(`WARNING: You are about to delete asset ${ID}!`.bgRed);

	confirmOK=prompt('Please confirm by entering \'yes\' or cancel by entering \'no\''.yellow);
	while (confirmOK != 'yes' && confirmOK != 'no') {
		confirmOK=prompt('Please enter either "yes" or "no": '.bgRed);
	}
	if (confirmOK == 'no') {
		console.log('Cancelling deletion'.red);
		return;
	} else {
		console.log('Confirmation received.  Proceeding to submit deletion request.')
	}

	let dataForDelete = { assetID: ID};
	let statefulTxn = CONTRACT.createTransaction('DeleteAsset');
	let tmapData = Buffer.from(JSON.stringify(dataForDelete));
	statefulTxn.setTransient({
		asset_delete: tmapData
	});

	try {
		await statefulTxn.setEndorsingPeers([endorsingPeer]).submit(COLLECTION);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting transaction...")
				await statefulTxn.setEndorsingPeers([endorsingPeer]).submit(COLLECTION);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return; //stop function here on error (avoid query)
		}
	}

	console.log("Now checking to see if deleted asset can be queried on the ledger:")
	let asset;
	try {
		asset = await CONTRACT.evaluateTransaction('CheckForAsset', ID);
	} catch(err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying query.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				asset = await CONTRACT.evaluateTransaction('CheckForAsset', ID);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	if (asset.toString()=="none") {
		console.log(`Success: Asset ${ID} no longer exists on the Channel ledger.`.green)
	} else {
		throw `Asset ${ID} exists on Channel ledger.`
	}
return;
}


/*
async function lookupTX(TX, CONTRACT) {
	// get block by TX ID
	console.log(`Querying TX ID ${TX} in ledger`);
	let result = await CONTRACT.evaluateTransaction('GetTransactionByID', channelName, TX);
//console.log(`*** result: ***\n${result}`);

// extract data and convert to JSON
	result = BlockDecoder.decodeTransaction(result); //works, but payload needs to be unpacked
	console.log(`*** BD result: ***\n${result}`); // output: [object Object]
//console.log(`*** BD JSON result: ***\n${JSON.stringify(result)}`); //no formatting, but fits on screen

//let obj = JSON.parse(result, function(key, value) {
//	if (key == "args") {
//		return value;
//	} else {
//		return value;
//	}
//});

//extract value from object:
	result = result.transactionEnvelope.payload.data.actions[0].header.creator.id_bytes
	console.log('id_bytes:' + result)

//console.log('Stringified version:' + JSON.stringify(result)); // to convert to JSON

//console.log('Decoded string:' + Buffer.from(result, 'base64').toString());  // to convert from base64



//console.log(`*** BD result: ***\n${JSON.stringify(result, null, 1)}`); //formatted, but too long
}
async function getRecordHistory(CONTRACT) {
	// get record ID
	//
	// lookup record public history
	//
	// extract TX IDs & add to array
	//
	// loop through array and pull actual TX records
	//
	// print output
}
*/

// function to query all parts in channel
async function queryAllParts(CONTRACT) {
	//This function queries all existing parts using a rich query
	console.log(`Querying all Parts in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryAssets', '{"selector":{"docType":"part"}}');
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryAssets', '{"selector":{"docType":"part"}}');
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	if (result.toString()=="") {
		console.log("No part records were found in channel".yellow)
	} else {
	console.log('*** result: ***'.cyan); //normal JSON
		console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	}
}

// function to query all orders in channel
async function queryAllOrders(CONTRACT) {
	//This function queries all existing parts using a rich query
	console.log(`Querying all Orders in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryAssets', '{"selector":{"docType":"order"}}');
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying query.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryAssets', '{"selector":{"docType":"order"}}');
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}

	}
		if (result.toString()=="") {
			console.log("No orders were found in channel".yellow)
		} else {
	console.log('*** result: ***'.cyan); //normal JSON
			console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
		}
}

// function to query all lots in channel
async function queryAllLots(CONTRACT) {
	//This function queries all existing lots using a rich query
	console.log("Querying all Lots in ledger");
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryAssets', '{"selector":{"docType":"lot record"}}');	
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying query.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryAssets', '{"selector":{"docType":"lot record"}}');	
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}

		return;
	} 
	if (result.toString()=="") {
		console.log("No lot records were found in channel".yellow)
	} else {
	console.log('*** result: ***'.cyan); //normal JSON
		console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	}
}

async function queryallPartsCollection(CONTRACT, COLLECTION) {
	//This function queries all existing parts using a rich query
	console.log(`Querying all Parts in Collection`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryPrivateAssets', COLLECTION, '{"selector":{"docType":"part"}}');
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryPrivateAssets', COLLECTION, '{"selector":{"docType":"part"}}');
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}

	}
	if (result.toString()=="") {
		console.log(`No parts were found in collection ${COLLECTION}`.yellow)
	} else {
	console.log('*** result: ***'.cyan); //normal JSON
		console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	}
}

async function queryallOrdersCollection(CONTRACT, COLLECTION) {
	//This function queries all existing parts using a rich query
	console.log(`Querying all Orders in Collection`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryPrivateAssets', COLLECTION, '{"selector":{"docType":"order"}}');
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryPrivateAssets', COLLECTION, '{"selector":{"docType":"order"}}');
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}

	}
	if (result.toString()=="") {
		console.log(`No orders were found in collection ${COLLECTION}`.yellow)
	} else {
	console.log('*** result: ***'.cyan); //normal JSON
		console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	}
}

async function queryallLotsCollection(CONTRACT, COLLECTION) {
	//This function queries all existing parts using a rich query
	console.log(`Querying all Lots in Collection`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryPrivateAssets', COLLECTION, '{"selector":{"docType":"lot record"}}');
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
	if (result.toString()=="") {
		console.log(`No lots were found in collection ${COLLECTION}`.yellow)
	} else {
	console.log('*** result: ***'.cyan); //normal JSON
		console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	}
}

//list all org's parts
async function queryAllMyParts(CONTRACT) {
	console.log(`Querying all ${ORG}'s Parts in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryAssets', `{\"selector\":{\"docType\":\"part\", \"issuer\": \"${ORG}\"}}`);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryAssets', `{\"selector\":{\"docType\":\"part\", \"issuer\": \"${ORG}\"}}`);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	if (result.toString()=="") {
		console.log(`No parts for org ${ORG} were found in channel`.yellow)
	} else {
	console.log('*** result: ***'.cyan); //normal JSON
		console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	}
}
//list all org's orders
async function queryAllMyOrders(CONTRACT) {
	console.log(`Querying all ${ORG}'s Orders in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryAssets', `{\"selector\":{\"docType\":\"order\", \"issuer\": \"${ORG}\"}}`);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryAssets', `{\"selector\":{\"docType\":\"order\", \"issuer\": \"${ORG}\"}}`);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	if (result.toString()=="") {
		console.log(`No orders for org ${ORG} were found in channel`.yellow)
	} else {
	console.log('*** result: ***'.cyan); //normal JSON
		console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	}
}
//list all org's lot numbers
async function queryAllMyLots(CONTRACT) {
	console.log(`Querying all ${ORG}'s Lot Numbers in ledger`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('QueryAssets', `{\"selector\":{\"docType\":\"lot record\", \"issuer\": \"${ORG}\"}}`);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('QueryAssets', `{\"selector\":{\"docType\":\"lot record\", \"issuer\": \"${ORG}\"}}`);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	if (result.toString()=="") {
		console.log(`No lot records for org ${ORG} were found in channel`.yellow)
	} else {
	console.log('*** result: ***'.cyan); //normal JSON
		console.dir(JSON.parse(result.toString()),{depth:null});  //looks much nicer!
	}
}

// helper function to insert value into nested object (used under MIT license, see comments)
function put (obj, path, val) {
	// (c) 2021 Chris Ferdinandi, MIT License, https://gomakethings.com
	function stringToPath (path) {

		// If the path isn't a string, return it
		if (typeof path !== 'string') return path;

		// Create new array
		let output = [];

		// Split to an array with dot notation
		path.split('.').forEach(function (item) {

			// Split to an array with bracket notation
			item.split(/\[([^}]+)\]/g).forEach(function (key) {

				// Push to the new array
				if (key.length > 0) {
					output.push(key);
				}

			});

		});

		return output;

	}

	// Convert the path to an array if not already
	path = stringToPath(path);

	// Cache the path length and current spot in the object
	let length = path.length;
	let current = obj;

	// Loop through the path
	path.forEach(function (key, index) {

		// Check if the assigned key should be an array
		let isArray = key.slice(-2) === '[]';

		// If so, get the true key name by removing the trailing []
		key = isArray ? key.slice(0, -2) : key;

		// If the key should be an array and isn't, create an array
		if (isArray && !Array.isArray(current[key])) {
			current[key] = [];
		}

		// If this is the last item in the loop, assign the value
		if (index === length -1) {

			// If it's an array, push the value
			// Otherwise, assign it
			if (isArray) {
				current[key].push(val);
			} else {
				current[key] = val;
			}
		}

		// Otherwise, update the current place in the object
		else {

			// If the key doesn't exist, create it
			if (!current[key]) {
				current[key] = {};
			}

			// Update the current place in the object
			current = current[key];

		}

	});
}

// look up asset to determine which collection it is saved under; if asset does not exist, returns "none"
async function getAssetCollection(ID, CONTRACT) {
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('ReadAsset', ID);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				result = await CONTRACT.evaluateTransaction('ReadAsset', ID);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}

	}
	return JSON.parse(result).collection
}

// Look for any quality alerts on every component used in part (recursive check)
async function CheckForQualityAlerts(CONTRACT) {
	//CheckForQualityAlerts
	console.log('Please enter the required information:'.cyan)
	let ID = prompt('Lot Number: ');
	console.log(`Checking for Quality Alerts on Lot ID ${ID}`);
	let result;
	try {
		result = await CONTRACT.evaluateTransaction('CheckForQualityAlerts', ID);
	} catch (err) {
		console.log('Error detected:\n'.red+ err)
		return;
	}
	console.log('*** result: ***'.cyan + `\n${result.toString()}`);
}
// TODO: unfinished: helper function to validate if the provided lot numbers satisfy all dependencies of provided part
async function ValidateComponents(CONTRACT, PART, COMPONENTS) {
	// Step 0: get part child component array
	let part;
	try {
		part = await CONTRACT.evaluateTransaction('ReadAsset', PART);
	} catch (err) {
		if (err.toString().includes("UNAVAILABLE: Connection dropped")) {
			console.clear();
			console.log("Detected gRPC error.  Resetting gateway and retrying function.".bgYellow)
			try {
				await gateway();
				console.log("Resubmitting query...")
				part = await CONTRACT.evaluateTransaction('ReadAsset', PART);
			} catch (err) {
				console.log('Error detected after gRPC reset:\n' + err)
				return;
			}
		} else {
			console.log('Error detected:\n'.red+ err)
			return;
		}
	}
	let children = JSON.parse(part).childAssets;
	console.log(`Part ${PART} has ${children.length} children`);

	let missingID;
	let failure; // tracker for entire loop (covering multiple collections)
	// Step 1: get collections (use global variable availableCollections)
	// for each collection, 
	let success;  // tracker for single loop (individual collection)
		// for each required child
		for (let j=0;j<children.length;j++) {
			// for each provided lot ID, look for matches
			for (let k=0;k<COMPONENTS.length; k++) {
				// get part ID from lot ID
				let lot = await CONTRACT.evaluateTransaction('ReadPartRecord', COLLECTION, LotNum);

				//NOTE: if cannot retrieve lot from from current collection THEN try other collections
				for (let i=0;i<availableCollections.length;i++) {
					lot = await CONTRACT.evaluateTransaction('ReadPartRecord', COLLECTION, LotNum);

				}

				let lotPartID = JSON.parse(lot).partID;
				// see if required child part ID matches retrieved lot part ID
				if (children[j] === lotPartID) {  // if so, break and return successful result
					success = true;  //success!
					break;
				} else {
					success = false;
					missingID = children[j];  // else, record error and finish loop
				}
			}
			if (!success) {  //failed to find match in current collection
				failure = true;
				break; //skip to next collection (if any) to keep checking
			}
		}
		// if success here, then can return; else continue with next iteration
	}
	


	// for each child component requirement, 
	// read record from database and check for matches







// sleep - wait x number of seconds  - example call: 'await sleep(1000)'
//function sleep(ms) {
//	return new Promise(resolve => setTimeout(resolve, ms));
//}

// force exit
function resetApp() {
	console.timeEnd('programTimer');
	return process.exit(5);
}

// helper function to get positive numeric user input
async function getPositiveNumber(Name, exitValue){
	let input=prompt(`${Name}: `).trim();
	while ( typeof(Number(input)) != "number" || input < 0 || isNaN(input) || input == "" || input.includes(" ") ) {
		if ( (exitValue) && input == exitValue ) {
			return input;
		}
		input=prompt('Please enter a valid number: '.bgRed).trim();
	}	
	return input;
}

// Check if provided ORG is member of provided collection
function checkMembership(ORG, GivenCollection) {
	// get membership of provided collection
	// check ORG against membership list
	for (let i=0; i<collections.length; i++) {
		if (collections[i].name == GivenCollection) {
			for (let j=0;j<collections[i].policy.length; j++) {
				if (collections[i].policy.includes(ORG)) {
					return true;
				}
			}
		}
	}
	return false;	
}

// auto-determine available collection names
async function getCollectionName(){
availableCollections = []; //reset to blank list in case this function has already been called
	try {
		// get names of multi-org collections for which this org is a member:
		// ignore org private collection name, since this can easily be deduced
		for (let i=0; i<collections.length; i++) {
			if (collections[i].policy.includes(ORG) && 
				collections[i].policy.includes(',') ) {
				availableCollections.push(collections[i].name);
			}
		}
		// if only one member of array, then set myCollection equal to this value
		if (availableCollections.length == 1) {
			console.log(`Setting myCollection equal to ${availableCollections[0]}`.green)
			myCollection = availableCollections[0];
		} else if (availableCollections.length > 1) {
			console.log(`There are ${availableCollections.length} collections available.  Which one do you want to use?`.cyan)
			for (let i=0; i<availableCollections.length; i++) {
				console.log(`Option ${i}: ${availableCollections[i]}`)
			}
			let input = prompt ('Please enter your choice number: '.cyan)
			while ( typeof(availableCollections[input])=='undefined') {
				input=prompt(`Please enter a valid number between 0 and ${availableCollections.length -1}: `.bgRed);
			}
			console.log(`Setting myCollection equal to ${availableCollections[input]}`.green)
			myCollection = availableCollections[input];
		}


	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}

async function partAndOrderMenu(contract){
	let exitLoop;
	while (!exitLoop) {
		const menu=[
			'Add Part', 
			'Add Order', 
			'Review Orders',
			'Return to Main Menu',
		]
		console.clear();
		console.log('  Main Menu'.bgGrey);
		console.log('> '+' Part & Order Menu'.bgBlue);
		menu.forEach(item => console.log('['+menu.indexOf(item)+']', item));
		let input = prompt('Please enter the function that you wish to run: '.cyan)
		while ( typeof(menu[input])=='undefined') {
			input=prompt(`Please enter a valid number between 0 and ${menu.length -1}: `.bgRed);
		}
		switch (Number(input)) {
			case 0: {
				console.log (`Running function "add part"`);
				try {
					await UIaddPart(contract, myCollection)
				} catch (err) {
					failureCallback(err)
				}
				returnToMenu();
				break;
			}
			case 1: {
				console.log (`Running function "add order"`);
				try {
					await UIaddOrder(contract, myCollection)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 2: {
				console.log (`Running function "review orders"`);
				try {
					await UIreviewOrders(contract, myCollection)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 3: {
				exitLoop=1;
				break;
			}
		}
	}	
}
async function manufacturingMenu(contract){
	let exitLoop;
	while (!exitLoop) {
		const menu=[
			'Manufacture Parts', 
			'Inspect Parts',
			'Check for Quality Alerts',
			'Return to Main Menu',
		]
		console.clear();
		console.log('  Main Menu'.bgGrey);
		console.log('> '+' Manufacturing Menu'.bgBlue);
		menu.forEach(item => console.log('['+menu.indexOf(item)+']', item));
		let input = prompt('Please enter the function that you wish to run: '.cyan)
		while ( typeof(menu[input])=='undefined') {
			input=prompt(`Please enter a valid number between 0 and ${menu.length -1}: `.bgRed);
		}
		switch (Number(input)) {
			case 0: {
				console.log (`Running function "manufacture"`);
				try {
					await UImakeparts(contract, myCollection)
				} catch(err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 1: {
				console.log (`Running function "inspect"`);
				try {
					await UIinspectParts(contract, myCollection)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 2: {
				console.log (`Checking for Quality Alerts`);
				try {
					await CheckForQualityAlerts(contract);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 3: {
				exitLoop=1;
				break;
			}
		}
	}
}
async function shippingAndReceivingMenu(contract){
	let exitLoop;
	while (!exitLoop) {
		const menu=[
			'Ship parts', 
			'Receive Parts',
			'Return to Main Menu',
		]
		console.clear();
		console.log('  Main Menu'.bgGrey);
		console.log('> '+' Shipping & Receiving Menu'.bgBlue);
		menu.forEach(item => console.log('['+menu.indexOf(item)+']', item));
		let input = prompt('Please enter the function that you wish to run: '.cyan)
		while ( typeof(menu[input])=='undefined') {
			input=prompt(`Please enter a valid number between 0 and ${menu.length -1}: `.bgRed);
		}
		switch (Number(input)) {
			case 0: {
				console.log (`Running function "ship"`);
				try {
					await UIship(contract, myCollection)
				} catch(err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 1: {
				console.log (`Running function "receive"`);
				try {
					await UIreceive(contract, myCollection)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 2: {
				exitLoop=1;
				break;
			}
		}
	}
}
async function queryMenu(contract){
	let exitLoop;
	while (!exitLoop) {
		const menu=[
			'single part', 
			'single order',
			'single lot record\n',

			'all parts',
			'all orders',
			'all lots\n',

			'my parts',
			'my orders',
			'my lots\n',

			'all parts collection',
			'all orders collection',
			'all lots collection\n',

			'Return to Main Menu',
		]
		console.clear();
		console.log('  Main Menu'.bgGrey);
		console.log('> '+' Query Menu'.bgBlue);
		menu.forEach(item => console.log('['+menu.indexOf(item)+']', item));
		let input = prompt('Please enter the function that you wish to run: '.cyan)
		while ( typeof(menu[input])=='undefined') {
			input=prompt(`Please enter a valid number between 0 and ${menu.length -1}: `.bgRed);
		}
		switch (Number(input)) {
			case 0: {
				console.log (`Querying single part`);
				try {
					await UIqueryPart(contract, myCollection)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 1: {
				console.log (`Querying single order`);
				try {
					await UIqueryOrder(contract, myCollection)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 2: {
				console.log (`Querying single lot`);
				try {
					await UIqueryLotRecord(contract, myCollection)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 3: {
				console.log (`Querying all parts`);
				try {
					await queryAllParts(contract);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 4: {
				console.log (`Querying all orders`);
				try {
					await queryAllOrders(contract);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 5: {
				console.log (`Querying all lots`);
				try {
					await queryAllLots(contract);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 6: {
				console.log (`Querying my parts`);
				try {
					await queryAllMyParts(contract);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 7: {
				console.log (`Querying my orders`);
				try {
					await queryAllMyOrders(contract);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 8: {
				console.log (`Querying all my lots`);
				try {
					await queryAllMyLots(contract);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 9: {
				console.log (`Querying all parts in collection`);
				try {
					await queryallPartsCollection(contract,myCollection);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 10: {
				console.log (`Querying all orders in collection`);
				try {
					await queryallOrdersCollection(contract,myCollection);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 11: {
				console.log (`Querying all lots in collection`);
				try {
					await queryallLotsCollection(contract,myCollection);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 12: {
				exitLoop=1;
				break;
			}
		}
	}
}
async function traceMenu(contract){
	let exitLoop;
	while (!exitLoop) {
		const menu=[
			'Full Lot Trace', 
			'Build Part Family Tree',
			'Get Public History of Asset',
			'Check for Quality Alerts',
			'Return to Main Menu',
		]
		console.clear();
		console.log('  Main Menu'.bgGrey);
		console.log('> '+' Traceability Menu'.bgBlue);
		menu.forEach(item => console.log('['+menu.indexOf(item)+']', item));
		let input = prompt('Please enter the function that you wish to run: '.cyan)
		while ( typeof(menu[input])=='undefined') {
			input=prompt(`Please enter a valid number between 0 and ${menu.length -1}: `.bgRed);
		}
		switch (Number(input)) {
			case 0: {
				console.log (`Running function "full lot trace"`);
				try {
					await UIgetLotGenealogyChannel(contract)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 1: {
				console.log (`Running function "build part family tree"`);
				try {
					await UIbuildPartFamilyTree(contract)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 2: {
				console.log (`Running function "get history of public asset"`);
				try {
					await UIgetRecordPublicHistory(contract)
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 3: {
				console.log (`Checking for Quality Alerts`);
				try {
					await CheckForQualityAlerts(contract);
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 4: {
				exitLoop=1;
				break;
			}
		}
	}
}
async function adminMenu(contract){
	let exitLoop;
	while (!exitLoop) {
		const menu=[
			'change collection',
			'restart app', 
			're-run app setup',
			'reset network connection',
			'delete asset',
			'Return to Main Menu',
		]
		console.clear();
		console.log('  Main Menu'.bgGrey);
		console.log('> '+' Administration Menu'.bgBlue);
		menu.forEach(item => console.log('['+menu.indexOf(item)+']', item));
		let input = prompt('Please enter the function that you wish to run: '.cyan)
		while ( typeof(menu[input])=='undefined') {
			input=prompt(`Please enter a valid number between 0 and ${menu.length -1}: `.bgRed);
		}
		switch (Number(input)) {
			case 0: {
				console.log (`Running function "change collection"`);
				try {
					await getCollectionName();
				} catch (err) {
					failureCallback(err)
				}
				break;
			}
			case 1: {
				console.log (`Running function "reset app"`);
				try {
					await resetApp()
				} catch (err) {
					failureCallback(err)
				}
				break;
			}
			case 2: {
				console.log (`Running function "app setup"`);
				try {
					await setup()
				} catch (err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 3: {
				console.log (`Resetting Gateway`);
				try {
					await gateway()
				} catch (err) {
					failureCallback(err);
				}
				break;
			}
			case 4: {
				console.log (`Running function "delete asset"`);
				try {
					await UIdeleteAsset(contract,myCollection)
				} catch(err) {
					failureCallback(err);
				}
				returnToMenu();
				break;
			}
			case 5: {
				exitLoop=1;
				break;
			}
		}
	}
}
async function mainMenu(contract){
	let exitLoop;
	while (!exitLoop) {
		try {
			const menu=[
				'Part & Order Setup', 
				'Manufacturing & Inspection', 
				'Shipping & Receiving',
				'Query',
				'Trace',
				'Admin',
				'exit',
			]
			console.clear();
			console.log('  Main Menu'.bgBlue);
			menu.forEach(item => console.log('['+menu.indexOf(item)+']', item));
			let input = prompt('Please enter the function that you wish to run: '.cyan)
			while ( typeof(menu[input])=='undefined') {
				input=prompt(`Please enter a valid number between 0 and ${menu.length -1}: `.bgRed);
			}
			switch (Number(input)) {
				case 0: {
					await partAndOrderMenu(contract);
					break;
				}
				case 1: {
					await manufacturingMenu(contract);
					break;
				}
				case 2: {
					await shippingAndReceivingMenu(contract);
					break;
				}
				case 3: {
					await queryMenu(contract);
					break;
				}
				case 4: {
					await traceMenu(contract);
					break;
				}
				case 5: {
					await adminMenu(contract);
					break;
				}
				case 6: {
					console.clear();
					process.exit(0);
					break;
				}
			}
		} catch (err) {
			console.log('error: ',err)
			prompt('waiting for your review')
		}
	}
}

function returnToMenu(){
	console.log();
	prompt('Press any key to return to menu'.cyan.underline+': ')
}
function failureCallback(err){
	console.log('Error detected:\n'.red+ err)
}

// Main workflow
async function main() {
	try {
			console.clear();
			console.log("Starting App".bgGray, "[========50%         ]")
			await getCollectionName()
		//	await setup()
			console.clear()
			console.log("Starting App".bgGray, "[========70%===      ]")
			await gateway()
		console.log("Starting App [=========100%=======]")
			await mainMenu(contractOrg1)
	} catch (err) {
		console.error('******** FAILED to run the application: '.red+err);
	}
}

main();
