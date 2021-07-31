// This program watches a folder for new files, 
// On detecting a new file, it generates and prints a QR code containing the filename to the terminal
//
// Written by Simeon MacMillen
// 2021-4-13
// Portions of code from https://stackoverflow.com/a/60650839

'use strict';

const clientName = 'client'
const homedir = require('os').homedir();
const fs = require("fs");
const path = require('path');
const QRCode = require('qrcode')
const QRpath = path.join(homedir, clientName, 'QRcodes');

const getMostRecentFile = (dir) => {
    const files = orderReccentFiles(dir);
    return files.length ? files[0].file : undefined;
};

const orderReccentFiles = (dir) => {
    return fs.readdirSync(dir)
        .filter(file => fs.lstatSync(path.join(dir, file)).isFile())
        .map(file => ({ file, mtime: fs.lstatSync(path.join(dir, file)).mtime }))
        .sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
};


async function generateQRcode(text) {
  try {
    console.log(await QRCode.toString(text,{type:'terminal',errorCorrectionLevel:'H'}))
  } catch (err) {
    console.error(err)
  }
}
// watch folder for changes; on change, print out new QR code
async function main() {

	// ensure that directory exists
	if (!fs.existsSync(QRpath)) {
		console.log("QR directory is missing. Please create this directory and re-run this program.")
		console.log("Expected location of QR directory: ", QRpath)
		return;
		//fs.mkdir(QRpath); //Create dir in case not found
	}

	let NewestFileName=getMostRecentFile(QRpath);
	if (typeof(NewestFileName) == 'undefined') {
		console.log("Waiting for lots")
	} else {
		console.log("Latest Lot ID: ",NewestFileName)
		await generateQRcode(NewestFileName);
	}
	while (NewestFileName == NewestFileName) {  //infinite loop
		let UpdateLastFileName=getMostRecentFile(QRpath);
		if (NewestFileName != UpdateLastFileName) {
			console.log("Update Received")
			NewestFileName=UpdateLastFileName;
			console.log("Lot ID: ",NewestFileName)
			await generateQRcode(NewestFileName);
		}
		await new Promise(r => setTimeout(r, 1000));
	}
}

main();
