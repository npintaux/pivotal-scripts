#!/bin/bash
echo
echo
echo "This script will prepare an VM image and a VM instance from a desired version of OpsMan."
echo "It reserves an IP address under the name 'om-public-ip' and assigns it to the VM."
echo "Prerequisite: retrieve the path to the release image from PivNet."
echo
echo

#
# Constants (can be modified to customize your script)
#
infraSubnetSuffix="-subnet-infrastructure"

#
# Gather input data to extrapolate new variable names
#
read -p "Please input your GCP Project Name: " gcpProjectName
read -p "Please input your deployment prefix: " prefix
read -p "Please enter the name of the desired image (e.g. opsman-pcf-gcp-buildnumber): " imageName
read -p "Please enter the path to the image: " imagePath
echo "Please select a region where you want to install PCF:"
select region in "asia-east1" "asia-northeast1" "asia-south1" "asia-southeast1" "australia-southeast1" "europe-north1" "europe-west1" "europe-west2" "europe-west3" "europe-west4" "northamerica-northeast1" "southamerica-east1" "us-central1" "us-east1" "us-east4" "us-west1" "us-west2"
do

        case $region in
                asia-east1) regionSuffix="-asiae1";break;;
                asia-northeast1) regionSuffix="-asiane1";break;;
                asia-south1) regionSuffix="-asias1";break;;
                asia-southeast1) regionSuffix="-asiase1";break;;
                australia-southeast1) regionSuffix="-ausse1";break;;
                europe-west1) regionSuffix="-euwest1";break;;
                europe-west2) regionSuffix="-euwest2";break;;
                europe-west3) regionSuffix="-euwest3";break;;
                europe-west4) regionSuffix="-euwest4";break;;
                northamerica-northeast1) regionSuffix="-nane1";break;;
                southamerica-east1) regionSuffix="-saeast1";break;;
                us-central1) regionSuffix="-uscentral1";break;;
                us-east1) regionSuffix="-useast1";break;;
                us-east4) regionSuffix="-useast4";break;;
                us-west1) regionSuffix="-uswest1";break;;
                us-west2) regionSuffix="-uswest2";break;;
                *) echo "Please select a valid option!";;
        esac
done


# Compute all variables
imageUrl=$(printf "https://storage.googleapis.com/%s" $imagePath)
opsmanVmName=$(printf %s-opsman $prefix)
subnet=$(printf %s%s%s $prefix $infraSubnetSuffix $regionSuffix)
zone=$(printf %s-a $region)
boshServiceAccount=$(gcloud iam service-accounts list | grep bosh | awk {'print $2'})
opsmanInstanceTags=$(printf "%s-opsman,allow-https" prefix)

# Generate an image based on the release
echo
echo "Generating an image based on the release..."
gcloud compute --project=$gcpProjectName images create $imageName --source-uri=$imageUrl

#
# reserve the external IP address for OpsMan
echo
echo "Reserving an IP addresse (om-public-ip)..."
gcloud compute addresses create om-public-ip --region=$region
ipAddress=$(gcloud compute addresses list | grep om-public-ip | awk {'print $3'})
echo "IP Address reserved for om-public-ip: $ipAddress"

#
# Create the OpsMan VM with the static IP address
#
gcloud beta compute --project=$gcpProjectName instances create $opsmanVmName --zone=$zone --machine-type=custom-2-8192 --subnet=$subnet --private-network-ip=192.168.101.5 --address=$ipAddress --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=$boshServiceAccount --scopes=https://www.googleapis.com/auth/cloud-platform --tags=$opsmanInstanceTags --image=$imageName --image-project=$gcpProjectName --boot-disk-size=100GB --boot-disk-type=pd-standard --boot-disk-device-name=$opsmanVmName
