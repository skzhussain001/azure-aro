#!/bin/bash 

#set -eu


if [ -z ${CLUSTER} ];
then 
    CLUSTER="aro-$(whoami)-$RAND"
    echo "##vso[task.setvariable variable=CLUSTER]$CLUSTER"
    export CLUSTER
fi 

if [ -z ${RESOURCEGROUP} ];
then 
    RESOURCEGROUP="$CLUSTER-$LOCATION"
    echo "##vso[task.setvariable variable=RESOURCEGROUP]$RESOURCEGROUP"
    export RESOURCEGROUP
fi 

#az aro delete --resource-group $RESOURCEGROUP --name $CLUSTER --yes