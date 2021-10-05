#!/bin/bash 

#set -eu


if [ -z ${RAND} ];
then 
    echo "RAND variable node defined"
    exit 1
fi 


if [ -z ${CLUSTER} ];
then 
    CLUSTER="aro-$RAND"
    echo "##vso[task.setvariable variable=CLUSTER]$CLUSTER"
    export CLUSTER
fi 

if [ -z ${RESOURCEGROUP} ];
then 
    RESOURCEGROUP="$CLUSTER-$LOCATION"
    echo "##vso[task.setvariable variable=RESOURCEGROUP]$RESOURCEGROUP"
    export RESOURCEGROUP
fi 

GET_ARO_CLUSTER=$(az aro list | jq -r ".[].name" | grep ${CLUSTER}))
if [ ! -z $GET_ARO_CLUSTER ];
then 
  az aro delete --resource-group $RESOURCEGROUP --name $CLUSTER --yes
else 
  echo "Skipping ARO cluster removal"
fi 

ARO_GROUPS=$(az group list | jq .[].name | grep ${RESOURCEGROUP})
for aro_grp in ${ARO_GROUPS}
do
    aro_grp=$(echo $aro_grp | sed 's/ *$//g' | sed "s/['\"]//g")
    echo "DELETE ${aro_grp}"
    az group delete  --name ${aro_grp} --yes
done