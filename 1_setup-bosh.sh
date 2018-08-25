#!/bin/bash
echo
echo
echo "This script will set up most of the prerequisites for the installation of BOSH."
echo "It is aimed at simplifying the installation of a demo environment in Google Cloud. As such, it takes as input as little as possible and extrapolates variables from it."
echo "Prerequisite: be logged into your GCP Account and have the right project selected".
echo
echo

#
# Constants (can be modified to customize your script)
#
networkSuffix="-virt-net"
pasSubnetSuffix="-subnet-pas"
infraSubnetSuffix="-subnet-infrastructure"
servicesSubnetSuffix="-subnet-services"
pasSubnetRange="192.168.16.0/22"
infraSubnetRange="192.168.101.0/26"
servicesSubnetRange="192.168.20.0/22"
natSuffixGwPri="-nat-gateway-pri"
natSuffixGwSec="-nat-gateway-sec"
natSuffixGwTer="-nat-gateway-ter"
natSuffixPri="-nat-pri"
natSuffixSec="-nat-sec"
natSuffixTer="-nat-ter"
natPrivateIPPri=192.168.101.2
natPrivateIPSec=192.168.101.3
natPrivateIPTer=192.168.101.4

#
# Gather input data to extrapolate new variable names
#
read -p "Please input your GCP Project Name: " gcpProjectName

read -p "Please enter a prefix for your settings (ex: myinitials-pcf): " prefix

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

#
# Compute all variables based on arguments
#
gcpProjectId=$(gcloud projects describe $gcpProjectName | grep projectNumber | awk {'print $2'} | sed -e 's|["'\'']||g')
gcpServiceAccount="$gcpProjectId-compute@developer.gserviceaccount.com"
natInstanceTags="nat-traverse,$(printf "%s-nat-instance" $prefix)"

vpcName=$prefix$networkSuffix
pasSubnetName=$prefix$pasSubnetSuffix$regionSuffix
infraSubnetName=$prefix$infraSubnetSuffix$regionSuffix
servicesSubnetName=$prefix$servicesSubnetSuffix$regionSuffix
natPrimaryName=$prefix$natSuffixGwPri
natSecondaryName=$prefix$natSuffixGwSec
natTertiaryName=$prefix$natSuffixGwTer
regionA=$(printf "%s-a" "$region")
regionB=$(printf "%s-b" "$region")
regionC=$(printf "%s-c" "$region")

firewallRuleAllowSsh=$(printf "%s-allow-ssh" "$prefix")
firewallRuleAllowSshTargetTags="allow-ssh"

firewallRuleAllowHttp=$(printf "%s-allow-http" "$prefix")
firewallRuleAllowHttpTargetTags="allow-http,router"

firewallRuleAllowHttps=$(printf "%s-allow-https" "$prefix")
firewallRuleAllowHttpsTargetTags="allow-https,router"

firewallRuleAllowHttp8080=$(printf "%s-allow-http-8080" "$prefix")
firewallRuleAllowHttp8080TargetTags="router"

firewallRuleAllowPasAll=$(printf "%s-allow-pas-all" "$prefix")
firewallRuleAllowPasAllTargetTags=$(printf "%s,%s-opsman,nat-traverse" "$prefix" "$prefix")
firewallRuleAllowPasAllSourceTags=$(printf "%s,%s-opsman,nat-traverse" "$prefix" "$prefix")

firewallRuleAllowCfTcp=$(printf "%s-allow-cf-tcp" "$prefix")
firewallRuleAllowCfTcpTargetTags=$(printf "%s-cf-tcp" "$prefix")

firewallRuleAllowSshProxy=$(printf "%s-allow-ssh-proxy" "$prefix")
firewallRuleAllowSshProxyTargetTags=$(printf "%s-ssh-proxy,diego-brain" "$prefix")

#
# create a VPC and add 3 subnets in the same region
#
echo "1. Creating a VPC to host the subnets"
gcloud compute --project=$gcpProjectName networks create $vpcName --subnet-mode=custom

echo
echo
echo "2. Creating the 3 subnets for infrastructure, pas and services"
gcloud compute --project=$gcpProjectName networks subnets create $pasSubnetName --network=$vpcName --region=$region --range=$pasSubnetRange
gcloud compute --project=$gcpProjectName networks subnets create $infraSubnetName --network=$vpcName --region=$region --range=$infraSubnetRange
gcloud compute --project=$gcpProjectName networks subnets create $servicesSubnetName --network=$vpcName --region=$region --range=$servicesSubnetRange

echo
echo "3. Creating the NAT instances"
echo "Creating NAT Primary Gateway"
gcloud beta compute --project=$gcpProjectName instances create $natPrimaryName --zone=$regionA --machine-type=n1-standard-4 --subnet=$infraSubnetName --private-network-ip=$natPrivateIPPri --network-tier=PREMIUM --metadata=startup-script=\#\!\ /bin/bash$'\n'sudo\ sh\ -c\ \'echo\ 1\ \>\ /proc/sys/net/ipv4/ip_forward\'$'\n'sudo\ iptables\ -t\ nat\ -A\ POSTROUTING\ -o\ eth0\ -j\ MASQUERADE --can-ip-forward --maintenance-policy=MIGRATE --service-account=$gcpServiceAccount --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --tags=nat-traverse,nicolas-pcf-nat-instance --image=ubuntu-1404-trusty-v20180818 --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=$natPrimaryName

echo "Creating NAT Secondary Gateway"
gcloud beta compute --project=$gcpProjectName instances create $natSecondaryName --zone=$regionB --machine-type=n1-standard-4 --subnet=$infraSubnetName --private-network-ip=$natPrivateIPSec --network-tier=PREMIUM --metadata=startup-script=\#\!\ /bin/bash$'\n'sudo\ sh\ -c\ \'echo\ 1\ \>\ /proc/sys/net/ipv4/ip_forward\'$'\n'sudo\ iptables\ -t\ nat\ -A\ POSTROUTING\ -o\ eth0\ -j\ MASQUERADE --can-ip-forward --maintenance-policy=MIGRATE --service-account=$gcpServiceAccount --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --tags=nat-traverse,nicolas-pcf-nat-instance --image=ubuntu-1404-trusty-v20180818 --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=$natSecondaryName

echo "Creating NAT Tertiary Gateway"
gcloud beta compute --project=$gcpProjectName instances create $natTertiaryName --zone=$regionC --machine-type=n1-standard-4 --subnet=$infraSubnetName --private-network-ip=$natPrivateIPTer --network-tier=PREMIUM --metadata=startup-script=\#\!\ /bin/bash$'\n'sudo\ sh\ -c\ \'echo\ 1\ \>\ /proc/sys/net/ipv4/ip_forward\'$'\n'sudo\ iptables\ -t\ nat\ -A\ POSTROUTING\ -o\ eth0\ -j\ MASQUERADE --can-ip-forward --maintenance-policy=MIGRATE --service-account=$gcpServiceAccount --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --tags=nat-traverse,nicolas-pcf-nat-instance --image=ubuntu-1404-trusty-v20180818 --image-project=ubuntu-os-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=$natTertiaryName

#
# Create routes for NAT instances
#
echo
echo "4. Creating routes for NAT instances"
gcloud compute --project=$gcpProjectName routes create $prefix$natSuffixPri --network=$vpcName --priority=800 --tags=$prefix --destination-range=0.0.0.0/0 --next-hop-instance=$natPrimaryName --next-hop-instance-zone=$regionA

gcloud compute --project=$gcpProjectName routes create $prefix$natSuffixSec --network=$vpcName --priority=800 --tags=$prefix --destination-range=0.0.0.0/0 --next-hop-instance=$natSecondaryName --next-hop-instance-zone=$regionB

gcloud compute --project=$gcpProjectName routes create $prefix$natSuffixTer --network=$vpcName --priority=800 --tags=$prefix --destination-range=0.0.0.0/0 --next-hop-instance=$natTertiaryName --next-hop-instance-zone=$regionC

#
# Create firewal rules
#
echo
echo "5. Creating firewall rules"
gcloud compute --project=$gcpProjectName firewall-rules create $firewallRuleAllowSsh --direction=INGRESS --priority=1000 --network=$vpcName --action=ALLOW --rules=tcp:22 --source-ranges=0.0.0.0/0 --target-tags=$firewallRuleAllowSshTargetTags

gcloud compute --project=$gcpProjectName firewall-rules create $firewallRuleAllowHttp --direction=INGRESS --priority=1000 --network=$vpcName --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=$firewallRuleAllowHttpTargetTags

gcloud compute --project=$gcpProjectName firewall-rules create $firewallRuleAllowHttps --direction=INGRESS --priority=1000 --network=$vpcName --action=ALLOW --rules=tcp:443 --source-ranges=0.0.0.0/0 --target-tags=$firewallRuleAllowHttpsTargetTags

gcloud compute --project=$gcpProjectName firewall-rules create $firewallRuleAllowHttp8080 --direction=INGRESS --priority=1000 --network=$vpcName --action=ALLOW --rules=tcp:8080 --source-ranges=0.0.0.0/0 --target-tags=$firewallRuleAllowHttp8080TargetTags

gcloud compute --project=$gcpProjectName firewall-rules create $firewallRuleAllowPasAll --description=This\ rule\ allows\ communication\ between\ BOSH-deployed\ ERT\ jobs --direction=INGRESS --priority=1000 --network=$vpcName --action=ALLOW --rules=tcp,udp,icmp --source-tags=$firewallRuleAllowPasAllSourceTags --target-tags=$firewallRuleAllowPasAllTargetTags

gcloud compute --project=$gcpProjectName firewall-rules create $firewallRuleAllowCfTcp --description=This\ rule\ allows\ access\ to\ the\ TCP\ router --direction=INGRESS --priority=1000 --network=$vpcName --action=ALLOW --rules=tcp:1024-65535 --source-ranges=0.0.0.0/0 --target-tags=$firewallRuleAllowCfTcpTargetTags

gcloud compute --project=$gcpProjectName firewall-rules create $firewallRuleAllowSshProxy --description=This\ rule\ allows\ access\ to\ the\ SSH\ proxy --direction=INGRESS --priority=1000 --network=$vpcName --action=ALLOW --rules=tcp:2222 --source-ranges=0.0.0.0/0 --target-tags=$firewallRuleAllowSshProxyTargetTags


#
# Create the databases
#
echo
echo "6. Creating the SQL instances"
echo "No need for that for this demo system. We will keep everything internal."

#
# create the storage buckets
#
echo
echo "7. Creating the storage buckets"
buildpacksBucketName=$(printf %s-buildpacks $prefix)
gsutil mb -p $gcpProjectName -c "multi_regional" -l "eu" gs://$buildpacksBucketName 
dropletsBucketName=$(printf %s-droplets $prefix)
gsutil mb -p $gcpProjectName -c "multi_regional" -l "eu" gs://$dropletsBucketName
packagesBucketName=$(printf %s-packages $prefix)
gsutil mb -p $gcpProjectName -c "multi_regional" -l "eu" gs://$packagesBucketName
resourcesBucketName=$(printf %s-resources $prefix)
gsutil mb -p $gcpProjectName -c "multi_regional" -l "eu" gs://$resourcesBucketName

#
# create the HTTP Load Balancer
#
#echo
#echo "8. Creating the HTTP Load Balancer"
#echo "8.1. Creating the Instance Group"
#instanceName=$(printf %s-http-lb $prefix)
#gcloud compute --project=$gcpProjectName instance-groups unmanaged create $instanceName --zone=europe-west4-a
#gcloud compute --project=$gcpProjectName instance-groups unmanaged create $instanceName --zone=europe-west4-b
#gcloud compute --project=$gcpProjectName instance-groups unmanaged create $instanceName --zone=europe-west4-c

#echo "You will need to set the Virtual Network and PAS subnet to each instance manually the GCP UI as the CLI does not support assigning those to the instances yet."

#echo
#echo "8.2. Creating the Health Check"
#healthCfPublic=$(printf %s-cf-public $prefix)
#gcloud compute --project $gcpProjectName http-health-checks create $healthCfPublic --port "8080" --request-path "/health" --check-interval "30" --timeout "5" --unhealthy-threshold "2" --healthy-threshold "10"

#echo 
#echo "8.3. Configuring the Back-end"

#
# create the TCP WebSockets Load Balancer
#
#echo
#echo "9. Creating the TCP WebSockets Load Balancer"

#
# create the SSH Proxy Load Balancer
#
#echo
#echo "10. Creating the SSH Proxy Load Balancer"

#
# create the Load Balancer for the TCP Router
#
#echo
#echo "11. Creating the Load Balancer for the TCP Router"