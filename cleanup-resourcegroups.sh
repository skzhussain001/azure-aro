#!/bin/bash 
## Script to delete aro groups
##  az account show
ARO_GROUPS=$(az group list | jq .[].name | grep aro)
for aro_grp in ${ARO_GROUPS}
do
    echo "DELETE ${aro_grp}"
    az group delete  --name ${aro_grp} --yes
done