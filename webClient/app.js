// This is a client-facing application for the Hyperledger Fabric Supply Chain Project
// It calls chaincode (written in Go) for this project
//
// Created by Simeon MacMillen (楚昊瑜)
// 2021-2-1
 /* eslint-disable no-useless-escape */


'use strict';

// required external modules
require('dotenv').config(); // required to use .env environment variable file
const { Gateway, Wallets } = require('fabric-network');
const FabricCAServices = require('fabric-ca-client');
const path = require('path');
//const prompt = require('prompt-sync')({sigint: true});
//const fs = require('fs').promises; // used to access files off server
require('colors'); // enable color formatting of strings in terminal
//const treeify = require('treeify');
const dateFormat = require("dateformat");
const express = require('express');
const bodyParser = require('body-parser');
const qr = require("qrcode")

const { buildCAClient, registerAndEnrollUser, enrollAdmin } = require(`/app/utils/CAUtil.js`);
const { buildCCPOrg1, buildWallet } = require(`/app/utils/AppUtil.js`); 
//const query = require('./scripts/query');
const s = require('./scripts/utils');



// app variables
const app = express();
const port = 3001;
dateFormat.masks.myFormat = 'yyyy.mm.dd'
const channelName = process.env.ChannelID;
const chaincodeName = process.env.CHAINCODE_NAME;
const mspOrg1 = process.env.CORE_PEER_LOCALMSPID;
//const walletPath = path.join(__dirname, 'wallet');
//const org1UserId = 'oemAppUser';
const Org1UserId = 'appUser2';
const org1Address=process.env.orgAddress;
const ORG=process.env.ORG;
const org=process.env.org;
const affiliation=''; //this value is used in cert/id generation # previously =`${org}.department1` 
let endorsingPeer = '';
let gatewayOrg1;
let contractOrg1;
//const QRpath = path.join(__dirname, 'QRcodes');

//get collections and convert to js object:
const collections = require(`/app/config/collections_config.json`,'utf8');
let availableCollections = []; // global list of collections that this org has access to


// App Configuration
app.set("views",path.join(__dirname,"views"));
app.set("view engine","pug");
app.use(express.static(path.join(__dirname,"public")));
app.use(bodyParser.urlencoded({extended: true}));
app.use(bodyParser.json());
app.use(function (err, req, res, next) {
	console.error(err.stack)
	res.status(500)
	res.render('error', { error: err })
})

module.exports = app;

/*
 *  Routes Definitions
 */
// basic routes:
//app.get('/', site.home);

app.get('/', (req,res) => {
	res.render("index",{title: "Home", ORG:ORG});
})

app.get('/make', (req,res) => {
	res.render("manufacture",{title: "Manufacturing Menu", ORG:ORG});
})

app.get('/shipping', (req,res) => {
	res.render("shipping",{title: "Shipping or Receiving Menu", ORG:ORG});
})


app.get('/query', (req,res) => {
	res.render("qcustom",{title: "Custom Query", PDC: availableCollections, ORG:ORG });
})


app.get('/query/parts', (req,res) => {
	res.render("qparts",{title: "Query Parts Menu", ORG:ORG});
})

app.get('/query/orders', (req,res) => {
	res.render("qorders",{title: "Query Orders Menu", ORG:ORG});
})

app.get('/query/lots', (req,res) => {
	res.render("qlots",{title: "Query Lots Menu", ORG:ORG});
})

app.get('/admin', (req,res) => {
	res.render("admin",{title: "Admin Menu", ORG:ORG});
})


//**********************************************
// 								GET ROUTES 							
//**********************************************

app.get('/orders', (req,res) => {
	res.render("orders",{title: "Order Menu", ORG:ORG});
})

app.get('/orders/add', (req,res) => {
	res.render("addorder",{title: "Add New Order", actionPath: "/orders/addorder/result", PDC: availableCollections,ORG:ORG});
})

app.get('/parts', (req,res) => {
	res.render("parts",{title: "Parts Menu", PDC: availableCollections, ORG:ORG });
})

app.get('/parts/design', (req,res) => {
	res.render("designPart",{title: "Design New Part", PDC: availableCollections, ORG:ORG });
})

app.get('/parts/query', (req,res) => {
	res.render("queryParts",{title: "Query Parts", PDC: availableCollections, ORG:ORG });
})

// formerly queryAllParts
// formerly /query/parts/all
app.get ('/parts/query-all', async (req,res) => {
	try {
		res.val = await contractOrg1.evaluateTransaction('QueryAssets', '{"selector":{"docType":"part"}}');
		if (!res.val) {
			console.log('res.val evaluates to false')
			let msg = "An unexpected error occurred.  Please contact your account administrator."
			res.render('error',{title: 'Error', message: msg, returnTo: '/qparts', ORG:ORG});
		} else if ((res.val).length===0) {
			console.log('res.val has length of zero')
			let msg=`No parts found in database`
			res.render('error',{title: 'Error', message: msg, returnTo: '/qparts', ORG:ORG});
		} else {
			let result = JSON.parse((res.val).toString());
			res.render("queryResult",{title: "All Parts in Channel",payload: result, ORG:ORG});
		}

	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/qparts', ORG:ORG});
	}
})

app.get('/lots', (req,res) => {
	res.render("lots",{title: "Lot Menu", PDC: availableCollections, ORG:ORG });
})


app.get('/lots/query', (req,res) => {
	res.render("queryLots",{title: "Query Lots", PDC: availableCollections, ORG:ORG });
})
// formerly queryAllLots
app.get ('/lots/query-all', async (req,res) => {
	try {
		res.val = await contractOrg1.evaluateTransaction('QueryAssets', '{"selector":{"docType":"lot record"}}');
		if (!res.val) {
			console.log('res.val evaluates to false')
			let msg = "An unexpected error occurred.  Please contact your account administrator."
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else if ((res.val).length===0) {
			console.log('res.val has length of zero')
			let msg=`No lots found in database`
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else {
			let result = JSON.parse((res.val).toString());
			res.render("queryResult",{title: "All Lots in Channel",payload: result, ORG:ORG});
		}

	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, ORG:ORG});
	}
})

app.get('/orders/query', (req,res) => {
	res.render("queryOrders",{title: "Query Orders", PDC: availableCollections, ORG:ORG });
})
// formerly queryAllOrders
app.get ('/orders/query-all', async (req,res) => {
	try {
		res.val = await contractOrg1.evaluateTransaction('QueryAssets', '{"selector":{"docType":"order"}}');
		if (!res.val) {
			console.log('res.val evaluates to false')
			let msg = "An unexpected error occurred.  Please contact your account administrator."
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else if ((res.val).length===0) {
			console.log('res.val has length of zero')
			let msg=`No orders found in database`
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else {
			let result = JSON.parse((res.val).toString());
			res.render("queryResult",{title: "All Orders in Channel",payload: result, ORG:ORG});
		}

	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, ORG:ORG});
	}
})


/* Depreciated Routes: */
app.get('/query/parts/single', (req,res) => {
	res.render("singleQuery",{title: "Query Single Part", PDC: availableCollections,type: "part",actionPath: "/query/parts/result", ORG:ORG});
})
app.get('/query/orders/single', (req,res) => {
	res.render("singleQuery",{title: "Query Single Order", PDC: availableCollections,type: "order",actionPath: "/query/orders/result", ORG:ORG});
})
app.get('/query/lots/single', (req,res) => {
	res.render("singleQuery",{title: "Query Single Lot", PDC: availableCollections,type: "lot",actionPath: "/query/lots/result", ORG:ORG});
})
app.get('/admin/designpart', (req,res) => {
	res.render("designPart",{title: "Design New Part", PDC: availableCollections, ORG:ORG });
})
app.get('/admin/deleteasset', (req,res) => {
	res.render("deleteAsset",{title: "Delete Asset", PDC: availableCollections, ORG:ORG });
})
// review orders
app.get('/orders/review', async (req,res) => {
	// get orders pending review
	try {
		let COLLECTION, pendingOrders;
		for (let i=0; i<availableCollections.length; i++ ) {
			availableCollections[i]
			console.log('looking for pendingOrders on each collection:')
			let tempVal = await contractOrg1.evaluateTransaction('QueryPrivateAssets',availableCollections[i],`{\"selector\":{\"docType\":\"order\",\"supplier\":\"${ORG}\",\"status\":\"new order\"}}`);
			tempVal = JSON.parse(tempVal);
			console.log('new value of tempVal: ',tempVal)
			if (tempVal.length>0){
				COLLECTION=availableCollections[i];
				pendingOrders=tempVal;
				console.log(`${pendingOrders.length} pending orders found in collection ${availableCollections[i]}.`)
			} else {
				console.log(`No pending orders found in collection ${availableCollections[i]}.`)
			}
		}

		res.render("reviewOrders",{title: "Review Orders", actionPath: '/orders/review', pendingOrders: pendingOrders, PDC: COLLECTION, ORG:ORG});
		console.log('pendingOrders: ',pendingOrders)
		console.log('COLLECTION: ',COLLECTION)

	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/orders', ORG:ORG});
	}
})
// manufacture parts
app.get('/lots/make', (req,res) => {
	res.render("manufacturePart",{title: "Manufacture Parts", actionPath: "/lots/make", ORG:ORG});
})

// inspect parts: get ID, measurements
app.get('/lots/inspect', async (req,res) => {
	if (checkIfObjectIsEmpty(req.query)) {
		//res.render("getPartToInspect",{title: "Get Lot to Inspect"});
		res.render("getLot",{title: "Scan Lot to Inspect",IMAGE: '/bar-code-icon.png', ALT_TXT: 'scan barcode image',ACTION: '/lots/inspect', ORG:ORG});
	} else {
		console.log('received query: ',req.query)
		console.log('req.query.LN: ',req.query.LN)

		try  {
			// find out which collection this lot is stored in:
			let assetID = `, "assetID":"${req.query.LN}"`
			let str = `{"selector":{"docType":"lot record"${assetID}}}`  // build search string
			res.val = await contractOrg1.evaluateTransaction('QueryAssets', `${str}`); // call chaincode
			let lotInfo = JSON.parse((res.val).toString());
			console.log('value of lotInfo (channel lot info): ',lotInfo)
			console.log('value of lotInfo[0].collection: ',lotInfo[0].collection)
			// get full Lot details from collection:
			res.val = await contractOrg1.evaluateTransaction('ReadPartRecord', lotInfo[0].collection, req.query.LN);
			let PDClotInfo = JSON.parse((res.val).toString());
			console.log('value of lotInfo (PDC lot info): ',PDClotInfo)
			// get Part details from collection:
			res.val = await contractOrg1.evaluateTransaction('ReadPartPrivateDetails', lotInfo[0].collection, PDClotInfo.partID);
			let partInfo = JSON.parse((res.val).toString());
			console.log('value of partInfo: ',partInfo)
			res.render("inspect",{title: "Inspect Parts", LN: req.query.LN, partInfo: partInfo,lotInfo: PDClotInfo, PDC: lotInfo[0].collection, ORG:ORG});
		} catch (err) {
			console.log('catch activated')
			let msg = s.failureCallback(err);
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		}
	}
})

// ship parts: 
app.get('/shipping/ship',async (req,res) => {
	if (checkIfObjectIsEmpty(req.query)) {
		res.render("getLot",{title: "Scan Lot to Ship",IMAGE: '/bar-code-icon.png', ALT_TXT: 'scan barcode image',ACTION: '/shipping/ship', ORG:ORG});
	} else {
		console.log('received query: ',req.query)
		console.log('req.query.LN: ',req.query.LN)
		try  {
			// get PDC and quality status for lot:
			console.log('get PDC and quality status for lot')
			let assetID = `, "assetID":"${req.query.LN}"`
			let str = `{"selector":{"docType":"lot record"${assetID}}}`  // build search string
			res.val = await contractOrg1.evaluateTransaction('QueryAssets', `${str}`); // call chaincode
			let lotInfo = JSON.parse((res.val).toString());
			console.log('value of lotInfo (channel lot info): ',lotInfo)
			console.log('value of PDC: ',lotInfo[0].collection)
			// get full Lot details from collection (including quality status and location):
			res.val = await contractOrg1.evaluateTransaction('ReadPartRecord', lotInfo[0].collection, req.query.LN);
			let PDClotInfo = JSON.parse((res.val).toString());
			console.log('value of lotInfo (PDC lot info): ',PDClotInfo)
			console.log('value of qualityStatus (PDC lot info): ',PDClotInfo.qualityStatus)

			if (PDClotInfo.location != ORG ) {
				if ((PDClotInfo.location).includes('in transit')) {
					throw `Unable to ship because lot ${req.query.LN} is ${PDClotInfo.location}`
				} else {
					throw `Unable to ship because lot ${req.query.LN} is at ${PDClotInfo.location}`
				}
			} else if (PDClotInfo.qualityStatus === 'accepted') {
				console.log(`${req.query.LN} has an acceptable quality status`.green)
				// proceed with next step:
				res.render("shipLot",{title: "Ship Lot ", LN: req.query.LN, LOC: PDClotInfo.location, PDC: lotInfo[0].collection, IMAGE: '/shipping-icon.png', ALT_TXT: 'shipping box image', ORG:ORG});
			} else if (PDClotInfo.qualityStatus === 'rejected') {  //TODO: confirm rejected status name
				console.log(`${req.query.LN} has a rejected quality status`.red)
				throw `Unable to ship lot ${req.query.LN} because of a rejected quality status`
			} else {
				console.log(`${req.query.LN} has an unacceptable quality status`.yellow)
				throw `Unable to ship lot ${req.query.LN} because it is missing inspection`
			}

		} catch (err) {
			console.log('catch activated')
			let msg = s.failureCallback(err);
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		}
	}
})

// receive parts:
app.get('/shipping/receive',async (req,res) => {
	if (checkIfObjectIsEmpty(req.query)) {
		res.render("getLot",{title: "Scan Lot to Receive",IMAGE: '/bar-code-icon.png', ALT_TXT: 'scan barcode image',ACTION: '/shipping/receive', ORG:ORG});
	} else {
		console.log('received query: ',req.query)
		console.log('req.query.LN: ',req.query.LN)
		console.log('req.query.QTY: ',req.query.QTY)
		try  {
			// get PDC and quality status for lot:
			console.log('get PDC and quality status for lot')
			let assetID = `, "assetID":"${req.query.LN}"`
			let str = `{"selector":{"docType":"lot record"${assetID}}}`  // build search string
			res.val = await contractOrg1.evaluateTransaction('QueryAssets', `${str}`); // call chaincode
			let lotInfo = JSON.parse((res.val).toString());
			console.log('value of lotInfo (channel lot info): ',lotInfo)
			console.log('value of PDC: ',lotInfo[0].collection)
			// get full Lot details from collection (including quality status, location, and quantity):
			res.val = await contractOrg1.evaluateTransaction('ReadPartRecord', lotInfo[0].collection, req.query.LN);
			let PDClotInfo = JSON.parse((res.val).toString());
			console.log('value of lotInfo (PDC lot info): ',PDClotInfo)
			console.log('value of qualityStatus (PDC lot info): ',PDClotInfo.qualityStatus)
			console.log('value of quantity (PDC lot info): ',PDClotInfo.quantity)

			if (PDClotInfo.location === ORG ) {
				if ((PDClotInfo.location).includes('Receiving')) {
					throw `Lot ${req.query.LN} has already been received`
				} else {
					throw `Lot ${req.query.LN} is already at ${ORG}`
				}
			} else if (PDClotInfo.qualityStatus === 'accepted') {
				console.log(`${req.query.LN} has an acceptable quality status`.green)
				// proceed with next step:
				res.render("receiveLot",{title: "Receive Lot ", LN: req.query.LN,QTY_expected: PDClotInfo.quantity, PDC: lotInfo[0].collection, IMAGE: '/shipping-icon.png', ALT_TXT: 'shipping box image', ORG:ORG});
			} else if (PDClotInfo.qualityStatus === 'rejected') {  //TODO: confirm rejected status name
				console.log(`${req.query.LN} has a rejected quality status`.red)
				throw `Unable to receive lot ${req.query.LN} because of a rejected quality status`
			} else {
				console.log(`${req.query.LN} has an unacceptable quality status`.yellow)
				throw `Unable to receive lot ${req.query.LN} because has a quality status of ${PDClotInfo.qualityStatus}`
			}

		} catch (err) {
			console.log('catch activated')
			let msg = s.failureCallback(err);
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		}
	}
})

//**********************************************
// 								POST ROUTES
//**********************************************

// create new part design
app.post('/admin/designpart', (req,res) => {
	console.log('provided data: req.body: ',req.body)
	res.render("addDIMs",{title: "Design New Part", PDC: availableCollections, Data: req.body, ORG:ORG});
})
// create new part design (result)
app.post('/admin/designpart/result', async (req,res) => {
	console.log('provided data: req.body: ',req.body)
	let DIMS=[];
	let PN, NAME, PPN, NUMDIMS,COLLECTION;
	if (Array.isArray(req.body.CPK)) {
		// loop through array
		for (let i=0;i<((req.body.CPK).length); i++) {
			DIMS.push(i+1); // dimension i
			DIMS.push(parseFloat(req.body.UCL[i]));
			DIMS.push(parseFloat(req.body.LCL[i]));
			DIMS.push(parseFloat(req.body.Target[i]));
			DIMS.push(parseFloat(req.body.CPK[i]));
		}
		PN=req.body.partID;
		NAME=req.body.partName;
		PPN=req.body.parentID;
		NUMDIMS=Number(req.body.numDims);
		COLLECTION=req.body.pdc;
	} else {
		// directly pull values
		DIMS.push(1);
		DIMS.push(parseFloat(req.body.UCL));
		DIMS.push(parseFloat(req.body.LCL));
		DIMS.push(parseFloat(req.body.Target));
		DIMS.push(parseFloat(req.body.CPK));
		PN=req.body.partID;
		NAME=req.body.partName;
		PPN=req.body.parentID;
		NUMDIMS=Number(req.body.numDims);
		COLLECTION=req.body.pdc;
	}
	try {
		let newPart = { partID: PN, partName: NAME, parentPart: PPN, numOfDims: NUMDIMS, dimensions: DIMS, collection: COLLECTION};
		let statefulTxn = contractOrg1.createTransaction('AddPart');
		let tmapData = Buffer.from(JSON.stringify(newPart));
		statefulTxn.setTransient({
			asset_properties: tmapData
		});
		await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
		let msg=`"Part ${PN}" was created successfully.`
		res.render('success',{title: 'Success', message: msg, returnTo: '/admin', ORG:ORG});
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/admin/designpart', ORG:ORG});
	}
})
// delete asset
app.post('/admin/deleteasset', async (req,res) => {
	console.log('provided data: req.body: ',req.body)
	try {
		let dataForDelete = { assetID: req.body.assetID};
		let statefulTxn = contractOrg1.createTransaction('DeleteAsset');
		let tmapData = Buffer.from(JSON.stringify(dataForDelete));
		statefulTxn.setTransient({
			asset_delete: tmapData
		});

		await statefulTxn.setEndorsingPeers([endorsingPeer]).submit(req.body.pdc);
		let msg=`"Asset ${req.body.assetID}" was successfully deleted from the channel and from collection ${req.body.pdc}.`
		res.render('success',{title: 'Success', message: msg, returnTo: '/admin', ORG:ORG});
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/admin', ORG:ORG});
	}
})
// formerly partQueryResult
app.post ('/query/parts/result', async (req,res) => {
	try {
		if (req.body.database === 'channel') {
			let assetID = `, "assetID":"${req.body.assetID}"`
			let str = `{"selector":{"docType":"part"${assetID}}}`  // build search string
			res.val = await contractOrg1.evaluateTransaction('QueryAssets', `${str}`); // call chaincode
		} else if (req.body.database === 'collection') {
			res.val = await contractOrg1.evaluateTransaction('ReadPartPrivateDetails', req.body.pdc, req.body.assetID);
		} else {
			console.log('no database type provided')
			throw 'No database type provided.  Please see your administrator for assistance.'
		}

		if (!res.val) {
			console.log('res.val evaluates to false')
			let msg = "An unexpected error occurred.  Please contact your account administrator."
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else if ((res.val).length===0 && req.body.database ==='channel') {
			console.log('res.val has length of zero for channel query')
			let msg=`"${req.body.assetID}" does not exist in channel`
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else if ((res.val).length===0 && req.body.database ==='collection') {
			console.log('res.val has length of zero for PDC query')
			let msg=`"${req.body.assetID}" does not exist in ${req.body.pdc}`
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else {
			let result = JSON.parse((res.val).toString());
			res.render("queryResult",{title: "Part Query Results",payload: result, ORG:ORG});
		}
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/query/parts/single', ORG:ORG});
	}
	console.log('provided data: req.body: ',req.body)
})
// formerly orderQueryResult
app.post ('/query/orders/result', async (req,res) => {
	try {
		if (req.body.database === 'channel') {
			let assetID = `, "assetID":"${req.body.assetID}"`
			let str = `{"selector":{"docType":"order"${assetID}}}`  // build search string
			res.val = await contractOrg1.evaluateTransaction('QueryAssets', `${str}`); // call chaincode
		} else if (req.body.database === 'collection') {
			res.val = await contractOrg1.evaluateTransaction('ReadOrderPrivateDetails', req.body.pdc, req.body.assetID); 
		} else {
			console.log('no database type provided')
			throw 'No database type provided.  Please see your administrator for assistance.'
		}

		if (!res.val) {
			console.log('res.val evaluates to false')
			let msg = "An unexpected error occurred.  Please contact your account administrator."
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else if ((res.val).length===0 && req.body.database === 'collection') {
			console.log('res.val has length of zero')
			let msg=`"${req.body.assetID}" does not exist in ${req.body.pdc}`
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else if ((res.val).length===0 && req.body.database === 'channel') {
			console.log('res.val has length of zero')
			let msg=`"${req.body.assetID}" does not exist in channel.`
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else {
			let result = JSON.parse((res.val).toString());
			res.render("queryResult",{title: "Order Query Results",payload: result, ORG:ORG});
		}
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/query/orders/single', ORG:ORG});
	}
	console.log('provided data: req.body: ',req.body)
})
// formerly lotQueryResult
app.post ('/query/lots/result', async (req,res) => {
	try {

		if (req.body.database === 'channel') {
			let assetID = `, "assetID":"${req.body.assetID}"`
			let str = `{"selector":{"docType":"lot record"${assetID}}}`  // build search string
			res.val = await contractOrg1.evaluateTransaction('QueryAssets', `${str}`); // call chaincode
		} else if (req.body.database === 'collection') {
			res.val = await contractOrg1.evaluateTransaction('ReadPartRecord', req.body.pdc, req.body.assetID);
		} else {
			console.log('no database type provided')
			throw 'No database type provided.  Please see your administrator for assistance.'
		}


		if (!res.val) {
			console.log('res.val evaluates to false')
			let msg = "An unexpected error occurred.  Please contact your account administrator."
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else if ((res.val).length===0 && req.body.database === 'collection') {
			console.log('res.val has length of zero')
			let msg=`"${req.body.assetID}" does not exist in ${req.body.pdc}.`
			res.render('error',{title: 'Error', message: msg, ORG:ORG});
		} else if ((res.val).length===0 && req.body.database === 'channel') {
			console.log('res.val has length of zero')
			let msg=`"${req.body.assetID}" does not exist in channel.`
			res.render('error',{title: 'Error', message: msg, ORG:ORG});


		} else {
			let result = JSON.parse((res.val).toString());
			res.render("queryResult",{title: "Lot Query Results",payload: result, ORG:ORG});
		}
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/query/lots/single', ORG:ORG});
	}
	console.log('provided data: req.body: ',req.body)
})
// custom query:
app.post ('/query/result', async (req,res) => {
	//res.send(req.body)
	let str;
	switch (req.body.type) {
		case 'part':
			if (req.body.database === 'channel') {
				// possible selectors: assetID, issuer
				let assetID,issuer;
				if (req.body.assetID) {
					assetID = `, "assetID":"${req.body.assetID}"`
				} else { assetID = ''; }

				if (req.body.issuer) {
					issuer = `, "issuer":"${req.body.issuer}"`
				} else { issuer = ''; }

				str = `{"selector":{"docType":"part"${issuer}${assetID}}}`  // build search string

			} else if (req.body.database === 'collection') {
				// possible selectors: partID, customer, parentPart
				let partID, customer, parentPart;

				if (req.body.partID) {
					partID = `, "partID":"${req.body.partID}"`
				} else { partID = ''; }

				if (req.body.customer) {
					customer = `, "customer":"${req.body.customer}"`
				} else { customer = ''; }

				if (req.body.parentPart) {
					parentPart = `, "parentPart":"${req.body.parentPart}"`
				} else { parentPart = ''; }

				str = `{"selector":{"docType":"part"${partID}${customer}${parentPart}}}`  // build search string

			} else {
				let msg = s.failureCallback('unexpected value')
				res.render('error',{title: 'Error', message: msg, returnTo: '/query', ORG:ORG});
			}

			break;
		case 'order':
			if (req.body.database === 'channel') {
				// possible selectors: assetID, issuer
				let assetID,issuer;

				if (req.body.assetID) {
					assetID = `, "assetID":"${req.body.assetID}"`
				} else { assetID = ''; }
				if (req.body.issuer) {
					issuer = `, "issuer":"${req.body.issuer}"`
				} else { issuer = ''; }
				
				str = `{"selector":{"docType":"order"${issuer}${assetID}}}`  // build search string
			
			} else if (req.body.database === 'collection') {
				// possible selectors: orderID, PartID, customer, supplier, status 
				let orderID, PartID, customer, supplier, status;

				if (req.body.orderID) {
					orderID = `, "orderID":"${req.body.orderID}"`
				} else { orderID = ''; }
				if (req.body.partID) {
					PartID = `, "PartID":"${req.body.partID}"`
				} else { PartID = ''; }
				if (req.body.customer) {
					customer = `, "customer":"${req.body.customer}"`
				} else { customer = ''; }
				if (req.body.supplier) {
					supplier = `, "supplier":"${req.body.supplier}"`
				} else { supplier = ''; }
				if (req.body.status) {
					status = `, "status":"${req.body.status}"`
				} else { status = ''; }

				str = `{"selector":{"docType":"order"${orderID}${PartID}${customer}${supplier}${status}}}`  // build search string
			} else {
				let msg = s.failureCallback('unexpected value')
				res.render('error',{title: 'Error', message: msg, returnTo: '/query', ORG:ORG});
			}

			break;
		case 'lot':
			if (req.body.database === 'channel') {
				// possible selectors: assetID
				let assetID;

				if (req.body.assetID) {
					assetID = `, "assetID":"${req.body.assetID}"`
				} else { assetID = ''; }

				str = `{"selector":{"docType":"lot record"${assetID}}}`  // build search string

			} else if (req.body.database === 'collection') {
				// possible selectors: lotID, orderID, partID, qualityStatus, operation, location
				let lotID, orderID, partID, qualityStatus, operation, location;

				if (req.body.lotID) {
					lotID = `, "lotID":"${req.body.lotID}"`
				} else { lotID = ''; }

				if (req.body.orderID) {
					orderID = `, "orderID":"${req.body.orderID}"`
				} else { orderID = ''; }

				if (req.body.partID) {
					partID = `, "partID":"${req.body.partID}"`
				} else { partID = ''; }

				if (req.body.qualityStatus) {
					qualityStatus = `, "qualityStatus":"${req.body.qualityStatus}"`
				} else { qualityStatus = ''; }

				if (req.body.operation) {
					operation = `, "operation":"${req.body.operation}"`
				} else { operation = ''; }

				if (req.body.location) {
					location = `, "location ":"${req.body.location}"`
				} else { location = ''; }

				str = `{"selector":{"docType":"lot record"${lotID}${orderID}${partID}${qualityStatus}${operation}${location}}}`  // build search string

			} else {
				let msg = s.failureCallback('unexpected value')
				res.render('error',{title: 'Error', message: msg, returnTo: '/query', ORG:ORG});
			}

			break;
	} //end switch

	// run query and get result
	try {
		if (req.body.database === 'channel') {
			res.val = await contractOrg1.evaluateTransaction('QueryAssets', `${str}`); // call chaincode
		} else if (req.body.database === 'collection') {
			res.val = await contractOrg1.evaluateTransaction('QueryPrivateAssets', req.body.pdc, `${str}`);
		} else {
			console.log('no database type provided')
			throw 'No database type provided.  Please see your administrator for assistance.'
		}

		if (!res.val) {
			console.log('res.val evaluates to false')
			let msg = "An unexpected error occurred.  Please contact your account administrator."
			res.render('error',{title: 'Error', message: msg, returnTo: '/query/custom', ORG:ORG});
		} else if ((res.val).length===0 || JSON.parse((res.val).toString()).length===0) {
			console.log('res.val has length of zero')
			let msg=`No results were found.  Please try different search options.`
			res.render('error',{title: 'Error', message: msg, returnTo: '/query/custom', ORG:ORG});
		} else {
			let result = JSON.parse((res.val).toString());
			//res.render("customQueryResult",{title: "Custom Query Results: ",payload: result, ORG:ORG});
			res.render("queryResult",{title: "Custom Query Results",payload: result, ORG:ORG});
		}

	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/query/custom', ORG:ORG});
	}
	console.log('provided data: req.body: ',req.body)
})
// create new order
app.post('/orders/addorder/result', async (req,res) => {
	console.log('provided data: req.body: ',req.body)
	try {
		let ON,PN,DueDate,QTY,SUPPLIER,COLLECTION;
		ON=req.body.orderID;
		PN=req.body.partID;
		DueDate=req.body.dueDate;
		QTY=Number(req.body.qty);
		SUPPLIER=req.body.supplier;
		COLLECTION=req.body.pdc
		let newOrder = { orderID: ON, partID: PN, dueDate: DueDate, quantity: QTY, supplier: SUPPLIER, collection: COLLECTION};
		console.log(`Adding Order ${ON} for Part ${PN}`);
		let statefulTxn = contractOrg1.createTransaction('AddOrder');
		let tmapData = Buffer.from(JSON.stringify(newOrder));
		statefulTxn.setTransient({
			asset_properties: tmapData
		});

		await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
		let msg=`"Order ${ON}" was created successfully.`
		res.render('success',{title: 'Success', message: msg, returnTo: '/orders', ORG:ORG});
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/orders/addorder', ORG:ORG});
	}
})
// review orders
app.post('/orders/review', async (req,res) => {
	console.log('provided data: req.body: ',req.body)
	try {
	let transient = { orderID: req.body.orderID, decision: req.body.decision, comments: '', collection: req.body.pdc};
	if (req.body.decision=='accept') {
		console.log(`Accepting Order ${req.body.orderID}`);
	} else if (req.body.decision=='reject') {
		console.log(`Rejecting Order ${req.body.orderID}`);
	} else {
		throw `unexpected value for order decision ${req.body.orderID}. Please contact a system administrator.`
	}
	let statefulTxn = contractOrg1.createTransaction('AcceptRejectOrder');
	// generate transient:
	let tmapData = Buffer.from(JSON.stringify(transient));
	statefulTxn.setTransient({
		asset_properties: tmapData
	});
		await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
		let msg=`"Order ${req.body.orderID}" was successfully processed with a decision of \"${req.body.decision}\".`
		res.render('success',{title: 'Success', message: msg, returnTo: '/orders', ORG:ORG});
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/orders', ORG:ORG});
	}
})
// manufacture parts step 1
app.post('/lots/make', async (req,res) => {
	console.log('makeparts step 1'.blue)
	console.log('provided data: req.body: ',req.body)
	try {
		console.log('Querying for part in database')
		let assetID = `, "assetID":"${req.body.partID}"`
		let str = `{"selector":{"docType":"part"${assetID}}}`  // build search string
		res.val = await contractOrg1.evaluateTransaction('QueryAssets', `${str}`); // call chaincode

		if (!res.val) {
			console.log('res.val evaluates to false')
			let msg = "An unexpected error occurred.  Please contact your account administrator."
			res.render('error',{title: 'Error', message: msg, returnTo: '/query/custom', ORG:ORG});
		} else if ((res.val).length===0 || JSON.parse((res.val).toString()).length===0) {
			console.log('res.val has length of zero')
			let msg=`Part ${assetID} does not exist.  Please revise your input and try again.`
			res.render('error',{title: 'Error', message: msg, returnTo: '/query/custom', ORG:ORG});
		} else {
			let result = JSON.parse((res.val).toString());
			console.log('parsed value from database: ',result)
			console.log('looking for child assets in received value: ',result[0].childAssets)
			res.render("manufacturePart2",{title: "Manufacture Parts", Ingredients: result[0].childAssets, PDC: result[0].collection, PN: req.body.partID, ON: req.body.orderID, actionPath: "/lots/make2", ORG:ORG});
		}
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/lots/make', ORG:ORG});
	}
})
// manufacture parts result
app.post('/lots/make2', async (req,res) => {
	console.log('makeparts step 2 (results)'.blue)
	console.log('provided data: req.body: ',req.body)
	try {
		let newLot = { partID: req.body.PN, orderID: req.body.ON, quantity: Number(req.body.QTY), subcomponents: req.body.SUB, collection: req.body.PDC};
		console.log(`Creating new lot of Part ${req.body.PN} for Order ${req.body.ON}...`);
		console.log(`information to submit: `,newLot)

		let statefulTxn = contractOrg1.createTransaction('MakePart');
		// generate transient:
		let tmapData = Buffer.from(JSON.stringify(newLot));
		statefulTxn.setTransient({
			asset_properties: tmapData
		});
		
		let result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
		let LotID=result.toString();
		console.log('Successfully created new lot ',LotID);

		let qrcode = await getQR(LotID) //generate QR code data

		res.render('lotTag', {qrsrc: qrcode, PN: req.body.PN, ON: req.body.ON, LN: LotID, ORG:ORG});

	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, returnTo: '/lots/make', ORG:ORG});
	}
})
// inspect step 2
app.post('/lots/inspect', async (req,res) => {
	console.log('provided data: req.body: ',req.body)
	try {

		// get measurements and convert to number format:
		let DIMS=[];
		for (let i=0;i<(req.body.measurements).length; i++) {
			DIMS.push(parseFloat(req.body.measurements[i]))
		}

		// package and submit: 
		let newDimData = { partID: req.body.partID, lotID: req.body.lotID, DimensionID: Number(req.body.DIM), measurements: DIMS, collection: req.body.PDC};
		console.log(`Preparing to record inspection data for Part ${req.body.partID}, Dimension ${req.body.DIM}`);
		let statefulTxn = contractOrg1.createTransaction('InspectPart');
		// generate transient:
		let tmapData = Buffer.from(JSON.stringify(newDimData));
		statefulTxn.setTransient({
			asset_properties: tmapData
		});

		let result = await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();

		if (result.toString() == "Passed inspection") {
			console.log(`*** Inspection recorded. ***\nResult: ${result.toString()}`.green);
			let msg = `Lot ${req.body.lotID} Dimension ${req.body.DIM} passed inspection.`
			res.render('success',{title: `DIM ${req.body.DIM} Passed Inspection`, message: msg, ORG:ORG});
		} else {
			console.log(`*** Inspection recorded ***\n`.yellow,`Result: ${result.toString()}`.Red);
			let msg = `Lot ${req.body.lotID} failed inspection on Dimension ${req.body.DIM}.`
			res.render('error',{title: `Failed Inspection on DIM ${req.body.DIM}`, message: msg, ORG:ORG});
		}

	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, ORG:ORG});
	}
})


// ship step 2
app.post('/shipping/ship', async (req,res) => {
	console.log('provided data: req.body: ',req.body)
	try {
		// submit transaction
		let shipInfo= { lotID: req.body.LN, destinationOrg: req.body.DEST, collection: req.body.PDC};
		console.log(`Preparing to record shipping information for Lot ${req.body.LN}`);
		let statefulTxn = contractOrg1.createTransaction('ShipParts');
		// generate transient:
		let tmapData = Buffer.from(JSON.stringify(shipInfo));
		statefulTxn.setTransient({
			asset_properties: tmapData
		});

		await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
		let msg = `Lot ${req.body.LN} is now enroute from ${ORG} to ${req.body.DEST}.`
		res.render('success',{title: 'Shipped Successfully', message: msg, ORG:ORG});
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, ORG:ORG});
	}
})

// receive step 2
app.post('/shipping/receive',async (req,res) => {
	console.log('provided data: req.body: ',req.body)
	try {


		// submit transaction
		let receiveInfo= { lotID: req.body.LN, quantity: Number(req.body.QTY_received), collection: req.body.PDC};
		console.log(`Preparing to receive shipment of ${req.body.QTY} parts from Lot ${req.body.LN}`);
		let statefulTxn = contractOrg1.createTransaction('ReceiveParts');
		// generate transient:
		let tmapData = Buffer.from(JSON.stringify(receiveInfo));
		statefulTxn.setTransient({
			asset_properties: tmapData
		});

		await statefulTxn.setEndorsingPeers([endorsingPeer]).submit();
		let msg = `Lot ${req.body.LN} was successfully received at ${ORG}.`
		res.render('success',{title: 'Received Successfully', message: msg, ORG:ORG});
	} catch (err) {
		console.log('catch activated')
		let msg = s.failureCallback(err);
		res.render('error',{title: 'Error', message: msg, ORG:ORG});
	}

})


// default route if page does not exist:
//(ALWAYS Keep this as the last route)
app.get('*', function(req, res){
	//res.status(404).send('This page does not exist.');
	let msg = 'This page does not exist.'
	res.render('error',{title: '404', message: msg, ORG:ORG});
});




// helper function 
async function getQR (text) {
	try {
		return await qr.toDataURL(text,{errorCorrectionLevel: 'H', width: 250, margin: 1});
	} catch (err) {
		console.log('error catch activated in getQR function')
		throw err
	}
}

function checkIfObjectIsEmpty(obj) {
	if (Object.keys(obj).length === 0 && obj.constructor === Object) {
		return true
	} else {
		return false
	} 
}


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
//async function setup() {
//	// build an in memory object with the network configuration (also known as a connection profile)
//	const ccp = buildCCPOrg1();
//
//	// build an instance of the fabric ca services client based on
//	// the information in the network configuration
//	const caClient = buildCAClient(FabricCAServices, ccp, `ca.${org1Address}`);
//
//	// setup the wallet to hold the credentials of the application user
//	const wallet = await buildWallet(Wallets, walletPath);
//
//	// in a real application this would be done on an administrative flow, and only once
//	await enrollAdmin(caClient, wallet, mspOrg1);
//
//	// in a real application this would be done only when a new user was required to be added
//	// and would be part of an administrative flow
//	await registerAndEnrollUser(caClient, wallet, mspOrg1, org1UserId, affiliation);
//}
async function gateway() {
	// Create a new gateway instance for interacting with the fabric network.
	// In a real application this would be done as the backend server session is setup for
	// a user that has been verified.
	try {
		gatewayOrg1 = await initContractFromOrg1Identity();
		const networkOrg1 = await gatewayOrg1.getNetwork(channelName);
		contractOrg1 = networkOrg1.getContract(chaincodeName);
		//const systemContract = networkOrg1.getContract('qscc');
		contractOrg1.addDiscoveryInterest({ name: chaincodeName, collectionNames: availableCollections });
		//NOTE: this assumes that each org only has 1 endorsing peer! In practice, this should not be the case
		endorsingPeer = networkOrg1.getChannel().getEndorsers(mspOrg1)[0];
		//endorsingPeer = networkOrg1.getChannel().getEndorser(`peer0.${org1Address}:7051`); //same as above
		//NOTE2: consider expanding this to use the getEndorsers(mspOrg1) which would give an array of all endorsing peers in this org - then pick (randomly?) from these for each session
		//console.log("Endorsing peer set to: " + endorsingPeer)
	} catch (err) {
		s.failureCallback(err);
	}
	//console.clear() //TODO: remove all the text printed to the screen by this function
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


	} catch (err) {
		console.log('Error detected:\n'.red+ err)
	}
}
// Main workflow
async function main() {
	try {
		try {
			await getCollectionName() // populate availableCollections array
		} catch (err) {
			console.error('failed to get collection name: '.red+err)
		}
		try {
			await gateway()
		} catch (err) {
			console.log('Error detected at main, starting gateway:\n'.red + err)
		}

		try {
			app.listen(port, () => {
				console.log(`Example app listening at http://localhost:${port}`);
			});
		} catch (err) {
			console.error('******** FAILED to run the application: '.red+err);
		}

	} catch (err) {
		s.failureCallback(err);
	}
}

main();

