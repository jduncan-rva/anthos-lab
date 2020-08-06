#!/usr/bin/env bash
# Simple tool to deploy multiple Anthos clusters with ASM configured
# TODO:
# - dependency resolution (sdk pkgs)
# - clean up
# - multi-cluster meshes

source default.config

# Setting a few variables

PROJECT_NUMBER=$(gcloud projects describe $PROJECT --format="value(projectNumber)")
WORKLOAD_POOL=$PROJECT.svc.id.goog
MESH_ID="proj-$PROJECT_NUMBER"

# set gcloud variables
echo "Setting gcloud information"
gcloud config set project $PROJECT 
gcloud config set compute/zone $REGION

echo "Ensuring proper APIs are enabled"
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
  cloudresourcemanager.googleapis.com

# installing dependencies
sudo apt-get install \
  google-cloud-sdk \
  google-cloud-sdk-kpt \
  kubectl

# Read in cluster list
CLUSTERS=$(<$CLUSTER_LIST)

# Download the Istio installer and Signature
echo "Downloading ASM Resources" 
curl -LO https://storage.googleapis.com/gke-release/asm/istio-$ASM_VER-linux-amd64.tar.gz
curl -LO https://storage.googleapis.com/gke-release/asm/istio-$ASM_VER-linux-amd64.tar.gz.1.sig

# ASM Prep work
echo "Preparing for ASM Deploy"
curl --request POST --header "Authorization: Bearer $(gcloud auth print-access-token)" --data '' "https://meshconfig.googleapis.com/v1alpha1/projects/$PROJECT:initialize"

# Verify the signature of the downloaded files
echo "Verifying ASM Resources"
openssl dgst -verify - -signature istio-$ASM_VER-linux-amd64.tar.gz.1.sig istio-$ASM_VER-linux-amd64.tar.gz <<'EOF'
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWZrGCUaJJr1H8a36sG4UUoXvlXvZ
wQfk16sxprI2gOJ2vFFggdq3ixF2h4qNBt0kI7ciDhgpwS8t+/960IsIgw==
-----END PUBLIC KEY-----
EOF

FILE_VERIFICATION=$?

if [ $FILE_VERIFICATION -ne 0 ];then
    echo "ASM Resources do not pass verification check. Please Confirm and re-try."
    exit $FILE_VERIFICATION
fi

# Untar the Istio archive
echo "Untarring ASM Archive"
tar xzf istio-$ASM_VER-linux-amd64.tar.gz

echo "Updating PATH variable to include istioctl"
export PATH=$PWD/istio-$ASM_VER/bin:$PATH

for cluster in ${CLUSTERS[@]}
do
  echo "Creating and Configuring Service Account"
  ACCT=$cluster-sa 
  gcloud iam service-accounts create $ACCT --project $PROJECT --display-name $ACCT --description "Service Account for $ACCT Anthos cluster"
  gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$ACCT@$PROJECT.iam.gserviceaccount.com" --role="roles/gkehub.connect"
  gcloud projects add-iam-policy-binding $PROJECT \
    --member user:$GCP_EMAIL_ADDRESS \
    --role=roles/editor \
    --role=roles/compute.admin \
    --role=roles/container.admin \
    --role=roles/resourcemanager.projectIamAdmin \
    --role=roles/iam.serviceAccountAdmin \
    --role=roles/iam.serviceAccountKeyAdmin \
    --role=roles/gkehub.admin
  gcloud iam service-accounts keys create $ACCT.json --iam-account=$ACCT@$PROJECT.iam.gserviceaccount.com --project=$PROJECT

  echo "Creating $cluster GKE Cluster"
  gcloud beta container clusters create $cluster \
    --machine-type=e2-standard-4 \
    --num-nodes=4 \
    --workload-pool=$WORKLOAD_POOL \
    --enable-stackdriver-kubernetes \
    --subnetwork=default \
    --labels=mesh_id=$MESH_ID \
    --release-channel=regular
  gcloud container clusters get-credentials $cluster
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
  kubectl create namespace istio-system

  echo "Registering GKE Cluster with Anthos"
  gcloud container hub memberships register $cluster --project=$PROJECT --gke-uri=https://container.googleapis.com/projects/$PROJECT/locations/$REGION/clusters/$cluster --service-account-key-file=$ACCT.json

  echo "Deploying ASM into $cluster"
  kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-1.6-asm .
  kpt cfg set asm gcloud.container.cluster $cluster
  kpt cfg set asm gcloud.core.project $PROJECT
  kpt cfg set asm gcloud.compute.location $REGION
  istioctl install -f asm/cluster/istio-operator.yaml
done

