#!/bin/bash

echo
echo "This simple script retrieves via the CF API the credentials of the PAS admin account. The simpler way to obtain this information is to access the OpsMan UI and go to "Credentials". Nevertheless, this script can be re-used and customized to retrieve any type of credentials in a PCF installation."

#
# We first need to know which foundation we need to target
#
echo
read -p "Please input your PCF Operation Manager FQDN (e.g. opsman.example.com): " opsmanFqdn
echo

#
# retrieve your token from the existing uaac
#
token=$(uaac contexts | grep "access_token" | awk {'print $2'})
uaacTokenString="Authorization: Bearer $token"

#
# List the installed products"
#
productUrl="https://$opsmanFqdn/api/v0/deployed/products"
products=$(curl -k "$productUrl" -X GET -H "$uaacTokenString")
echo $products

#
# retrieve the GUID of the CF installation
#
echo
read -p "Please input the GUID of the CF installation (e.g. cf-90d6c74d1da4629d1824) obtained in the previous command: " cfGuid
echo

#
# Finally retrieve the credentials
#
variable=".uaa.admin_credentials"
credUrl=$(printf "%s/%s/credentials/%s" $productUrl $cfGuid $variable) 
echo "Your Admin Credentials:"
echo "======================="
curl -k "$credUrl" -X GET -H "$uaacTokenString"
echo
echo
