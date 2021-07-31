/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

require('dotenv').config(); // required to use .env environment variable file
const fs = require('fs');
const path = require('path');
const org1Address=process.env.orgAddress;
const org=process.env.org;
const homedir = require('os').homedir();  // get user's home dir
const projectName=process.env.ProjectName;

exports.buildCCPOrg1 = () => {
	// load the common connection configuration file
	const ccpPath = path.resolve(`${homedir}`, `${projectName}`, 'organizations', 'peerOrganizations', `${org1Address}`, `connection-${org}.json`);
	const fileExists = fs.existsSync(ccpPath);
	if (!fileExists) {
		throw new Error(`no such file or directory: ${ccpPath}`);
	}
	const contents = fs.readFileSync(ccpPath, 'utf8');

	// build a JSON object from the file contents
	const ccp = JSON.parse(contents);

	console.log(`Loaded the network configuration located at ${ccpPath}`);
	return ccp;
};

exports.buildWallet = async (Wallets, walletPath) => {
	// Create a new  wallet : Note that wallet is for managing identities.
	let wallet;
	if (walletPath) {
		wallet = await Wallets.newFileSystemWallet(walletPath);
		console.log(`Built a file system wallet at ${walletPath}`);
	} else {
		wallet = await Wallets.newInMemoryWallet();
		console.log('Built an in memory wallet');
	}

	return wallet;
};

exports.prettyJSONString = (inputString) => {
	if (inputString) {
		return JSON.stringify(JSON.parse(inputString), null, 2);
	}
	else {
		return inputString;
	}
}
