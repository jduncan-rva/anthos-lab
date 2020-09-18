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

# ensure config file exists
CONFIG_FILE=default.config 
if [ -f "$CONFIG_FILE" ]
then
  ACTION=$1
  source $CONFIG_FILE
else 
  echo -e "${EC}--- Error: Unable to load configuration file. ${NC}"
  echo -e "${EC}    Please make sure $PWD/$CONFIG_FILE exists. Exiting.\n${NC}"
  exit 1
fi

echo -e "\n\n${HC}------------------- PREFLIGHT CHECKS --------------------${NC}\n"

# Step 0 - make sure the SDK is installed
echo -e "${OC}  * Testing to insure the Google Cloud SDK is installed and available${NC}"

SDK=$(which gcloud)
if [ -f "$SDK" ]
then
  echo -e "${OC}  * SDK located at $SDK."
  echo -e "${OC}  * Google Cloud SDK is installed and available.${NC}"
else
  echo -e "${EC}  * Unable to locate Google Cloud SDK.${NC}"
  echo -e "${EC}  * Please refer to the documentation at https://cloud.google.com/sdk/install to remedy the issue and try again.${NC}"
  echo -e "${EC}  * Exiting.${NC}"
  exit 2
fi

# Step 0 part 2 - make sure docker is installed and running (optional)
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
      exit 3
    fi
else
  echo -e "${EC}  * Docker doesn't seem to be installed."
  echo -e "${EC}  * Please refer to documentation for your Operating System and remedy"
  echo -e "${EC}  * Exiting${NC}"
  exit 4
fi

echo -e "${OC}  * Checking current project${NC}"
CURR_PROJECT=$(gcloud config get-value project)
# we have initialized the SDK and we're in the desired project
if [ "$CURR_PROJECT" = "$PROJECT" ];then
  echo -e "${OC}  * Already using project $CURR_PROJECT ${NC}"
  echo -e "${OC}  * Checking current Region${NC}"
  CURR_REGION=$(gcloud config get-value compute/region)
  if [ "$CURR_REGION" = "$REGION" ];then 
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

echo -e "${OC}  * Ensuring needed APIs are enabled ${NC}"

gcloud services enable \
container.googleapis.com \
compute.googleapis.com \
monitoring.googleapis.com \
logging.googleapis.com \
cloudtrace.googleapis.com \
meshca.googleapis.com \
meshtelemetry.googleapis.com \
meshconfig.googleapis.com \
iamcredentials.googleapis.com \
anthos.googleapis.com \
gkeconnect.googleapis.com \
gkehub.googleapis.com \
cloudresourcemanager.googleapis.com \
anthos.googleapis.com > /dev/null

# service account key verification
SA_EXISTS=$(gcloud iam service-accounts list | egrep "^$SERVICE_ACCT\ .*" | wc -l)

if [ "$SA_EXISTS" -gt 0 ];then
  #a service account with the desired name already exists. 
  # we won't try to re-create it
  echo -e "${OC}  * Service Account already exists. Continuing. ${NC}"
else 
  echo -e "${OC}  * Creating Service Account $SERVICE_ACCT${NC}"
  gcloud iam service-accounts create $SERVICE_ACCT --project $PROJECT --display-name $SERVICE_ACCT --description "Service Account for Anthos Lab Container Deployment" > /dev/null

  echo -e "${OC}  * Applying role bindings for Service Account $SERVICE_ACCT${NC}"
  gcloud projects add-iam-policy-binding $PROJECT --member serviceAccount:$SERVICE_ACCT@$PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null
fi

# service account key verification
if [ -f $SERVICE_ACCT.json ];then 
  echo -e "${OC}  * Account Key Present - $SERVICE_ACCT.json Continuing.${NC}"
else 
  echo -e "${OC}  * Creating account keys for Service Account $SERVICE_ACCT${NC}"

  gcloud iam service-accounts keys create $SERVICE_ACCT.json \
  --iam-account=$SERVICE_ACCT@$PROJECT.iam.gserviceaccount.com \
  --project=$PROJECT > /dev/null
fi

echo -e "${OC}  * Service Account Configuration Complete. Moving on to $ACTION${NC}"

# deploy tasks
if [ $ACTION == 'deploy' ];then

  echo -e "${OC}  * Preparing for ACM configuration${NC}"

  # acm repos in the filesystem
  if [ -d $HOME/$REPO_DIR ];then
    echo -e "${OC}  * ACM repository directory exists. Cleaning it out to start fresh.${NC}"
    rm -rf $HOME/$REPO_DIR > /dev/null
    mkdir $HOME/$REPO_DIR > /dev/null
  else 
    echo -e "${OC}  * Creating ACM repository directory.${NC}"
    mkdir $HOME/$REPO_DIR > /dev/null
  fi

  # nomos configuration
  if [ -f $HOME/nomos ];then 
    echo -e "${OC}  * nomos present at $HOME/nomos. Continuing. ${NC}"
  else 
    echo -e "${OC}  * Installing nomos ACM tool at $HOME/nomos. ${NC}"
    echo -e "${OC}  * You can use nomos after deploying to manage ACM.${NC}"
    if [[ $OSTYPE == "darwin"* ]];then
      gsutil cp gs://config-management-release/released/latest/darwin_amd64/nomos $HOME/nomos 
    fi
    if [[ $OSTYPE == "linux"* ]];then
      gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos $HOME/nomos
    fi
    chmod +x $HOME/nomos
  fi

  echo -e "${OC}  * Preflight checks complete. Continuing to deployment. ${NC}"

  docker run -it -e ACTION=$ACTION --env-file=$(pwd)/default.config \
   -v $(pwd)/$SERVICE_ACCT.json:/opt/$SERVICE_ACCT.json \
   -v $HOME/$REPO_DIR:/opt/$REPO_DIR \
   -v $HOME/deploy:/opt/deploy anthos-lab

  echo -e "\n\n${HC}------------------- CLUSTER INFORMATION --------------------${NC}\n"

  gcloud container clusters list --filter="name:$CLUSTERS" --format="[box]"
  echo -e "${OC}  * Generating kubeconfig entry for cluster.${NC}"
  gcloud container clusters get-credentials $CLUSTERS
  echo -e "${OC}  * Current ACM status. Not this may take a few minutes to show proper status.${NC}"
  $HOME/nomos status
fi

# cleanup tasks
if [ $ACTION == 'cleanup' ];then 
  rm -rf $HOME/deploy 
  rm -rf $HOME/$REPO_NAME

  docker run -it -e ACTION=$ACTION --env-file=$(pwd)/default.config \
    -v $(pwd)/$SERVICE_ACCT.json:/opt/$SERVICE_ACCT.json \
    anthos-lab
fi

