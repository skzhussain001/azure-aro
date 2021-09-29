#!/bin/bash 

set -eu

if [ -z ${BUILDDATE} ];
then 
    BUILDDATE="$(date +%Y%m%d-%H%M%S)"
    echo "##vso[task.setvariable variable=BUILDDATE]$BUILDDATE"
    export BUILDDATE
fi 

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

if [ -z ${SUBID} ];
then 
    SUBID="$(az account show -o tsv --query id)"
    echo "##vso[task.setvariable variable=SUBID]$SUBID"
    export SUBID
fi 

if [ -z ${VNET_NAME} ];
then 
    VNET_NAME="$VNET_NAME-vnet"
    echo "##vso[task.setvariable variable=VNET_NAME]$VNET_NAME"
    export VNET_NAME
fi 


if [ -z ${VNET_OCTET1} ];
then 
    VNET_OCTET1="$(echo $VNET | cut -f1 -d.)"
    echo "##vso[task.setvariable variable=VNET_OCTET1]$VNET_OCTET1"
    export VNET_OCTET1
fi 

if [ -z ${VNET_OCTET2} ];
then 
    VNET_OCTET2="$(echo $VNET | cut -f2 -d.)"
    echo "##vso[task.setvariable variable=VNET_OCTET2]$VNET_OCTET2"
    export VNET_OCTET2
fi 

if [ -z "$VNET_RG" ]; then
    VNET_RG="$RESOURCEGROUP"
    echo "##vso[task.setvariable variable=VNET_RG]$VNET_RG"
    export VNET_RG
fi

az aro delete --resource-group $RESOURCEGROUP --name $CLUSTER