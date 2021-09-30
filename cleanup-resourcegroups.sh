#!/bin/bash 
## Script to delete aro groups
##  az account show
ARO_GROUPS=$(az group list | jq .[].name | grep aro)
for aro_grp in ${ARO_GROUPS}
do
    aro_grp=$(echo $aro_grp | sed 's/ *$//g' | sed "s/['\"]//g")
    echo "DELETE ${aro_grp}"
    az group delete  --name ${aro_grp} --yes
done