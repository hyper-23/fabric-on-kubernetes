#!/bin/sh

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../artifacts
CHANNEL_NAME=channel1

cd ../artifacts

# remove previous crypto material and config transactions
if [ -d ./config ]; then
  rm -fr config/*
else
  mkdir config
fi


# generate genesis block for orderer
echo ""
echo "******************************************"
echo "**  generate genesis block for orderer  **"
echo "******************************************"
#configtxgen -profile ThreeOrgsOrdererGenesis -channelID channel1 -outputBlock ./config/genesis.block
configtxgen -profile ThreeOrgsOrdererGenesis -channelID system-channel -outputBlock ./config/genesis.block
if [ "$?" -ne 0 ]; then
  echo "Failed to generate orderer genesis block..."
  exit 1
fi

# generate channel configuration transaction
echo ""
echo "**************************************************"
echo "**  generate channel configuration transaction  **"
echo "**************************************************"
configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx ./config/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
if [ "$?" -ne 0 ]; then
  echo "Failed to generate channel configuration transaction..."
  exit 1
fi

# generate anchor peer transaction for org1
echo ""
echo "*********************************************"
echo "**  generate anchor peer transaction Org1  **"
echo "*********************************************"
configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./config/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org1MSP..."
  exit 1
fi

# generate anchor peer transaction for org2
echo ""
echo "*********************************************"
echo "**  generate anchor peer transaction Org2  **"
echo "*********************************************"
configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./config/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org2MSP..."
  exit 1
fi

# generate anchor peer transaction for org3
echo ""
echo "*********************************************"
echo "**  generate anchor peer transaction Org3  **"
echo "*********************************************"
configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./config/Org3MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org3MSP
if [ "$?" -ne 0 ]; then
  echo "Failed to generate anchor peer update for Org3MSP..."
  exit 1
fi