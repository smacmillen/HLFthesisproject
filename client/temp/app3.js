'use strict';

require('colors');

const cliSelect = require('cli-select');

function failureCallback(){
	console.log('error')
}


function partAndOrderMenu(response){
	console.log('Part & Order Menu')
	//console.log('selected ' +response.id + ': ' + response.value);
	switch (response.id) {
		case 0: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIaddPart')
			mainMenu();
			break;
		}
		case 1: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIaddOrder')
			mainMenu();
			break;
		}
		case 2: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIreviewOrders')
			mainMenu();
			break;
		}
		case 3: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('Returning to Main Menu');
			mainMenu();
			break;
		}
	}
}
function manufacturingMenu(response){
	console.log('Manufacturing & Inspection Menu')
	//console.log('selected ' +response.id + ': ' + response.value);
	switch (response.id) {
		case 0: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UImakeparts')
			mainMenu();
			break;
		}
		case 1: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIinspectParts')
			mainMenu();
			break;
		}
		case 2: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('Returning to Main Menu');
			mainMenu();
			break;
		}
	}
}
function shippingAndReceivingMenu(response){
	console.log('Shipping & Receiving Menu')
	//console.log('selected ' +response.id + ': ' + response.value);
	switch (response.id) {
		case 0: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIship')
			mainMenu();
			break;
		}
		case 1: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIreceive')
			mainMenu();
			break;
		}
		case 2: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('Returning to Main Menu');
			mainMenu();
			break;
		}
	}
}
function queryMenu(response){
	console.log('Query Menu')
	//console.log('selected ' +response.id + ': ' + response.value);
	switch (response.id) {
		case 0: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIqueryPart')
			mainMenu();
			break;
		}
		case 1: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIqueryOrder')
			mainMenu();
			break;
		}
		case 2: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIqueryLotRecord')
			mainMenu();
			break;
		}
		case 3: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('Returning to Main Menu');
			mainMenu();
			break;
		}
	}
}
function traceMenu(response){
	console.log('Tracing Menu')
	//console.log('selected ' +response.id + ': ' + response.value);
	switch (response.id) {
		case 0: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIgetLotGenealogyChannel')
			mainMenu();
			break;
		}
		case 1: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIbuildPartFamilyTree')
			mainMenu();
			break;
		}
		case 2: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIgetRecordPublicHistory')
			mainMenu();
			break;
		}
		case 3: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIqueryLotWhereUsedPrivate')
			mainMenu();
			break;
		}
		case 4: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIqueryLotWhereUsedPublic')
			mainMenu();
			break;
		}
		case 5: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('Returning to Main Menu');
			mainMenu();
			break;
		}
	}
}
function adminMenu(response){
	console.log('Admin Menu')
	//console.log('selected ' +response.id + ': ' + response.value);
	switch (response.id) {
		case 0: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function resetApp')
			mainMenu();
			break;
		}
		case 1: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function setup')
			mainMenu();
			break;
		}
		case 2: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('calling function UIdeleteAsset')
			mainMenu();
			break;
		}
		case 3: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('Returning to Main Menu');
			mainMenu();
			break;
		}
	}
}

function subMenu(response){
	console.log('submenu1')
	//console.log('selected ' +response.id + ': ' + response.value);
	switch (response.id) {
		case 0: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('What would you like to do?')
			cliSelect({
				values: [
					'Add Part', 
					'Add Order', 
					'Review Orders',
					'Return to Main Menu',
				],
				valueRenderer: (value, selected) => {
					if (selected) {
						return (value.bgBlue);
					}
					return value;
				},
			}).then((response) => {
				partAndOrderMenu(response)
			}).catch(() => {
				failureCallback()
			})

			break;
		}
		case 1: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('What would you like to do?')
			cliSelect({
				values: [
					'Manufacture Parts', 
					'Inspect Parts',
					'Return to Main Menu',
				],
				valueRenderer: (value, selected) => {
					if (selected) {
						return (value.bgBlue);
					}
					return value;
				},
			}).then((response) => {
				manufacturingMenu(response)
			}).catch(() => {
				failureCallback()
			})

			break;
		}
		case 2: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('What would you like to do?')
			cliSelect({
				values: [
					'Ship parts', 
					'Receive Parts',
					'Return to Main Menu',
				],
				valueRenderer: (value, selected) => {
					if (selected) {
						return (value.bgBlue);
					}
					return value;
				},
			}).then((response) => {
				shippingAndReceivingMenu(response)
			}).catch(() => {
				failureCallback()
			})

			break;
		}
		case 3: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('What would you like to do?')
			cliSelect({
				values: [
					'query parts', 
					'query order',
					'query lot record',
					'Return to Main Menu',
				],
				valueRenderer: (value, selected) => {
					if (selected) {
						return (value.bgBlue);
					}
					return value;
				},
			}).then((response) => {
				queryMenu(response)
			}).catch(() => {
				failureCallback()
			})

			break;
		}
		case 4: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('What would you like to do?')
			cliSelect({
				values: [
					'Full Lot Trace', 
					'Build Part Family Tree',
					'Get Public History of Asset',
					'Find where Lot is Used (in Private Collection)',
					'Find where Lot is Used (in Supply Chain Network)',
					'Return to Main Menu',
				],
				valueRenderer: (value, selected) => {
					if (selected) {
						return (value.bgBlue);
					}
					return value;
				},
			}).then((response) => {
				traceMenu(response)
			}).catch(() => {
				failureCallback()
			})

			break;
		}
		case 5: {
			console.log('selected ' +response.id + ': ' + response.value);
			console.log('What would you like to do?')
			cliSelect({
				values: [
					'reset app', 
					're-run app setup',
					'delete asset',
					'Return to Main Menu',
				],
				valueRenderer: (value, selected) => {
					if (selected) {
						return (value.bgBlue);
					}
					return value;
				},
			}).then((response) => {
				adminMenu(response)
			}).catch(() => {
				failureCallback()
			})


			break;
		}
		case 6: {
			console.log('Exiting App')
			return;
		}
	}
}
function mainMenu() {
	console.log('What would you like to do?'.blue)
	cliSelect({
		values: [
			'Part & Order Setup', 
			'Manufacturing & Inspection', 
			'Shipping & Receiving',
			'Query',
			'Trace',
			'Admin',
			'exit',
		],
		valueRenderer: (value, selected) => {
			if (selected) {
				return (value.bgBlue);
			}

			return value;
		},
		//}).then(subMenu,failureCallback);
	}).then((response) => {
		subMenu(response)
	}).catch(() => {
		failureCallback()
	})
}
function main() {
	mainMenu();
}


main()
