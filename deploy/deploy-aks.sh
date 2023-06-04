#!/bin/bash
set -x

az config set extension.use_dynamic_install=yes_without_prompt
az extension add --name aks-preview
az extension update --name aks-preview
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.AlertsManagement

#
# Variables for Azure Kubernetes Service (AKS)
#


# SUBSCRIPTION_ID="xxx-xxx-xxx-xxx"
SUBSCRIPTION_ID=$(az account show | jq -r .id)

AKS_CLUSTER_NAME="poc-aks"
AKS_NODE_COUNT=2
RESOURCE_GROUP_NAME="rg-${AKS_CLUSTER_NAME}"
LOCATION="EastUS"
VNET_NAME="vnet-${AKS_CLUSTER_NAME}"
VNET_ADDRESS_PREFIXES="10.0.0.0/8"
SUBNET_NODE_NAME="subnet-nodepool"
SUBNET_NODE_ADDRESS_PREFIXES="10.240.0.0/16"
SUBNET_POD_NAME="subnet-podpool"
SUBNET_POD_ADDRESS_PREFIXES="10.241.0.0/16"
KUBERNETES_VERSION="1.26.3"
CNI_PLUGIN="azure"
NETWORK_POLICY="azure"
NODE_VM_SIZE="Standard_B4ms"

#
# Variables for Application Gateway Ingress Controller (AGIC)
#
SUBNET_AGIC_NAME="subnet-agic"
SUBNET_AGIC_ADDRESS_PREFIXES="10.55.66.0/24"
AGIC_NAME="agic-${AKS_CLUSTER_NAME}"

#
# Variable for Log Analytics Workspace
#
LOG_ANALYTICS_WORKSPACE_NAME="law-${AKS_CLUSTER_NAME}"
LOG_ANALYTICS_WORKSPACE_SKU="PerGB2018"

#
# Variable for Azure Monitor Workspace
#
AZURE_MONITOR_WORKSPACE_NAME="amw-${AKS_CLUSTER_NAME}"
GRAFANA_NAME="grafana-${AKS_CLUSTER_NAME}"

#
# Step 1: Create a resource group
#

az group create --name ${RESOURCE_GROUP_NAME} --location ${LOCATION}

#
# Step 2: Create a VNet with a subnet for nodes and a subnet for pods
#

az network vnet create -g ${RESOURCE_GROUP_NAME} --location ${LOCATION} --name ${VNET_NAME} --address-prefixes ${VNET_ADDRESS_PREFIXES} -o none
az network vnet subnet create -g ${RESOURCE_GROUP_NAME} --vnet-name ${VNET_NAME} --name ${SUBNET_NODE_NAME} --address-prefixes ${SUBNET_NODE_ADDRESS_PREFIXES} -o none
az network vnet subnet create -g ${RESOURCE_GROUP_NAME} --vnet-name ${VNET_NAME} --name ${SUBNET_POD_NAME} --address-prefixes ${SUBNET_POD_ADDRESS_PREFIXES} -o none
az network vnet subnet create -g ${RESOURCE_GROUP_NAME} --vnet-name ${VNET_NAME} --name ${SUBNET_AGIC_NAME} --address-prefixes ${SUBNET_AGIC_ADDRESS_PREFIXES} -o none

#
# Step 3: Azure Managed Prometheus: Create Azure Monitor workspace
# Creation: ~ 22s

time az resource create -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
     --namespace microsoft.monitor \
     --resource-type accounts \
     --name ${AZURE_MONITOR_WORKSPACE_NAME} \
     --properties {}

#
# Step 4: Link to Grafana Instance
#
time az grafana create -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
    --name ${GRAFANA_NAME}

#
# Step 3: Azure Kubernetes Service (AKS)
# Creation: 5 ~ 10m
# https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create


time az aks create -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --enable-cluster-autoscaler \
  --azure-monitor-workspace-resource-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/microsoft.monitor/accounts/${AZURE_MONITOR_WORKSPACE_NAME} \
  --grafana-resource-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/microsoft.dashboard/grafana/${GRAFANA_NAME} \
  --max-count 2 \
  --min-count 1 \
  --tier standard \
  --max-pods 250 \
  --auto-upgrade-channel stable \
  --dns-name-prefix ${AKS_CLUSTER_NAME} \
  --enable-managed-identity \
  --node-count ${AKS_NODE_COUNT} \
  --node-vm-size ${NODE_VM_SIZE} \
  --network-plugin ${CNI_PLUGIN} \
  --network-policy ${NETWORK_POLICY} \
  --vnet-subnet-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${SUBNET_NODE_NAME} \
  --pod-subnet-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${SUBNET_POD_NAME} \
  --enable-addons ingress-appgw \
  --enable-azuremonitormetrics \
  --appgw-name ${AGIC_NAME} \
  --appgw-subnet-id /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP_NAME}/providers/Microsoft.Network/virtualNetworks/${VNET_NAME}/subnets/${SUBNET_AGIC_NAME}


AKS_RESOURCE_GROUPNAME=$(az aks show -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP_NAME} --query "nodeResourceGroup" -o tsv)

if [ -z "$AKS_RESOURCE_GROUPNAME" ]; then
  echo "AKS_RESOURCE_GROUPNAME is null, exit"
  exit 1
fi

#
# Step 4:  Update existing Application Gateway
#
# https://learn.microsoft.com/en-us/cli/azure/network/application-gateway?view=azure-cli-latest#az-network-application-gateway-update

time az network application-gateway update -n ${AGIC_NAME} -g ${AKS_RESOURCE_GROUPNAME} \
  --sku Standard_v2 \
  --capacity 1 \


#
# Azure Container Insight: Create Log Analytics workspace
# https://learn.microsoft.com/en-us/cli/azure/monitor/log-analytics/workspace?view=azure-cli-latest#az-monitor-log-analytics-workspace-create

time az monitor log-analytics workspace create -g ${RESOURCE_GROUP_NAME} -l ${LOCATION} \
    --workspace-name ${LOG_ANALYTICS_WORKSPACE_NAME} \
    --sku ${LOG_ANALYTICS_WORKSPACE_SKU} \
    --ingestion-access Enabled \
    --retention-time 14 \
    --query-access Enabled




# Show link

#       "prometheusQueryEndpoint": "https://amw-poc1-aks-g8ux.eastus.prometheus.monitor.azure.com"


#
# Wipe Resource Group
#
# az group delete --name rg-POC-Mendix --yes --no-wait


# Import kubeconfig to Bastion
# [cloudshell]$ az aks get-credentials --resource-group rg-POC-Mendix --name mendix-poc-aks --file ./kubeconfig_mendix
# [cloudshell]$ scp -P 5566 ./kubeconfig_mendix repairman@20.24.221.253:/home/repairman/kubeconfig_mendix
# [cloudshell]$ ssh repairman@20.24.221.253 -p5566
# [bastion]$ export KUBECONFIG=/home/repairman/kubeconfig_mendix
# [bastion]$ kubectl cluster-info
#
# Kubernetes control plane is running at https://mendix-poc-aks-tf1td1fa.mendix.privatelink.eastasia.azmk8s.io:443
# CoreDNS is running at https://mendix-poc-aks-tf1td1fa.mendix.privatelink.eastasia.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
# Metrics-server is running at https://mendix-poc-aks-tf1td1fa.mendix.privatelink.eastasia.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy
#