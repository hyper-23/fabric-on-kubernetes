#!/bin/sh

export PATH=${PWD}/../bin:$PATH

cd ../artifacts

# remove previous crypto material and config transactions
rm -fr ./crypto-config/*

# generate crypto material
echo ""
echo "********************************"
echo "**  generate crypto material  **"
echo "********************************"
cryptogen generate --config=./crypto-config.yaml --output="crypto-config"
if [ "$?" -ne 0 ]; then
  echo "Failed to generate crypto material..."
  exit 1
fi

