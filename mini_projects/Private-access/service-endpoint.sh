#!/bin/bash -e

# create a vnet with 2 subnets 
# create ubuntu vm in both subnets 

# create nsg
az network nsg rule create \

 --resource-group $rg \

 --nsg-name ERP-SERVERS-NSG \

 --name Allow_Storage \

 --priority 190 \

 --direction Outbound \

 --source-address-prefixes "VirtualNetwork" \

 --source-port-ranges '*' \

 --destination-address-prefixes "Storage" \

 --destination-port-ranges '*' \

 --access Allow \

 --protocol '*' \

 --description "Allow access to Azure Storage"

az network nsg rule create \

 --resource-group $rg \

 --nsg-name ERP-SERVERS-NSG \

 --name Deny_Internet \

 --priority 200 \

 --direction Outbound \

 --source-address-prefixes "VirtualNetwork" \

 --source-port-ranges '*' \

 --destination-address-prefixes "Internet" \

 --destination-port-ranges '*' \

 --access Deny \

 --protocol '*' \

 --description "Deny access to Internet."

# create storage account

STORAGEACCT=$(az storage account create \

 --resource-group $rg \

 --name engineeringdocs$RANDOM \

 --sku Standard_LRS \

 --query "name" | tr -d '"')

#save key
STORAGEKEY=$(az storage account keys list \

 --resource-group $rg \

 --account-name $STORAGEACCT \

 --query "[0].value" | tr -d '"')

# create file share
az storage share create \

 --account-name $STORAGEACCT \

 --account-key $STORAGEKEY \

 --name "erp-data-share"

# assign endpoints to the subnet

az network vnet subnet update \

 --vnet-name ERP-servers \

 --resource-group $rg \

 --name Databases \

 --service-endpoints Microsoft.Storage

az storage account update \

  --name $storageAcctName \

  --resource-group myResourceGroup \

  --default-action Deny

# storage accounts are open to accept all traffic. You want only traffic from the Databases subnet to be able to access the storage.

az storage account network-rule add \

 --resource-group $rg \

 --account-name $STORAGEACCT \

 --vnet-name ERP-servers \

 --subnet Databases


if [[ $? -eq 0 ]] 
then
APPSERVERIP="$(az vm list-ip-addresses \

 --resource-group $rg \

 --name AppServer \

 --query "[].virtualMachine.network.publicIpAddresses[*].ipAddress" \

 --output tsv)"

DATASERVERIP="$(az vm list-ip-addresses \

 --resource-group $rg \

 --name DataServer \

 --query "[].virtualMachine.network.publicIpAddresses[*].ipAddress" \

 --output tsv)"
else 
echo 'ERROR OCCURED !!! '
fi

echo 'Try mounting the file share to each vm' 

ssh -t Azureuser@$DATASERVERIP \

 "mkdir Azureshare; \

 sudo mount -t cifs //$STORAGEACCT.file.core.windows.net/erp-data-share Azureshare \

 -o vers=3.0,username=$STORAGEACCT,password=$STORAGEKEY,dir_mode=0777,file_mode=0777,sec=ntlmssp;findmnt \

 -t cifs; exit; bash"

if [[ $? -eq 0 ]] 
then
echo 'The file share was successfully mounted...'
echo 'But it will fail on other VM'
else 
echo 'ERROR OCCURED!!! '
fi

ssh -t Azureuser@$APPSERVERIP \

 "mkdir Azureshare; \

 sudo mount -t cifs //$STORAGEACCT.file.core.windows.net/erp-data-share Azureshare \

 -o vers=3.0,username=$STORAGEACCT,password=$STORAGEKEY,dir_mode=0777,file_mode=0777,sec=ntlmssp; findmnt \

 -t cifs; exit; bash"
