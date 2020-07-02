#!/bin/bash

cd ../script

echo ""
echo "********************************"
echo "**  Genetate connect-profile  **"
echo "********************************"

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
    local PP=$(one_line_pem $2)
    local CP=$(one_line_pem $3)
    local OP=$(one_line_pem $4)
    sed $1 \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        -e "s#\${ORDERERPEM}#$OP#" \
        -e "s#\${ORDERERPEM2}#$OP#" \
        -e "s#\${ORDERERPEM3}#$OP#" \
        -e "s#\${ORDERERPEM4}#$OP#" \
        -e "s#\${ORDERERPEM5}#$OP#" \
        $5
}

ARCH=$(uname   -s | grep Darwin)
if [ "$ARCH" == "Darwin" ]; then
  OPTS="-it"
else
  OPTS="-i"
fi

#
echo ""
echo "********************************************"
echo "**  Create connection.json for org1 TEST  **"
echo "********************************************"
# ORG1 setting
PEERPEM=../artifacts/crypto-config/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
CAPEM=../artifacts/crypto-config/peerOrganizations/org1.example.com/ca/ca.org1.example.com-cert.pem
ORDERERPEM=../artifacts/crypto-config/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem
PROFILE=../artifacts/bcapi-config/org1/network/connection.json

# create connection.json
cp template/connection-template-org1.json $PROFILE

echo "$(json_ccp $OPTS $PEERPEM $CAPEM $ORDERERPEM $PROFILE)"
echo "OK"