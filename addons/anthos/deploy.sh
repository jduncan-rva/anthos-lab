# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function update_pkgs {
# installing dependencies if needed/desired
echo "$FUNCNAME: Checking for proper package dependencies (Linux)"
sudo apt-get install \
  google-cloud-sdk \
  google-cloud-sdk-kpt \
  kubectl \
  git \
  -qq
}
  
LOG_PREFIX="DEPLOY_GKE"
# Create deploy directory 
echo "$LOG_PREFIX: Creating deploy directory"
mkdir deploy

echo "$LOG_PREFIX: Ensuring proper APIs are enabled"
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
anthos.googleapis.com

if "$UPDATE_PKGS"; then
  update_pkgs
fi

for cluster in ${CLUSTERS[@]}
do
  echo "$LOG_PREFIX: Creating and Configuring Service Account"
  ACCT=$cluster-sa 
  gcloud iam service-accounts create $ACCT --project $PROJECT --display-name $ACCT --description "Service Account for $ACCT Anthos cluster" -q
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ACCT@$PROJECT.iam.gserviceaccount.com" --role="roles/gkehub.connect" -q
  gcloud projects add-iam-policy-binding $PROJECT \
    --member user:$GCP_EMAIL_ADDRESS \
    --role=roles/editor \
    --role=roles/compute.admin \
    --role=roles/container.admin \
    --role=roles/resourcemanager.projectIamAdmin \
    --role=roles/iam.serviceAccountAdmin \
    --role=roles/iam.serviceAccountKeyAdmin \
    --role=roles/gkehub.admin \
    -q
  gcloud iam service-accounts keys create deploy/$ACCT.json --iam-account=$ACCT@$PROJECT.iam.gserviceaccount.com --project=$PROJECT -q

  echo "$LOG_PREFIX: Creating GKE Cluster - $cluster"
  gcloud beta container clusters create $cluster \
    --scopes=cloud-platform \
    --machine-type=e2-standard-4 \
    --num-nodes=2 \
    --workload-pool=$WORKLOAD_POOL \
    --enable-stackdriver-kubernetes \
    --subnetwork=default \
    --labels=mesh_id=$MESH_ID \
    --release-channel=regular
  gcloud container clusters get-credentials $cluster
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
  kubectl create namespace istio-system

  echo "$LOG_PREFIX: Registering GKE Cluster with Anthos"
  gcloud container hub memberships register $cluster --project=$PROJECT --gke-uri=https://container.googleapis.com/projects/$PROJECT/locations/$REGION/clusters/$cluster --service-account-key-file=$DEPLOY_DIR/$ACCT.json
done