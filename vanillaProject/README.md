
backup before temporarily modifying app.js to use API-like commands for project (6.2) section
---

Quick backup before removing section of chaincode from manufacturing function for subcomponent validation (works in most cases, but fails if multi-collection scenarion since cannot know if lot exists on other collection)

--
Stability Improvements
--
In process of building new menu structure
---------------------------------------------------------------------------
- applied fix to 'submit', not just 'evaluate' transactions
---
- changed fix from using 'err.toString().indexOf' to using 'err.toString().includes' as the former was not being evaluated
---
- tested a possible solution to detect gRPC error, reset network, and resubmit query/action.
- applied fix to all outward facing "evaluate" commands in node app
---------------------------------------------------------------------------
- Sadly, I encountered the error again, so I don't know what else can cause it.  
- As a result, I tweaked the docker shell script to auto-restart on Ctrl+c close (exit code 130) for faster reboot
- added 'review orders' function to app


---
- added a restart function to the node app and updated the docker startup bash script to restart on exit code 5 (corresponding to the node restart function) and not restart otherwise.
---
MAJOR improvement: discovered the source of the gRPC errors!!  During the app startup, if I entered '0' and then hit enter before the program was ready for input then it would accept the input (including a carrage return).  However, this would result in a bad input to select the collection resulting in a collection of 'undefined'.  Then, any attempt to use the collection would result in the gRPC error.  Restarting the program "fixed" it because I usually didn't make the same mistake two times in a row.

I corrected this by testing the input against the collection array and rejecting the input if the array[input] was undefined.  This was both simplier than the previous validation used, but also covered more possible bad inputs (including the one described above!)

---
- corrected error checking (converted string to number for check)
---
- added error checking for part add LCL, Target on app

---------------------------------------------------------------------------
- added "delete asset" function to app & chaincode

---------------------------------------------------------------------------
- fixed app genealogy function
TODO: create chaincode function to edit parts/orders

-----

- got a quality check function in chaincode WORKING!!
- added to make, ship, receive functions. (unsure if should add to inspect function??)
- added check on add order to ensure that supplier is member of collection!
NOTE: this should also be done when adding part, however, not possible, since supplier is not entered for new part

-----
- added "restart" function to restart JS script (implemented through bash script)
- added error handling to JS script to notify user if no records were found in range queries
- updated chaincode to record lot ID in channel (PublicAsset)
- updated chaincode to add quality status to lot ID in channel (PublicAsset)

-----
App updates:
- modified query Part to query channel to find other collection name if unable to find part in current collection
- added correct error handling for query entries (part/order/lot)
- applied above modifications to part/order/lot functions

TODO: update chaincode to add quality check for lot IDs prior to make, inspect, ship, receive


--------------------------------------------------------------
#TODO: move app startup actions to separate function
#TODO: create record history functions (app+chaincode)

-------------------------------
Successfully migrated OEM server from IOZoom to Hawkhost VPS, reinstalled & brought up network

added error-checking for bad lot on app.js geneology function

added additional error-checking to ensure that part/order/lot lookups only receive matching result type

-------------------------------

QR function finished
----
#TODO: add timeout for server calls to detect broken gprc issue, (maybe not possible for async call?)
			+ restart on timeout

working on setting up QR function - needed to mount directory to use inside dockerized container
---
Chaincode:
- merged PublicRecord into PublicAsset

#TODO: enabled network-wide quarantine?
#TODO: migrate genealogy function from collection to channel-based query

---------------------------------------------------------------------------------------------------------------------
I think it's working!
-------
work in progress: recursive trace function for listing all affected lot numbers 
------

App Changes:
- applied fix (see last post) to all write-functions
- fixed makeParts function to allow for input of subcomponent lot numbers
Chaincode Changes:
- AddPart: check for duplicates in public, not private collection
- AddPart: use date+time for createDate
- fixed issue with updating of parent part in public channel: changed function "ReadPart" to "ReadAsset", deleted "ReadOrder"

Both:
- created "trace" function to lookup all lots containing lot number
TODO: make trace function recursive and build "genealogy" structure showing relationships

#TODO: addOrder: lookup supplier to see if part of collection (has to be done in app, since chaincode cannot see supplier)
#TODO: chaincode: add inventory query (to see all parts at given location)
#TODO: create QR code on manufacturing operation
#TODO: setup multi-layer menu in app (for listing functions)

------------------------------------------------------------------------------------------------------------------
Tested a working solution for the docker client peer selection issue during write transactions:
Modified node client to use specific endorsing peer node when submitting transactions
Tested fix on addpart function, result=success
Next, need to apply fix to all other write functions
----
Additionally, need to update docker image on docker hub
+
Test Non-Docker client with same fix to see if can remove discovery (and thus eliminate the startup errors on that client)

-------------------
tempoary Workaround setup: a non-dockerized client app was re-installed at $HOME which uses an alternate network config

----
4-org setup works!

Currently experiencing an issue running the dockerized client app when writing to shared private collections:

--> Submit Transaction: AddPart A2
2021-03-24T23:18:55.339Z - error: [Transaction]: Error: No valid responses from any peers. Errors:
    peer=peer0.oem.scm.com:7051, status=500, message=AddPart cannot be performed: Error client from org S21MSP is not authorized to read or write private data from an org OEMMSP peer
		Error detected when calling addPart function:Error: No valid responses from any peers. Errors:
		    peer=peer0.oem.scm.com:7051, status=500, message=AddPart cannot be performed: Error client from org S21MSP is not authorized to read or write private data from an org OEMMSP peer


----
Current project files: working setup to start 3-org network:
1) First start bootstrapHost.sh on Org1 and Org2 and follow directions
2) Next start outsideOrg.sh on Org3 and follow directions

Next: test 4-org setup

------------------------------------------------------------------------------------------------------
started Dockerizing the client node.js app to try to remove errors on startup.  Succeeded in dockerizing it.  However, it is unable to connect to addresses on localhost.  Recommend replacing localhost addresses with specific org addresses (e.g. peer0.s11.scm.com) across all files, starting with ccp-templates.json/yaml.  This may be a large undertaking, though, so it is tabled for now.  Current focus shifted to bringing up network on all four servers.
-------------------

- rewrite collections file to use static file customized for 4 orgs and copy across network (no more templates or regex)
----
Successfully onboarded an orderer organization!
The problem that I had was that I was using the wrong MSPID and MSPDIR for the signatures.  I was using
peer MSPID/DIR.  I needed to use the orderer MSPID and orderer Admin user MSPDIR to get it to work.

Works:
- onboard peer
- update peer anchor
- onboard orderer

Next: need to get chaincode installed and working across all orgs.  Want to re-write the SIG_POLICY and COLLECTION sections
- auto generate these based on number of orgs in-use (setup in utils.sh file with rewrite)

------------------------------------------------------------------------------------------------------

backup before major rewrite of utils.sh file

plan to rewrite as follows:

Org1=
Org2=
Org3=
Org4=
(OrgX=)

MasterOrg=Org1 (can be set)
CurrentOrg=(based on machine)
-
Number of orgs=3 (?)

----------------------------------------------------------------------------------------------------
Current project: create on-boarding process for new orgs:
- fetchConfig function created


--
Going to shelve the client app issue for now - it may be due to the connection profile
----------------------------------------------------------------------------------------------------
System is operational again, although client app errors remain (still able to use, with reliability issues).
Looking at this post for possible help: https://stackoverflow.com/questions/63995545/debugging-tls-handshake-failure
--------
Note: system is not currently functional - below update broke it - suspected TLS issue
Major overhall of bootstrap script: migrate away from dependency on fabric-samples files (except binaries): create basic templates of required files and replace values as required
----------------------------------------------------------------------------------------------------

Fixed bug in collection selector function
--------
Added function to client app which automatically selects collection name (or prompts if more than one) based on collection config file and org memberships.
--------
- added error-checking/wait time for copying collection file
- removed redundant functions
--------
- setup Collections-config file to auto-generate and disseminate based on, to starting orgs
- added check for required binaries (including new 'jq')
-------------------------
- added error checking for client app numeric input (dimension values)
- various bug fixes to app.js, chaincode.go
- added function to search for all orders, parts

--------
Major changes to chaincode (Go), client application (node.js):
- require collection name to be passed in most functions
(previously this was hardcoded into functions)
- save data to either channel or collection
(previously saved to either of 2 collections, with most data being saved to collection visible to single-org only)
- fixed Org name trimming (changed strings.Trim to strings.TrimSuffix to avoid overtrimming)

------------------------------------------------------------------------------------------------------------------
- Docker config network settings have been modified to use only one (docker swarm) network
- In latest test, S41 client app gave error on first run.  On second run, no error, executed 'add part' function successfully

TODO: modify chaincode to take collection name as argument, not try to guess it - this will allow for more flexibility (and may be necessary with multi-user collections)

- Currently data submitted through client program is being saved in separate databases (collections) - need to fix via above note.

--------
Currently working to get the node.js client application working (projectDir/app)

- I was able to successfully start up the JS app on org S41!  I tried to add a part, but when I submitted my transaction, I got an error:
error starting container: API error (500): Could not attach to network internal-network: rpc error: code = NotFound desc = network internal-network not founda

I am going to try to remove the internal network and just use a single, unified swarm network for all containers to see if this fixes the issue

------
npm install << install all dependencies for a package
#To fix some errors with the app, I had to refresh the node project dependencies.  I tried:
rm -rf node_modules/
npm install
#This didn't work, so I did:
rm -rf node_modules/
npm update 
#which took care of the error message
------

One note: getting the fabric commands to execute properly inside the docker container required the right environment variables to be provided.  I did this by modifying the docker-compose file as well as manually passing variables when I called the command.  Lastly, I put the commit command in a script which I linked (as a volume) into the container (also via the compose file) and then executed through a command.
------
Chaincode commit error fixed! to resolve the address lookup failure, I exec'd into the docker container, where the address would resolve.
The bootstrap script now works: from setting up the network to installing and committing chaincode!


------------------------------------------------------------------------------------------------------------

One possible problem solved?  To address differing views of org approvals, tried 2 things:
- used same collections config file between both orgs
- changed signature policy to list orgs in the same order for each peer (previous sequence was own peer, then other peer)

After making these two changes, I got a "true" approval for each organization
However, the commit still failed with an endorsement policy failure error.

I am going to try to edit the collections config file to remove the private-org collections to see if that will help
=> result: did not make a difference, still get endorsement policy failure.
Next, I am going to see if the approval functions are using the incorrect certs (admin, not peer) to approve
-> temporary ignore this idea

I am focusing on the construction of the 'commit' command to see if it is missing required arguments.  Based on the official example, it should include the peer addresses of both orgs.  If TLS is enabled, I also need to pass these certs in.

I am getting this error when I use the full peer address:
Error: failed to retrieve endorser client for commit: endorser client failed to connect to peer0.oem.scm.com:7051: failed to create new connection: connection error: desc = "transport: error while dialing: dial tcp: lookup peer0.oem.scm.com on 8.8.8.8:53: no such host"
However, I cannot switch to "localhost" because both orgs use the same port, so there would be a conflict.



------------------------------------------------------------------------------------------------------------
Problem discovered: during chaincode packaging, the previous chaincode package was being included in the new package
new chaincode package location should NOT be the same as where any previous chaincode packages are saved
OR all previous chaincode packages should be purged before creating...
==> fixed (separated location of chaincode source and packages)

------------------

- Peer crashing re-appeared... :(

Looking into correct ports being open:

OEM:
nc -z -v 198.252.99.103 2376
Connection refused
nc -z -v 198.252.99.103 2377
Succeeded!


-------------------
- Peer crashing seems to be fixed by upgrading each VPS host to 2GB of RAM (from 1GB of RAM each)

- Still having problem with conflicting org approvals.

Things I can try:
1) use same collections document for both peers (generate on one peer and send via rsync to the other)
2) write function to export environment variables needed and call within each CC function:
	***reference**
	export CORE_PEER_LOCALMSPID="Org2MSP"
	export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
	export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/ms    p 
	export CORE_PEER_ADDRESS=localhost:9051
	export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

-----------------------------------------------------------------------------------------------------------------------
peer crashing issue still occuring.

Tried editing config/core.yaml settings:

	changed:
	peer.gossip.dialTimeout from 3s to 6s
	peer.gossip.connTimeout from 2s to 5s

---------
Able to get CC  install function working on peer Wei after running:

CC_PATH$: go mod tidy
CC_PATH$: go mod vendor
CC_PATH$: go build

Current, remaining problem: after both orgs (S11 and S21) approve chaincode successfully,
checkcommitreadiness shows conflicting values when called from each peer:

S21 Org:
"approvals": {
	"S11MSP": false,
	"S21MSP": true
}
S11 ORG:
"approvals": {
	"S11MSP": true,
	"S21MSP": false
}


----------

peer wei (master org) quits unexpectedly at install CC function
other peer does not quit

previous versions believed to work at this step (however, problem may not have been exposed before if I did not get far enough )
