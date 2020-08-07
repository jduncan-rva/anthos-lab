#!/usr/bin/env bash
# Simple tool to deploy multiple Anthos clusters with ASM configured
# TODO:
# - dependency resolution (sdk pkgs)
# - clean up
# - multi-cluster meshes

ACTION=$1

ASM_KEY="-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWZrGCUaJJr1H8a36sG4UUoXvlXvZ
wQfk16sxprI2gOJ2vFFggdq3ixF2h4qNBt0kI7ciDhgpwS8t+/960IsIgw==
-----END PUBLIC KEY-----"

function prep {
  source default.config

  # Setting a few variables

  PROJECT_NUMBER=$(gcloud projects describe $PROJECT --format="value(projectNumber)")
  WORKLOAD_POOL=$PROJECT.svc.id.goog
  MESH_ID="proj-$PROJECT_NUMBER"
  REPO_DIR=anthos-lab-acm 

  # set gcloud variables
  echo "Setting gcloud information"
  gcloud config set project $PROJECT 
  gcloud config set compute/zone $REGION

  # Read in cluster list
  CLUSTERS=$(<$CLUSTER_LIST)
}

function deploy_asm {

  if [-d "istio-$ASM_VER/"];then 
    # this is mostly to not do this for every cluster in a loop
    echo "ASM Resources already present"
  else
    # Download the Istio installer and Signature
    echo "Downloading ASM Resources" 
    curl -LO https://storage.googleapis.com/gke-release/asm/istio-$ASM_VER-linux-amd64.tar.gz
    curl -LO https://storage.googleapis.com/gke-release/asm/istio-$ASM_VER-linux-amd64.tar.gz.1.sig
    
    # Verify the signature of the downloaded files
    echo "Verifying ASM Resources"
    openssl dgst -verify asm.key -signature istio-$ASM_VER-linux-amd64.tar.gz.1.sig istio-$ASM_VER-linux-amd64.tar.gz
    
    # ASM Prep work
    echo "Preparing for ASM Deploy"
    curl --request POST --header "Authorization: Bearer $(gcloud auth print-access-token)" --data '' "https://meshconfig.googleapis.com/v1alpha1/projects/$PROJECT:initialize"
    
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
  fi 

  echo "Deploying ASM into $cluster"
  kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-1.6-asm .
  kpt cfg set asm gcloud.container.cluster $cluster
  kpt cfg set asm gcloud.core.project $PROJECT
  kpt cfg set asm gcloud.compute.location $REGION
  istioctl install -f asm/cluster/istio-operator.yaml
}

function deploy_repo {
  echo "Creating Cloud Source Repository"
  git config --global credential.'https://source.developers.google.com'.helper gcloud.sh
  gcloud source repos create $REPO_DIR 
  gcloud source repos clone $REPO_DIR 
}

function configure_git {
  git config --global name "Anthos Lab"
  git config --globel email "$GCP_EMAIL_ADDRESS"
}

function deploy_acm {
  echo "Configuring cluster for Anthos Configuration Management"
  gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator.yaml
  cp addons/acm/config-management.yaml ./config-management-$cluster.yaml

  # make the needed substitutions 
  sed -i 's/CLUSTER/'"$cluster"'/' config-management-$cluster.yaml
  sed -i 's/PROJECT/'"$PROJECT"'/' config-management-$cluster.yaml
  sed -i 's/REPO_DIR/'"$REPO_DIR"'/' config-management-$cluster.yaml

  echo "Applying ACM to $cluster"
  kubectl apply -f config-management-operator-$cluster.yaml

  echo "Installing nomos"
  gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos nomos
  chmod +x ./nomos

  echo "Initializing $REPO_DIR as ACM repository"
  ./nomos init --path=$REPO_DIR
  configure_git

  echo "Committing configuration to Git"
  git -C $REPO_DIR add . 
  git -C $REPO_DIR commit -a -m 'Intitial ACM Commit'
  git -C $REPO_DIR push origin master
}

function install_addons {
  if "$DEPLOY_ASM"; then
    deploy_asm
  fi
  if "$DEPLOY_ACM"; then
    deploy_acm
  fi 
}

function update_pkgs {
  # installing dependencies if needed/desired
  echo "Checking for proper package dependencies (Linux)"
  sudo apt-get install \
    google-cloud-sdk \
    google-cloud-sdk-kpt \
    kubectl \
    git
}

function deploy {
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
    cloudresourcemanager.googleapis.com \
    anthos.googleapis.com

  if "$UPDATE_PKGS"; then
    update_pkgs
  fi

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
    
    install_addons
  done
}

function cleanup_filesystem {
  echo "Cleaning up filesystem artifacts"
  rm -rf asm
  rm -rf istio*
  rm -f *-sa.json
  rm -f config-management-*.yaml
  rm -f nomos 
  rm -rf $REPO_DIR 
}

function cleanup_gcp {
  for cluster in ${CLUSTERS[@]}
    do
    echo "Cleaning up cluster $cluster"
    gcloud iam service-accounts delete $cluster-sa@$PROJECT.iam.gserviceaccount.com -q
    gcloud container hub memberships delete $cluster -q
    gcloud container clusters delete $cluster -q
    if $DEPLOY_ACM;then 
      gcloud source repos delete $REPO_DIR -q
    fi
  done
}

case $ACTION in

  deploy) 
    prep
    deploy
  ;;

  cleanup)
    prep
    cleanup_filesystem
    cleanup_gcp
  ;;

  redeploy)
    prep
    cleanup_filesystem
    cleanup_gcp
    deploy
  ;;

  cleanupfs)
    prep
    cleanup_filesystem
  ;;

  cleanupgcp)
    prep
    cleanup_gcp
  ;;

  *)
    echo "USAGE: $0 [cleanup|cleanupfs|cleanupgcp|deploy|redeploy]"
  ;;

esac
