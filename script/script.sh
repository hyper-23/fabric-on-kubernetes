#!/bin/bash

DELAY="3"
TIMEOUT="10"
VERBOSE="false"
COUNTER=1
MAX_RETRY=2

# Peer Setting items.
PEER_MSPID[0]="Org1MSP"
PEER_ADDRESS[0]="fabrc-org1peer1:30110"
PEER_MSPCONFIGPATH[0]="/shared/artifacts/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
PEER_TLS_ROOTCERT_FILE[0]="/shared/artifacts/crypto-config/peerOrganizations/org1.example.com/peers/fabrc-org1peer1/tls/ca.crt"

PEER_MSPID[1]="Org2MSP"
PEER_ADDRESS[1]="fabrc-org2peer1:30210"
PEER_MSPCONFIGPATH[1]="/shared/artifacts/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
PEER_TLS_ROOTCERT_FILE[1]="/shared/artifacts/crypto-config/peerOrganizations/org2.example.com/peers/fabrc-org2peer1/tls/ca.crt"

PEER_MSPID[2]="Org3MSP"
PEER_ADDRESS[2]="fabrc-org3peer1:30310"
PEER_MSPCONFIGPATH[2]="/shared/artifacts/crypto-config/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp"
PEER_TLS_ROOTCERT_FILE[2]="/shared/artifacts/crypto-config/peerOrganizations/org3.example.com/peers/fabrc-org3peer1/tls/ca.crt"

CC_SRC_PATH="${GOPATH}/src/${CHAINCODE_NAME}"
CHAINCODE_SEQUENCE=1
PEER_CONN_PARMS=""

# Peer setting item check.
N=`expr ${#PEER_MSPID[@]} \- 1`
_N1=`expr ${#PEER_ADDRESS[@]} \- 1`
_N2=`expr ${#PEER_MSPCONFIGPATH[@]} \- 1`
_N3=`expr ${#PEER_TLS_ROOTCERT_FILE[@]} \- 1`
if [ ${N} -ne ${_N1} ] || [ ${N} -ne ${_N2} ] || [ ${N} -ne ${_N3} ] || [ ${_N1} -ne ${_N2} ] || [ ${_N1} -ne ${_N3} ] || [ ${_N2} -ne ${_N3} ]; then
  echo "Peer information is missing."
  exit 1
fi

# Setting infomation.
echo "=== Orderer ==="
echo "ORDERER_URL	: ${ORDERER_URL}"
echo "ORDERER_CA	: ${ORDERER_CA}"
echo 

echo "=== Peer ==="
for i in `seq 0 $N`
do
	echo "CORE_PEER_LOCALMSPID	: ${PEER_MSPID[i]}"
	echo "CORE_PEER_ADDRESS	: ${PEER_ADDRESS[i]}"
	echo "CORE_PEER_MSPCONFIGPATH	: ${PEER_MSPCONFIGPATH[i]}"
	echo "CORE_PEER_TLS_ROOTCERT_FILE : ${PEER_TLS_ROOTCERT_FILE}"
	echo 
done

echo "=== Channel ==="
echo "CHANNEL_NAME	: ${CHANNEL_NAME}"
echo 

echo "=== Chaincode ==="
echo "CHAINCODE_NAME	: ${CHAINCODE_NAME}"
echo "CHAINCODE_VERSION	: ${CHAINCODE_VERSION}"
echo "CHAINCODE_SEQUENCE	: ${CHAINCODE_SEQUENCE}"
echo "CC_SRC_PATH	: ${CC_SRC_PATH}"
echo 

createChannel() {
	CORE_PEER_LOCALMSPID=${PEER_MSPID[0]}
	CORE_PEER_ADDRESS=${PEER_ADDRESS[0]}
	CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[0]}
	echo "===================== Creating channel ===================== "
	local rc=1
	local COUNTER=1
	## Poll in case the raft leader is not set yet
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
		peer channel create -o ${ORDERER_URL} -c ${CHANNEL_NAME} -f /shared/artifacts/config/${CHANNEL_NAME}.tx --outputBlock /shared/artifacts/config/${CHANNEL_NAME}.block --tls --cafile ${ORDERER_CA} >&log.txt
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
  	verifyResult $res "Channel creation failed"
	echo "===================== Channel '$CHANNEL_NAME' created ===================== "
	echo 
}

joinChannel () {
	for i in `seq 0 $N`
	do
		CORE_PEER_LOCALMSPID=${PEER_MSPID[i]}
		CORE_PEER_ADDRESS=${PEER_ADDRESS[i]}
		CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[i]}
		CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[i]}
		echo "===================== ${PEER_ADDRESS[i]} joining channel ===================== "
		local rc=1
		local COUNTER=1
		## Sometimes Join takes time, hence retry
		while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
			sleep $DELAY
			set -x
			peer channel join -b /shared/artifacts/config/${CHANNEL_NAME}.block -o ${ORDERER_URL} >&log.txt
			res=$?
			set +x
			let rc=$res
			COUNTER=$(expr $COUNTER + 1)
		done
		cat log.txt
		echo
		verifyResult $res "After $MAX_RETRY attempts, ${PEER_ADDRESS[i]} has failed to join channel '$CHANNEL_NAME' "
		echo "===================== Channel joined  ${PEER_ADDRESS[i]} ===================== "
		echo 
	done
}

updateAnchorPeers() {
	for i in `seq 0 $N`
	do
		echo "===================== ${PEER_ADDRESS[i]} updating anchor ===================== "
		CORE_PEER_LOCALMSPID=${PEER_MSPID[i]}
		CORE_PEER_ADDRESS=${PEER_ADDRESS[i]}
		CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[i]}
		CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[i]}
		local rc=1
		local COUNTER=1
		## Sometimes Join takes time, hence retry
		while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
			sleep $DELAY
			set -x
			peer channel update -o ${ORDERER_URL} -c ${CHANNEL_NAME} -f /shared/artifacts/config/${CORE_PEER_LOCALMSPID}anchors.tx --tls ${CORE_PEER_TLS_ENABLED} --cafile ${ORDERER_CA} >&log.txt
			res=$?
			set +x
			let rc=$res
			COUNTER=$(expr $COUNTER + 1)
		done
		cat log.txt
		verifyResult $res "Anchor peer update failed"
		echo "===================== Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME' ===================== "
		echo
	done
  sleep $DELAY
  echo
}

packageChaincode() {
		cp -r /shared/artifacts/chaincode/${CHAINCODE_NAME} ${GOPATH}/src/
		cd ${CC_SRC_PATH}
		GO111MODULE=on go mod vendor
		cd ${GOPATH}

		CORE_PEER_LOCALMSPID=${PEER_MSPID[0]}
		CORE_PEER_ADDRESS=${PEER_ADDRESS[0]}
		CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[0]}
		CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[0]}
		echo "===================== Creating chaincode package ===================== "
		local rc=1
		local COUNTER=1
		## Sometimes Join takes time, hence retry
		while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
			sleep $DELAY
			set -x
			peer lifecycle chaincode package ${CHAINCODE_NAME}.tar.gz --path ${CC_SRC_PATH} --lang golang --label ${CHAINCODE_NAME}_${CHAINCODE_VERSION} >&log.txt
			res=$?
			set +x
			let rc=$res
			COUNTER=$(expr $COUNTER + 1)
		done
		cat log.txt
		verifyResult $res " Package failed chaincode"
		echo "===================== Chaincode packaged ===================== "
		echo
}

installChaincode() {
	for i in `seq 0 $N`
	do
		echo "===================== ${PEER_ADDRESS[i]} install chaincode ===================== "
		CORE_PEER_LOCALMSPID=${PEER_MSPID[i]}
		CORE_PEER_ADDRESS=${PEER_ADDRESS[i]}
		CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[i]}
		CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[i]}
		echo "===================== ${PEER_ADDRESS[i]} installing chaincode ===================== "
		local rc=1
		local COUNTER=1
		## Sometimes Join takes time, hence retry
		while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
			sleep $DELAY
			set -x
			peer lifecycle chaincode install ${CHAINCODE_NAME}.tar.gz >&log.txt
			res=$?
			set +x
			let rc=$res
			COUNTER=$(expr $COUNTER + 1)
		done
		cat log.txt
		verifyResult $res " peer install failed chaincode"
		echo "===================== ${PEER_ADDRESS[i]} chaincode installed ===================== "
		echo
	done
}

queryPackage() {
		CORE_PEER_LOCALMSPID=${PEER_MSPID[0]}
		CORE_PEER_ADDRESS=${PEER_ADDRESS[0]}
		CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[0]}
		CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[0]}
		echo "===================== Query chaincode package ID ===================== "
		peer lifecycle chaincode queryinstalled >&log.txt
		export PACKAGE_ID=`sed -n '/Package/{s/^Package ID: //; s/, Label:.*$//; p;}' log.txt`
		echo "packgeID=$PACKAGE_ID"
		echo "===================== Query successfull  ===================== "
		echo
}

approveChaincode() {
	for i in `seq 0 $N`
	do
		echo "===================== ${PEER_ADDRESS[i]} approving chaincode ===================== "
		CORE_PEER_LOCALMSPID=${PEER_MSPID[i]}
		CORE_PEER_ADDRESS=${PEER_ADDRESS[i]}
		CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[i]}
		CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[i]}
		echo "===================== Approving chaincode definition for ${PEER_ADDRESS[i]} ===================== "
		sleep $DELAY
		set -x
		peer lifecycle chaincode approveformyorg -o ${ORDERER_URL} --tls ${CORE_PEER_TLS_ENABLED} --cafile ${ORDERER_CA} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} --version ${CHAINCODE_VERSION} --init-required --package-id $PACKAGE_ID --sequence ${CHAINCODE_SEQUENCE} >&log.txt
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
		cat log.txt
		verifyResult $res " peer approve failed chaincode"
        echo "===================== Chaincode definition approved on org1peer1 on channel ${CHANNEL_NAME} =====================";
		echo
	done
}

checkCommitReadiness() {
	for i in `seq 0 $N`
	do
		echo "===================== ${PEER_ADDRESS[i]} check commit readiness ===================== "
		CORE_PEER_LOCALMSPID=${PEER_MSPID[i]}
		CORE_PEER_ADDRESS=${PEER_ADDRESS[i]}
		CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[i]}
		CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[i]}
		echo "===================== Checking the commit readiness of the chaincode definition on ${PEER_ADDRESS[i]} on channel '$CHANNEL_NAME'... ===================== "
		local rc=1
		local COUNTER=1
		# continue to poll
  		# we either get a successful response, or reach MAX RETRY
		while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
			sleep $DELAY
			echo "Attempting to check the commit readiness of the chaincode definition on ${PEER_ADDRESS[i]}, Retry after $DELAY seconds."
			set -x
    		peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name ${CHAINCODE_NAME} --version ${CHAINCODE_VERSION} --sequence ${CHAINCODE_SEQUENCE} --output json --init-required >&log.txt
			res=$?
			set +x
			let rc=0
			grep "$CORE_PEER_LOCALMSPID" log.txt &>/dev/null || let rc=1
			COUNTER=$(expr $COUNTER + 1)
		done
		cat log.txt
		if test $rc -eq 0; then
			echo "===================== Checking the commit readiness of the chaincode definition successful on ${PEER_ADDRESS[i]} on channel '$CHANNEL_NAME' ===================== "
			echo
		else
			echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Check commit readiness result on ${PEER_ADDRESS[i]} is INVALID !!!!!!!!!!!!!!!!"
			echo
			exit 1
		fi
	done
}

commitChaincode() {
	echo "===================== ${PEER_ADDRESS[1]} commiting chaincode ===================== "
	CORE_PEER_LOCALMSPID=${PEER_MSPID[1]}
	CORE_PEER_ADDRESS=${PEER_ADDRESS[1]}
	CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[1]}
	CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[1]}
	for i in `seq 0 $N`
	do
		PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses ${PEER_ADDRESS[i]} --tlsRootCertFiles ${PEER_TLS_ROOTCERT_FILE[i]}"
	done
	echo "===================== Commiting chaincode definition to channel ===================== "
	set -x
	peer lifecycle chaincode commit -o ${ORDERER_URL} --tls ${CORE_PEER_TLS_ENABLED} --cafile ${ORDERER_CA} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} ${PEER_CONN_PARMS} --version ${CHAINCODE_VERSION} --sequence ${CHAINCODE_SEQUENCE} --init-required >&log.txt
	res=$?
	set +x
	cat log.txt
	verifyResult $res "Chaincode definition commit failed on ${CORE_PEER_ADDRESS} on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode definition committed on channel '$CHANNEL_NAME' ===================== "
	echo
}

queryCommitted() {
	echo "===================== ${PEER_ADDRESS[0]} committed chaincode check ===================== "
	CORE_PEER_LOCALMSPID=${PEER_MSPID[0]}
	CORE_PEER_ADDRESS=${PEER_ADDRESS[0]}
	CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[0]}
	CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[0]}
  	EXPECTED_RESULT="Version: ${CHAINCODE_VERSION}, Sequence: ${CHAINCODE_SEQUENCE}, Endorsement Plugin: escc, Validation Plugin: vscc"
  	echo "===================== Querying chaincode definition on ${CORE_PEER_ADDRESS} on channel '$CHANNEL_NAME'... ===================== "
	local rc=1
	local COUNTER=1
	# continue to poll
  	# we either get a successful response, or reach MAX RETRY
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		echo "Attempting to Query committed status on ${CORE_PEER_ADDRESS}, Retry after $DELAY seconds."
		set -x
		peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CHAINCODE_NAME} >&log.txt
		res=$?
		set +x
		test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: [0-9], Sequence: [0-9], Endorsement Plugin: escc, Validation Plugin: vscc')
		test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
		COUNTER=$(expr $COUNTER + 1)
	done
	echo
	cat log.txt
	if test $rc -eq 0; then
		echo "===================== Query chaincode definition successful on ${CORE_PEER_ADDRESS} on channel '$CHANNEL_NAME' ===================== "
			echo
	else
		echo "!!!!!!!!!!!!!!! After $MAX_RETRY attempts, Query chaincode definition result on ${CORE_PEER_ADDRESS} is INVALID !!!!!!!!!!!!!!!!"
		echo
		exit 1
	fi
}

initChaincode() {
	CORE_PEER_LOCALMSPID=${PEER_MSPID[0]}
	CORE_PEER_ADDRESS=${PEER_ADDRESS[0]}
	CORE_PEER_MSPCONFIGPATH=${PEER_MSPCONFIGPATH[0]}
	CORE_PEER_TLS_ROOTCERT_FILE=${PEER_TLS_ROOTCERT_FILE[0]}
	echo "===================== Invoke transaction ===================== "
	# while 'peer chaincode' command can get the orderer endpoint from the
	# peer (if join was successful), let's supply it directly as we know
	# it using the "-o" option
	set -x
	peer chaincode invoke -o ${ORDERER_URL} --tls ${CORE_PEER_TLS_ENABLED} --cafile ${ORDERER_CA} -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} ${PEER_CONN_PARMS} --isInit -c '{"function":"initLedger","Args":["initLedger"]}' >&log.txt
	res=$?
	set +x
	cat log.txt
	verifyResult $res "Invoke execution on ${PEER_ADDRESS[@]} failed 1"

	set -x	
	sleep 5
	peer chaincode invoke -o ${ORDERER_URL} --tls ${CORE_PEER_TLS_ENABLED} --cafile ${ORDERER_CA} -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} ${PEER_CONN_PARMS} -c '{"Args":["initLedger"]}' >&log.txt
	res=$?
	set +x
	cat log.txt
	verifyResult $res "Invoke execution on ${PEER_ADDRESS[@]} failed 2"
	echo "===================== Invoke transaction successful on ${PEER_ADDRESS[@]} on channel '$CHANNEL_NAME' ===================== "
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo
    exit 1
  fi
}

## Create channel
sleep 1
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers ..."
updateAnchorPeers

# ## Package the chaincode
# echo "packaging chaincode..."
packageChaincode

# ## Query chaincode packageID
# echo "Querying packageID..."
installChaincode

# ## Install chaincode on all peers
echo "Installing chaincode..."
queryPackage

# Approve chaincode definition
echo "Approving chaincode..."
approveChaincode

# Check the commit readiness of the chaincode definition
echo "Checking the commit readiness of the chaincode definition..."
checkCommitReadiness

# Commit chaincode definition
echo "Committing chaincode definition..."
commitChaincode

# Check the commit of the chaincode definition
echo "Checking the commit of the chaincode definition..."
queryCommitted

# Init chaincode
echo "Initialize chaincode..."
initChaincode

echo
echo "========= Fabric TEST network setup completed =========== "
echo

exit 0
