#!/bin/bash

# Written by Stuart Kirk
# stuart.kirk@microsoft.com
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# API and INGRESS server configuration must be set to either "Public" or "Private" (case sensitive)


################################################################################################## Initialize
set -eu
set -x 

#if [ $# -gt 1 ]; then
#    echo "Usage: $BASH_SOURCE <Custom Domain eg. aro.foo.com>"
#    exit 1
#fi

# Random string generator - don't change this.
RAND="$(echo $RANDOM | tr '[0-9]' '[a-z]')"
export RAND

# Customize these variables as you need for your cluster deployment
# If you wish to use custom DNS servers, you can place them into the variable below as space-separated entries

APIPRIVACY="Public"
DNSSERVERS=""
#DNSSERVERS="1.2.3.4 55.55.55.55 15.15.15.15"
INGRESSPRIVACY="Public"
LOCATION="eastus"
MASTER_SIZE="Standard_D8s_v3"
VNET="10.151.0.0"
VNET_RG=""
WORKERS="4"
WORKER_SIZE="Standard_D4s_v3"

################################################ Don't change these
export APIPRIVACY
export DNSSERVERS
export INGRESSPRIVACY
export LOCATION
export MASTER_SIZE
export VNET
export VNET_RG
export WORKERS
export WORKER_SIZE

if [ -z ${BUILDDATE} ];
then 
    BUILDDATE="$(date +%Y%m%d-%H%M%S)"
    echo "##vso[task.setvariable variable=BUILDDATE]$BUILDDATE"
    export BUILDDATE
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

if [ -z ${SUBID} ];
then 
    SUBID="$(az account show -o tsv --query id)"
    echo "##vso[task.setvariable variable=SUBID]$SUBID"
    export SUBID
fi 

if [ -z ${VNET_NAME} ];
then 
    VNET_NAME="$CLUSTER-vnet"
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

################################################################################################## Infrastructure Provision

 
echo " "
echo "Building Azure Red Hat OpenShift 4"
echo "----------------------------------"

# Register the resource providers
function create_microsoft_authorization(){
        if [ -n "$(az provider show -n Microsoft.Authorization -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "The ARO resource provider has not been registered for your subscription $SUBID."
        echo -n "I will attempt to register the ARO RP now (this may take a few minutes)..."
        az provider register -n Microsoft.Authorization --wait > /dev/null
        echo "done."
        echo -n "Verifying the Microsoft.Authorization is registered..."
        if [ -n "$(az provider show -n Microsoft.Authorization -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
            echo "error! Unable to register Microsoft.Authorization. Please remediate this."
            exit 1
        fi
        echo "done."
    fi
}

function register_resource_providers(){
    az account set --subscription $SUBID

    if [ -n "$(az provider show -n Microsoft.Compute -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "The Azure Compute resource provider has not been registered for your subscription $SUBID."
        echo -n "I will attempt to register the Azure Compute RP now (this may take a few minutes)..."
        az provider register -n Microsoft.Compute --wait > /dev/null
        echo "done."
        echo -n "Verifying the Azure Compute RP is registered..."
    if [ -n "$(az provider show -n Microsoft.Compute -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "error! Unable to register the Azure Compute RP. Please remediate this."
        exit 1
    fi
        echo "done."
    fi

    if [ -n "$(az provider show -n Microsoft.RedHatOpenShift -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "The ARO resource provider has not been registered for your subscription $SUBID."
        echo -n "I will attempt to register the ARO RP now (this may take a few minutes)..."
        az provider register -n Microsoft.RedHatOpenShift --wait > /dev/null
        echo "done."
        echo -n "Verifying the ARO RP is registered..."
        az provider show -n Microsoft.RedHatOpenShift -o table
        if [ -n "$(az provider show -n Microsoft.RedHatOpenShift -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
            echo "error! Unable to register the ARO RP. Please remediate this."
            exit 1
        fi
        echo "done."
    fi

    create_microsoft_authorization

    if [ -n "$(az provider show -n Microsoft.Storage -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
        echo "The ARO resource provider has not been registered for your subscription $SUBID."
        echo -n "I will attempt to register the Storage now (this may take a few minutes)..."
        az provider register -n Microsoft.Storage --wait > /dev/null
        echo "done."
        echo -n "Verifying the Microsoft.Storage is registered..."
        if [ -n "$(az provider show -n Microsoft.Storage -o table | grep -E '(Unregistered|NotRegistered)')" ]; then
            echo "error! Unable to register the Microsoft.Storage. Please remediate this."
            exit 1
        fi
        echo "done."
    fi

    if [ $# -eq 1 ]; then
        CUSTOMDOMAIN="--domain=$1"
        export CUSTOMDOMAIN
        echo "You have specified a parameter for a custom domain: $1. I will configure ARO to use this domain."
        echo " "
    fi

    # Custom DNS Server Check
    check_custom_dns_server

    # Resource Group Creation
    echo -n "Creating Resource Group..."
    az group create -g "$RESOURCEGROUP" -l "$LOCATION" -o table >> /dev/null 
    echo "done"

    exit 0
}

function check_custom_dns_server(){
    if [ -n "$DNSSERVERS" ]; then
        CUSTOMDNSSERVERS="--dns-servers $DNSSERVERS"
        export CUSTOMDNSSERVERS
        echo "You have specified that the ARO virtual network should be created using the custom DNS servers: $DNSSERVERS"
        echo " "
    else
        CUSTOMDNSSERVERS=""
    fi
}

function fail {
  echo $1 >&2
  exit 1
}

function retry {
  local n=1
  local max=5
  local delay=30
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Attempt $n/$max:"
        az account show
        sleep 3s
        create_microsoft_authorization
        sleep $delay;
      else
        fail "The command has failed after $n attempts."
      fi
    }
  done
}

# Create a virtual network containing two empty subnets
function configure_networking(){
    echo "BUILDDATE ${BUILDDATE}"
    # Custom DNS Server Check
    check_custom_dns_server
    RESOURCEGROUP=$(echo $RESOURCEGROUP | sed 's/ *$//g' | sed "s/['\"]//g")
    VNET_NAME=$(echo $VNET_NAME | sed 's/ *$//g' | sed "s/['\"]//g")
    CLUSTER=$(echo $CLUSTER | sed 's/ *$//g' | sed "s/['\"]//g")

    az account set --subscription $SUBID

    # VNet Creation
    echo -n "Creating Virtual Network..."
    az network vnet create -g "$RESOURCEGROUP" -n $VNET_NAME --address-prefixes $VNET/16 $CUSTOMDNSSERVERS -o table > /dev/null
    echo "done"

    # Subnet Creation
    echo -n "Creating 'Master' Subnet..."
    az network vnet subnet create -g "$RESOURCEGROUP" --vnet-name "$VNET_NAME" -n "$CLUSTER-master" --address-prefixes "$VNET_OCTET1.$VNET_OCTET2.$(shuf -i 0-254 -n 1).0/24" --service-endpoints Microsoft.ContainerRegistry -o table > /dev/null
    echo "done"
    echo -n "Creating 'Worker' Subnet..."
    az network vnet subnet create -g "$RESOURCEGROUP" --vnet-name "$VNET_NAME" -n "$CLUSTER-worker" --address-prefixes "$VNET_OCTET1.$VNET_OCTET2.$(shuf -i 0-254 -n 1).0/24" --service-endpoints Microsoft.ContainerRegistry -o table > /dev/null
    echo "done"

    # VNet & Subnet Configuration
    echo -n "Disabling 'PrivateLinkServiceNetworkPolicies' in 'Master' Subnet..."
    az network vnet subnet update -g "$RESOURCEGROUP" --vnet-name "$VNET_NAME" -n "$CLUSTER-master" --disable-private-link-service-network-policies true -o table > /dev/null
    echo "done"
    #echo -n "Adding ARO RP Contributor access to VNET..."
    az role assignment create --scope /subscriptions/$SUBID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME --assignee ${ROLE_ASSIGNEE}  --role "Contributor" -o table > /dev/null
    ######
    ### REMOVING FOR NOW
    ######
    #echo "az role assignment create --scope /subscriptions/$SUBID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME  --assignee-object-id ${ROLE_ASSIGNEE}  --role "Contributor" --assignee-principal-type ServicePrincipal"
    #COMMAND="az role assignment create --scope /subscriptions/$SUBID/resourceGroups/$RESOURCEGROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME  --assignee-object-id ${ROLE_ASSIGNEE}  --role "Contributor" --assignee-principal-type ServicePrincipal"
    #retry ${COMMAND}

    echo "done"
    exit 0
}


function check_pull_secret(){
    # Pull Secret
    echo -n "Checking if pull-secret.txt exists..."
    if [ -f "pull-secret.txt" ]; then
        echo "detected"
        echo -n "Removing extra characters from pull-secret.txt..."
        tr -d "\n\r" < pull-secret.txt >pull-secret.tmp
        rm -f pull-secret.txt
        mv pull-secret.tmp pull-secret.txt
        echo "done"
        PULLSECRET="--pull-secret=$(cat pull-secret.txt)"
        export PULLSECRET
    elif [ ! -z $CREATEPULLSECRET ];
    then 
        echo $CREATEPULLSECRET > pull-secret.txt
        echo -n "Removing extra characters from pull-secret.txt..."
        tr -d "\n\r" < pull-secret.txt >pull-secret.tmp
        rm -f pull-secret.txt
        mv pull-secret.tmp pull-secret.txt
        echo "done"
        PULLSECRET="--pull-secret=$(cat pull-secret.txt)"
        export PULLSECRET
    else
        echo "not detected."
        exit 1
    fi
    echo " "
}


################################################################################################## Build ARO
function create_aro_cluster(){

    az account set --subscription $SUBID
    # create pull secret 
    check_pull_secret

    # Build ARO
    echo "=============================================================================================================================================================================="
    echo "Building ARO with 3 x $MASTER_SIZE masters & $WORKERS x $WORKER_SIZE sized workers - this takes roughly 30-40mins. The time is now: $(date)..."
    echo " "
    echo "Executing: "
    echo "az aro create -g $RESOURCEGROUP -n $CLUSTER --cluster-resource-group $RESOURCEGROUP-cluster --vnet=$VNET_NAME --vnet-resource-group=$VNET_RG --master-subnet=$CLUSTER-master --worker-subnet=$CLUSTER-worker --ingress-visibility=$INGRESSPRIVACY --apiserver-visibility=$APIPRIVACY --worker-count=$WORKERS --master-vm-size=$MASTER_SIZE --worker-vm-size=$WORKER_SIZE $CUSTOMDOMAIN $PULLSECRET -o table"
    echo " "
    time az aro create -g "$RESOURCEGROUP" -n "$CLUSTER" --cluster-resource-group "$RESOURCEGROUP-cluster" --vnet="$VNET_NAME" --vnet-resource-group="$VNET_RG" --master-subnet="$CLUSTER-master" --worker-subnet="$CLUSTER-worker" --ingress-visibility="$INGRESSPRIVACY" --apiserver-visibility="$APIPRIVACY" --worker-count="$WORKERS" --master-vm-size="$MASTER_SIZE" --worker-vm-size="$WORKER_SIZE" $CUSTOMDOMAIN $PULLSECRET --only-show-errors -o table


    ################################################################################################## Post Provisioning

    # Update ARO RG tags
    echo " "
    echo -n "Updating resource group tags..."
    DOMAIN="$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --only-show-errors --query 'clusterProfile.domain' 2>/dev/null)"
    export DOMAIN
    VERSION="$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --only-show-errors --query 'clusterProfile.version' 2>/dev/null)"
    export VERSION
    az group update -g "$RESOURCEGROUP" --tags "ARO $VERSION Build Date=$BUILDDATE" --only-show-errors -o table >> /dev/null 2>&1
    echo "done."

}

# Forward Zone Creation (if necessary)
function create_forward_zone(){
    if [ -n "$CUSTOMDOMAIN" ]; then

        CUSTOMDOMAINNAME="$(echo $CUSTOMDOMAIN | cut -f2 -d=)"
        export CUSTOMDOMAINNAME

        if [ -z "$(az network dns zone list -o tsv --query '[*].name' | grep $CUSTOMDOMAINNAME)" ]; then
            echo -n "A DNS zone was not detected for $CUSTOMDOMAINNAME Creating..."
        az network dns zone create -n $CUSTOMDOMAINNAME -g $RESOURCEGROUP --only-show-errors -o table >> /dev/null 2>&1
            echo "done." 
            echo " "
            echo "Dumping nameservers for newly created zone..." 
            az network dns zone show -n $CUSTOMDOMAINNAME -g $RESOURCEGROUP --only-show-errors -o tsv --query 'nameServers'
            echo " "
        else
            echo "A DNS zone was already detected for $CUSTOMDOMAINNAME. Skipping zone creation..."
        fi

        DNSRG="$(az network dns zone list -o table |grep $CUSTOMDOMAINNAME | awk '{print $2}')"
        export DNSRG

        if [ -z "$(az network dns record-set list -g $DNSRG -z $CUSTOMDOMAINNAME -o table |grep api)" ]; then
            echo -n "An A record for the ARO API does not exist. Creating..." 
            IPAPI="$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query apiserverProfile.ip)"
            export IPAPI
            az network dns record-set a add-record -z $CUSTOMDOMAINNAME -g $DNSRG -a $IPAPI -n api --only-show-errors -o table >> /dev/null 2>&1
            echo "done."
        else
            echo "An A record appears to already exist for the ARO API server. Please verify this in your DNS zone configuration."
        fi

        if [ -z "$(az network dns record-set list -g $DNSRG -z $CUSTOMDOMAINNAME -o table |grep apps)" ]; then
            echo -n "An A record for the apps wildcard ingress does not exist. Creating..."
            IPAPPS="$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query ingressProfiles[*].ip)"
            export IPAPPS
            az network dns record-set a add-record -z $CUSTOMDOMAINNAME -g $DNSRG -a $IPAPPS -n *.apps --only-show-errors -o table >> /dev/null 2>&1
            echo "done."
        else
            echo "An A record appears to already exist for the apps wildcard ingress. Please verify this in your DNS zone configuration."
        fi
    fi
}


################################################################################################## Output Messages

function print_output(){
    echo " "
    echo "$(az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP -o table 2>/dev/null)"

    echo " "
    echo "$APIPRIVACY Console URL"
    echo "-------------------"
    echo "$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query 'consoleProfile.url' 2>/dev/null)"

    echo " "
    echo "$APIPRIVACY API URL"
    echo "-------------------"
    echo "$(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query 'apiserverProfile.url' 2>/dev/null)"

    echo " "
    echo "To log in to the oc CLI (per accessibility)"
    echo "-------------------------------------------"
    echo "oc login $(az aro show -n $CLUSTER -g $RESOURCEGROUP -o tsv --query 'apiserverProfile.url') -u kubeadmin -p $(az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP -o tsv --query 'kubeadminPassword')"

    echo " "
    echo "To delete this ARO Cluster"
    echo "--------------------------"
    echo "az aro delete -n $CLUSTER -g $RESOURCEGROUP -y ; az group delete -n $RESOURCEGROUP -y"

    if [ -n "$CUSTOMDNS" ]; then

        echo " "
        echo "To delete the two A records in DNS"
        echo "----------------------------------"
        echo "az network dns record-set a delete -g $DNSRG -z $DNS -n api -y ; az network dns record-set a delete -g $DNSRG -z $DNS -n *.apps -y"
    fi

    echo " "
    echo "-end-"
    echo " "
}

# Print usage
usage() {
  echo -n "${0} [OPTION]
 Options:
  -r, --register-resource-providers         Register the resource providers
  -cd, --register-resource-providers-custom-domain        Register the resource providers with custom domain 
  -p, --check-pull-secret        Configure Red Hat pull secret (optional)
  -n, --configure-networking        Create a virtual network containing two empty subnets
  -c, --create-aro-cluster        Create the cluster
  --f, --create-forward-zone        Create forward zone for cluster 
  -pr, --print-output        Print output of cluster deployment 
  -h, --help        Display this help and exit
"
}


function deploy_all(){
    register_resource_providers
    #register_resource_providers $2 
    check_pull_secret
    configure_networking
    create_aro_cluster
    create_forward_zone
}


optstring=v
unset options
while (($#)); do
  case $1 in
    # If option is of type -ab
    -[!-]?*)
      # Loop over each character starting with the second
      for ((i=1; i < ${#1}; i++)); do
        c=${1:i:1}

        # Add current char to options
        options+=("-$c")

        # If option takes a required argument, and it's not the last char make
        # the rest of the string its argument
        if [[ $optstring = *"$c:"* && ${1:i+1} ]]; then
          options+=("${1:i+1}")
          break
        fi
      done
      ;;

    # If option is of type --foo=bar
    --?*=*) options+=("${1%%=*}" "${1#*=}") ;;
    # add --endopts for --
    --) options+=(--endopts) ;;
    # Otherwise, nothing special
    *) options+=("$1") ;;
  esac
  shift
done
set -- "${options[@]}"
unset options

# Read the options and set stuff
while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2; break ;;
    -r|--register-resource-providers)  shift; register_resource_providers ;;
    -cd|--register-resource-providers-custom-domain)  shift; register_resource_providers $2 ;;
    -p|--check-pull-secret) shift; check_pull_secret;;
    -n|--configure-networking) shift; configure_networking;;
    -c|--create-aro-cluster) shift; create_aro_cluster;;
    -f|--create-forward-zone ) shift; create_forward_zone;;
    -pr|--print-output) shift; print_output;;
    --endopts) shift; break ;;
    *) deploy_all ;;
  esac
  shift
done

# Store the remaining part as arguments.
args+=("$@")

exit 0
