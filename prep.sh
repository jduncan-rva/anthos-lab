#!/usr/bin/env bash
# 
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# anthos-lab/prep.sh
# This script helps configure your gcloud environment to deploy your Anthos lab.
# It will create a service account with the proper role bindings and also create
# a key for the containerized application to use 

# header color 
HC='\033[0;32m'
# output color
OC='\033[0;34m'
# error color
EC='\033[1;31m'
# turn off forced color
NC='\033[0m'

source cfg/default.config

echo -e "\n\n${HC}------------------- PREREQUISITES --------------------${NC}\n"
# Step 0 - make sure the SDK is installed
echo -e "${OC}--- Testing to insure the Google Cloud SDK is installed and available\n${NC}"

SDK=$(which gcloud)
if [ -f "$SDK" ]
then
  echo -e "${OC}  * SDK located at $SDK"
  echo -e "${OC}  * Google Cloud SDK is installed and available\n\n${NC}"
else
  echo -e "${EC}  * Unable to locate Google Cloud SDK${NC}"
  echo -e "${EC}  * Please refer to the documentation at https://cloud.google.com/sdk/install to remedy the issue and try again${NC}"
  echo -e "${EC}  * Exiting${NC}"
  exit 1
fi

# Step 0 part 2 - make sure docker is installed and running (optional)
# This is only executed if you set CONTAINERIZE to `true` in your config file.
# This is useful on a Macbook where there are LibreSSL compatbility issues
if [ $CONTAINERIZE = 'true' ]
then
  echo -e "${OC}--- You've decided to run this in a container\n"
  echo -e "  * Making sure there's a container runtime available for use."
  echo -e "  * NOTE: This currrently works for Docker. Other runtimes may be supported in the future.${NC}"

  DOCKER=$(which docker)
  if [ -f "$DOCKER" ]
  then 
    echo -e "${OC}  * Docker runtime found at $DOCKER"
    DOCKER_CHECK=$(docker version | grep 'Cannot connect' | wc -l)
      if [ "$DOCKER_CHECK" -eq 0 ]
      then
        echo -e "${OC}  * Docker seems to be running. Ready to proceed${NC}"
      else 
        echo -e "${EC}  * Docker doesn't appear to be running. Please verify and re-run"
        echo -e "${EC}  * Exiting${NC}"
        exit 126
      fi
  else
    echo -e "${EC}  * Docker doesn't seem to be installed."
    echo -e "${EC}  * Please refer to documentation for your Operating System and remedy"
    echo -e "${EC}  * Exiting${NC}"
    exit 127
  fi
fi

echo -e "\n${OC}Prerequisites Complete. Proceeding to SDK Configuration${NC}\n"

echo -e "${HC}------------------- SDK CONFIGURATION --------------------${NC}\n"

echo -e "${OC}--- Initalizing SDK${NC}\n"
echo -e "${OC}  * Checking current project${NC}"
CURR_PROJECT=$(gcloud config get-value project)
# we have initialized the SDK and we're in the desired project
if [ "$CURR_PROJECT" = "$PROJECT" ]
then
  echo -e "${OC}  * Already using project $CURR_PROJECT ${NC}"
  echo -e "${OC}  * Checking current Region${NC}"
  CURR_REGION=$(gcloud config get-value compute/region)
  if [ "$CURR_REGION" = "$REGION" ]
  then 
    echo -e "${OC}  * Already using region $CURR_REGION${NC}"
  else 
    echo -e "${OC}  * Setting region to $REGION${NC}"
    gcloud config set compute/region $REGION
  fi
# we're assuming the value is unset here, so we'll run gcloud init
# this will catch any missing values
else 
  echo -e "${OC}  * No project set, running SDK initialization${NC}"
  gcloud init
fi

echo -e "\n${OC}SDK Initialization Complete. Proceeding to Service Account Creation${NC}\n"

echo -e "${HC}------------------- SERVICE ACCOUNT CONFIGURATION --------------------${NC}\n"

SERVICE_ACCT="anthos-lab-sa"
echo -e "${OC}  * Creating Service Account $SERVICE_ACCT${NC}"
gcloud iam service-accounts create $SERVICE_ACCT --project $PROJECT --display-name $SERVICE_ACCT --description "Service Account for Anthos Lab Container Deployment"

echo -e "${OC}  * Applying role bindings for Service Account $SERVICE_ACCT${NC}"
gcloud projects add-iam-policy-binding $PROJECT --member serviceAccount:$SERVICE_ACCT@$PROJECT.iam.gserviceaccount.com \
 --role=roles/gkehub.connect \
 --role=roles/editor \
 --role=roles/compute.admin \
 --role=roles/container.admin \
 --role=roles/resourcemanager.projectIamAdmin \
 --role=roles/iam.serviceAccountAdmin \
 --role=roles/iam.serviceAccountKeyAdmin \
 --role=roles/gkehub.admin -q

echo -e "${OC}  * Creating account keys for Service Account $SERVICE_ACCT${NC}"
gcloud iam service-accounts keys create $SERVICE_ACCT.json \
 --iam-account=$SERVICE_ACCT@$PROJECT.iam.gserviceaccount.com \
 --project=$PROJECT

echo -e "${OC}Service Account Configuration Complete. Moving on to Deployment${NC}"

echo -e "\n${HC}------------------- ANTHOS LAB DEPLOYMENT --------------------${NC}\n"

