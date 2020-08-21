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
#
# Script used to deploy Anthos Config Management (ACM) into Anthos clusters
LOG_PREFIX="DEPLOY_ACM"

function deploy_repo {
  echo "Creating Cloud Source Repository"
  gcloud source repos create $REPO_NAME
  gcloud source repos clone $REPO_NAME $REPO_DIR
}

function configure_git {
  echo "$LOG_PREFIX: Setting up git to interact with ACM"
  git config --global credential.'https://source.developers.google.com'.helper gcloud.sh
  echo "$LOG_PREFIX: Creating ACM Repository"
  git -C $REPO_DIR init
  git -C $REPO_DIR remote add origin https://source.developers.google.com/p/$PROJECT/r/$REPO_NAME
}

echo "$LOG_PREFIX: Ensuring ACM-related IAM policies are in place"
# https://cloud.google.com/anthos-config-management/docs/how-to/installing#git-creds-gcenode

gcloud projects add-iam-policy-binding $PROJECT --member serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com --role roles/source.reader -q

gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:$PROJECT.svc.id.goog[config-management-system/importer]" $PROJECT_NUMBER-compute@developer.gserviceaccount.com -q

echo "$LOG_PREFIX: Configuring cluster for Anthos Configuration Management"
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml $DEPLOY_DIR/config-management-operator.yaml
cp addons/acm/config-management.yaml $DEPLOY_DIR/config-management-$cluster.yaml

# make the needed substitutions 
sed -i 's/CLUSTER/'"$cluster"'/' $DEPLOY_DIR/config-management-$cluster.yaml
sed -i 's/PROJECT/'"$PROJECT"'/' $DEPLOY_DIR/config-management-$cluster.yaml
sed -i 's/REPO_NAME/'"$REPO_NAME"'/' $DEPLOY_DIR/config-management-$cluster.yaml

echo "$LOG_PREFIX: Applying ACM to $cluster"
kubectl apply -f deploy/config-management-operator.yaml
kubectl apply -f deploy/config-management-$cluster.yaml

echo "$LOG_PREFIX: Waiting for ACM CRD to deploy"
sleep 15
echo "$LOG_PREFIX: Annotating Kubernetes Service Account"
kubectl annotate serviceaccount -n config-management-system importer iam.gke.io/gcp-service-account=$PROJECT_NUMBER-compute@developer.gserviceaccount.com

echo "$LOG_PREFIX: Installing nomos"
gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos $DEPLOY_DIR/nomos
chmod +x $DEPLOY_DIR/nomos

deploy_repo

configure_git

echo "$LOG_PREFIX: Initializing $REPO_DIR as ACM repository"
$DEPLOY_DIR/nomos init --path=$REPO_DIR

echo "$LOG_PREFIX: Committing configuration to Git"
git -C $REPO_DIR add . 
git -C $REPO_DIR commit -a -m 'Intitial ACM Commit'
git -C $REPO_DIR push origin master

