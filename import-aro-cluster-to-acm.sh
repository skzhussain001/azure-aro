#!/bin/bash 
# https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.3/html/clusters/importing-a-target-managed-cluster-to-the-hub-cluster#importing-a-managed-cluster-with-the-cli
## Run command on hub cluster 

if [ -ne $4 ];
then
  echo "Please Cluster Name."
  echo "USAGE: $0 cluster-name https://api.ocp4.example.com:6443 sha256~xXxXxXxXxXxXxXxXxXxXxXx" 
  exit 1
fi 


CLUSTER_NAME=$1
TARGET_CLUSTER=$2
TARGET_CLUSTER_TOKEN=$3
CLUSTER_ENVIORNMENT=$4

echo "Set the name of the context for hub cluster"
oc config rename-context $(oc config current-context) hubcluster

ACMHUB_CLUSTER=$(oc whoami --show-console)


echo "Creating configuration for ${CLUSTER_NAME}"
oc status
oc new-project ${CLUSTER_NAME}
oc label namespace ${CLUSTER_NAME} cluster.open-cluster-management.io/managedCluster=${CLUSTER_NAME}

cat >managed-cluster.yaml<<EOF
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: ${CLUSTER_NAME}
spec:
  hubAcceptsClient: true
EOF

oc apply -f managed-cluster.yaml


cat >klusterlet-addon-config.yaml<<EOF
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${CLUSTER_NAME}
   labels:
    enviornment: ${CLUSTER_ENVIORNMENT}
spec:
  clusterName: ${CLUSTER_NAME}
  clusterNamespace: ${CLUSTER_NAME}
  applicationManager:
    enabled: true
  certPolicyController:
    enabled: true
  clusterLabels:
    cloud: Azure
    vendor: OpenShift
  iamPolicyController:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
  version: 2.2.0
EOF

cat klusterlet-addon-config.yaml
oc apply -f klusterlet-addon-config.yaml || exit 1

oc get secret ${CLUSTER_NAME}-import -n ${CLUSTER_NAME} -o jsonpath={.data.crds\\.yaml} | base64 --decode > klusterlet-crd.yaml || exit 1
oc get secret ${CLUSTER_NAME}-import -n ${CLUSTER_NAME} -o jsonpath={.data.import\\.yaml} | base64 --decode > import.yaml || exit 1


echo "Importing ${CLUSTER_NAME} into ${ACMHUB_CLUSTER}"
oc login --token=${TARGET_CLUSTER_TOKEN} --server=${TARGET_CLUSTER}
oc config rename-context $(oc config current-context) ${CLUSTER_NAME}
oc status
oc apply --context=${CLUSTER_NAME}  -f klusterlet-crd.yaml || exit 1
oc apply --context=${CLUSTER_NAME}  -f import.yaml || exit 1

rm -rf klusterlet-crd.yaml
rm -rf import.yaml

oc get --context=${CLUSTER_NAME} pod -n open-cluster-management-agent
oc get --context=${CLUSTER_NAME} pod -n open-cluster-management-agent-addon

exit 0