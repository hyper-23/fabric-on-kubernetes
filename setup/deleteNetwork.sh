echo ""
echo "********************************************"
echo "**  remove chaincode docker images(dind)  **"
echo "********************************************"
dind=$(kubectl get pods | grep "fabrc-chaincode" | awk '{print $1}')
kubectl exec -i $dind sh <<'EOC'
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi -f $(docker images nid* -q)
EOC

kubectl exec $dind docker images

cd ../

KUBECONFIG_FOLDER=${PWD}/configFiles

kubectl delete --ignore-not-found=true -f ${KUBECONFIG_FOLDER}/docker.yaml

kubectl delete -f ${KUBECONFIG_FOLDER}/caDeployment.yaml

kubectl delete -f ${KUBECONFIG_FOLDER}/cli.yaml
kubectl delete -f ${KUBECONFIG_FOLDER}/peersDeployment.yaml
kubectl delete -f ${KUBECONFIG_FOLDER}/blockchainServices.yaml

kubectl delete -f ${KUBECONFIG_FOLDER}/generateArtifactsJob.yaml
kubectl delete -f ${KUBECONFIG_FOLDER}/copyArtifactsJob.yaml

kubectl delete -f ${KUBECONFIG_FOLDER}/createVolume.yaml
kubectl delete --ignore-not-found=true -f ${KUBECONFIG_FOLDER}/dockerVolume.yaml

sleep 5

echo -e "\npv:" 
kubectl get pv
echo -e "\npvc:"
kubectl get pvc
echo -e "\njobs:"
kubectl get jobs 
echo -e "\ndeployments:"
kubectl get deployments
echo -e "\nservices:"
kubectl get services
echo -e "\npods:"
kubectl get pods

echo -e "\nNetwork Deleted!!\n"
