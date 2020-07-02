#!/bin/bash

# Create Configfile
echo ""
echo "********************************"
echo "**  Start Generate Artifacts  **"
echo "********************************"
cd ../script
./gen-crypto-config.sh
./gen-config.sh
./gen-connection-config.sh

cd ../

# Check configFiles-test
if [ -d "${PWD}/configFiles-test" ]; then
    KUBECONFIG_FOLDER=${PWD}/configFiles
else
    echo "Configuration files are not found."
    exit
fi


# Create fabrc-Chaincode deployment
if [ "$(cat configFiles-test/peersDeployment.yaml | grep -c tcp://fabrc-chaincode)" != "0" ]; then
    # Deploy fabrc-Chaincode container
    echo "peersDeployment.yaml file was configured to use fabrc-Chaincode in a container."
    echo "Creating fabrc-Chaincode deployment"

    kubectl create -f ${KUBECONFIG_FOLDER}/dockerVolume.yaml
    kubectl create -f ${KUBECONFIG_FOLDER}/docker.yaml
    sleep 5

    dockerPodStatus=$(kubectl get pods --selector=name=fabrc-chaincode --output=jsonpath={.items..phase})
    echo "Wating for fabrc-Chaincode container to run."
    while [ "${dockerPodStatus}" != "Running" ]; do
        echo "Current status of fabrc-Chaincode is ${dockerPodStatus}"
        sleep 5;
        if [ "${dockerPodStatus}" == "Error" ]; then
            echo "There is an error in the fabrc-Chaincode pod. Please check logs."
            exit 1
        fi
        dockerPodStatus=$(kubectl get pods --selector=name=fabrc-chaincode --output=jsonpath={.items..phase})
    done
fi


# Creating Persistant Volume
echo -e "\nCreating volume"
if [ "$(kubectl get pvc | grep shared-pvc | awk '{print $2}')" != "Bound" ]; then
    echo "The Persistant Volume does not seem to exist or is not bound"
    echo "Creating Persistant Volume"

    echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/createVolume.yaml"
    kubectl create -f ${KUBECONFIG_FOLDER}/createVolume.yaml
    sleep 5

    if [ "kubectl get pvc | grep shared-pvc | awk '{print $3}'" != "shared-pv" ]; then
        echo "Success creating Persistant Volume"
    else
        echo "Failed to create Persistant Volume"
    fi
else
    echo "The Persistant Volume exists, not creating again"
fi


# Copy the required files(configtx.yaml, cruypto-config.yaml, chaincode etc.) into volume
echo -e "\nCreating Copy artifacts job."
echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/copyArtifactsJob.yaml"
kubectl create -f ${KUBECONFIG_FOLDER}/copyArtifactsJob.yaml

pod=$(kubectl get pods --selector=job-name=copyartifacts --output=jsonpath={.items..metadata.name})

podSTATUS=$(kubectl get pods --selector=job-name=copyartifacts --output=jsonpath={.items..phase})

echo "Wating for container of copy artifact pod to run."
while [ "${podSTATUS}" != "Running" ]; do
    echo "Current status of ${pod} is ${podSTATUS}"
    sleep 5;
    if [ "${podSTATUS}" == "Error" ]; then
        echo "There is an error in copyartifacts job. Please check logs."
        exit 1
    fi
    podSTATUS=$(kubectl get pods --selector=job-name=copyartifacts --output=jsonpath={.items..phase})
done

echo -e "${pod} is now ${podSTATUS}"
echo -e "\nStarting to copy artifacts in persistent volume."

#fix for this script to work on icp and ICS
kubectl cp ./artifacts $pod:/shared/

echo "Waiting for 10 more seconds for copying artifacts to avoid any network delay"
sleep 10
JOBSTATUS=$(kubectl get jobs |grep "copyartifacts" |awk '{print $2}')
echo "Waiting for copyartifacts job to complete"
while [ "${JOBSTATUS}" != "1/1" ]; do
    sleep 1;
    PODSTATUS=$(kubectl get pods | grep "copyartifacts" | awk '{print $3}')
        if [ "${PODSTATUS}" == "Error" ]; then
            echo "There is an error in copyartifacts job. Please check logs."
            exit 1
        fi
    JOBSTATUS=$(kubectl get jobs |grep "copyartifacts" |awk '{print $2}')
done
echo "Copy artifacts job completed"


# Create services for all peers, ca, orderer, couch
echo -e "\nCreating Services for blockchain network"
echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/blockchainServices.yaml"
kubectl create -f ${KUBECONFIG_FOLDER}/blockchainServices.yaml

# Convert '_sk' file to 'key.pem'
echo -e "\nGenerating the required artifacts for Blockchain network"
echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/generateArtifactsJob.yaml"
kubectl create -f ${KUBECONFIG_FOLDER}/generateArtifactsJob.yaml

JOBSTATUS=$(kubectl get jobs |grep utils|awk '{print $2}')
echo "Waiting for generateArtifacts job to complete"
while [ "${JOBSTATUS}" != "1/1" ]; do
    sleep 1;
    UTILSSTATUS=$(kubectl get pods | grep "utils" | awk '{print $3}')
    if [ "${UTILSSTATUS}" == "Error" ]; then
        echo "There is an error in utils job. Please check logs."
        exit 1
    fi
    JOBSTATUS=$(kubectl get jobs |grep utils|awk '{print $2}')
done

# Create peers, orderer, ca, couch, cli using Kubernetes Deployments
echo -e "\nCreating new Deployment to create three peers in network"
echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/peersDeployment.yaml"
kubectl create -f ${KUBECONFIG_FOLDER}/peersDeployment.yaml
echo "Running: kubectl create -f ${KUBECONFIG_FOLDER}/cli.yaml"
kubectl create -f ${KUBECONFIG_FOLDER}/cli.yaml

echo "Checking if all deployments are ready"

NUMPENDING=$(kubectl get deployments | grep blockchain | awk '{print $4}' | grep 0 | wc -l | awk '{print $1}')
echo "Waiting on pending deployments."
while [ "${NUMPENDING}" != "0" ]; do
    echo "Deployments pending = ${NUMPENDING}"
    NUMPENDING=$(kubectl get deployments | grep blockchain | awk '{print $4}' | grep 0 | wc -l | awk '{print $1}')
    sleep 1
done

echo "Waiting for 10 seconds for peers and orderer to settle"
sleep 10

pod=$(kubectl get pods --selector=name=cli --output=jsonpath={.items..metadata.name})

echo "$pod"

#fix for this script to work on icp and ICS
kubectl cp ./script/script.sh $pod:/go
kubectl exec -it $pod bash /go/script.sh

# Print Pod list
echo ""
kubectl get pod

echo -e "\nNetwork Setup Completed !!"
