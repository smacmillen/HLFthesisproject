#!/bin/bash
# A simple script to facilitate copying project files from one server to another
RED='\033[0;31m'
NC='\033[0m'
function errorCheck() {
	if [ "$?" -ne 0  ]; then
		echo -e "${RED}ERROR${NC} detected. Script could not be completed.  Please review and try again.${NC}"
		exit 1
	fi
}

#----------variables for script--------------:

# Source Org information:  (Copy from here)
ORG=OEM
uname=mina
org=${ORG,,} #lowercase version
ProjectName=vanillaProject
appName=client
# destination org information: (Copy to here)
# not required as long as this script is run on the destination org


function all(){
	echo "Deleting all files in this directory:"
	read -n 1 -s -r -p "$(echo -e 'When ready, press any key to continue: \n\b')" && echo ""
	sudo rm -rf *

	echo "Deleting the client wallet"
	sudo rm -rf $home/$appName/wallet

	#define files/directories to exclude:
	echo -e "$ProjectName/organizations/\n$ProjectName/genesis_block.pb\n$ProjectName/CC/scm/source/vendor\n$ProjectName/CC/scm/pkg/*\n$ProjectName/logs\nQRprinter/node_modules\n">exclude.list
	#echo -e "$ProjectName/CC/scm/source/vendor\n$ProjectName/CC/scm/pkg/*\n">exclude.list
	errorCheck

	echo "Copying system files from ${uname} server:"
	rsync -r -P --exclude-from='exclude.list' ${uname}@${org}.scm.cloudns.asia:~/{$ProjectName,$appName/app.js,$appName/package*,$appName/utils,$appName/dockerClient.sh,QRprinter} $HOME
	#rsync -r -P --exclude-from='exclude.list' ${uname}@${org}.scm.cloudns.asia:~/{$ProjectName/files,$ProjectName/CC,$ProjectName/*.sh,$appName/app.js,$appName/package*,$appName/utils} $HOME
	errorCheck

	echo "Moving app files into app directory:"
	mkdir -p $HOME/$appName #make directory if it does not already exist
	cp -r $HOME/{app.js,package*,utils,dockerClient.sh} $HOME/$appName/
	errorCheck
	echo "Cleaning up files after successful copy"
	rm -r $HOME/{app.js,package*,utils,dockerClient.sh,$ProjectName/exclude.list}
	errorCheck

	echo "Removing any old chaincode packages and wallet artifacts"
	rm -rf $ProjectName/CC/scm/scm* $HOME/client/wallet
	# Modifying utils.sh:
	File=$HOME/$ProjectName/files/scripts/utils.sh
	echo "Disabling OrgMaster setting" 
	sed -i '/OrgMaster="yes"/c\OrgMaster="no"' $File
	errorCheck
	echo "Setting other org name to $ORG" 
	sed -i "/x1name=/c\x1name=$ORG" $File
	errorCheck
	echo "Setting other org username to $uname" 
	sed -i "/x1user=/c\x1user=$uname" $File
	errorCheck
	echo "script completed"
}

function client() {
	#copy only the node.js client
	echo "Copying node.js client from ${uname} server:"
	rsync -r -P ${uname}@${org}.scm.cloudns.asia:~/$appName/{app.js,dockerClient.sh} $HOME/$appName/ 
	errorCheck
	echo "finished copying"
}

function copyScript() {
	#copy only the node.js client
	echo "Copying copy script from ${uname} server:"
	rsync -r -P ${uname}@${org}.scm.cloudns.asia:~/$ProjectName/copyFromMaster.sh $HOME/$ProjectName/copyFromMaster.sh 
	errorCheck
	echo "finished copying"
}

function file() {
	#copy any file
	if [ ! -n "$1" ]; then
		echo "${RED}}ERROR${NC}:missing filename to copy"
		exit
	fi
	echo "Copying $1 from ${uname} server:"
	rsync -r -P ${uname}@${org}.scm.cloudns.asia:~/$ProjectName/$1 ~/$ProjectName/
	errorCheck
	echo "finished copying $1 to $PWD"
}


case $1 in
	all)
		all;;
	client)
		client;;
	copyScript)
		copyScript;;
	file)
		file $2;;
	*)
		echo "incorrect or missing argument"
		exit
esac
