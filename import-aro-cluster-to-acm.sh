#!/bin/bash 
# https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.3/html/clusters/importing-a-target-managed-cluster-to-the-hub-cluster#importing-a-managed-cluster-with-the-cli
## Run command on hub cluster 

if [ -ne $3 ];
then
  echo "Please Cluster Name."
  echo "USAGE: $0 cluster-name https://api.ocp4.example.com:6443 sha256~xXxXxXxXxXxXxXxXxXxXxXx" 
  exit 1
fi 


CLUSTER_NAME=$1
TARGET_CLUSTER=$2
TARGET_CLUSTER_TOKEN=$3

ACMHUB_CLUSTER=$(oc whoami --show-console)

echo "Importing ${CLUSTER_NAME} into ${ACMHUB_CLUSTER}"

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
    vendor: auto-detect
spec:
  clusterName: ${CLUSTER_NAME}
  clusterNamespace: ${CLUSTER_NAME}
  applicationManager:
    enabled: true
  certPolicyController:
    enabled: true
  clusterLabels:
    cloud: auto-detect
    vendor: auto-detect
  iamPolicyController:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
  version: 2.2.0
EOF

oc apply -f klusterlet-addon-config.yaml

oc get secret ${CLUSTER_NAME}-import -n ${CLUSTER_NAME} -o jsonpath={.data.crds\\.yaml} | base64 --decode > klusterlet-crd.yaml
oc get secret ${CLUSTER_NAME}-import -n ${CLUSTER_NAME} -o jsonpath={.data.import\\.yaml} | base64 --decode > import.yaml

oc login --token=${TARGET_CLUSTER_TOKEN} --server=${TARGET_CLUSTER}
oc status
oc apply -f klusterlet-crd.yaml
oc apply -f import.yaml

rm -rf klusterlet-crd.yaml
rm -rf import.yaml

oc get pod -n open-cluster-management-agent
oc get pod -n open-cluster-management-agent-addon

exit 0