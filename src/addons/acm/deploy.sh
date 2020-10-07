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

REPO_DIR=/opt/$REPO_DIR
FULL_REPO=$REPO_DIR/$REPO_NAME
# hack because arrays don't work inside the sdk container. wtf? 
cluster=$CLUSTERS

function deploy_repo {
  echo -e "${OC}  * Creating Cloud Source Repository${NC}"
  gcloud source repos create $REPO_NAME
  gcloud source repos clone $REPO_NAME $FULL_REPO
}

function configure_git {
  echo -e "${OC}  * Setting up git repository${NC}"
  git config --global credential.'https://source.developers.google.com'.helper gcloud.sh
  git config --global user.email $GCP_EMAIL_ADDRESS
  git config --global user.name $GIT_USERNAME
}

echo -e "\n\n${HC}------------------- ANTHOS CONFIG MANAGEMENT --------------------${NC}\n"

echo -e "${OC}  * Confirming ACM IAM Policies are in place${NC}"
# https://cloud.google.com/anthos-config-management/docs/how-to/installing#git-creds-gcenode

gcloud projects add-iam-policy-binding $PROJECT --member serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com --role roles/source.reader -q

gcloud iam service-accounts add-iam-policy-binding --role roles/iam.workloadIdentityUser --member "serviceAccount:$PROJECT.svc.id.goog[config-management-system/importer]" $PROJECT_NUMBER-compute@developer.gserviceaccount.com -q

echo -e "${OC}  * Configuring $cluster for ACM${NC}"
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml $DEPLOY_DIR/config-management-operator.yaml
cp addons/acm/config-management.yaml $DEPLOY_DIR/config-management-$cluster.yaml

# make the needed substitutions 
sed -i 's/CLUSTER/'"$cluster"'/' $DEPLOY_DIR/config-management-$cluster.yaml
sed -i 's/PROJECT/'"$PROJECT"'/' $DEPLOY_DIR/config-management-$cluster.yaml
sed -i 's/REPO_NAME/'"$REPO_NAME"'/' $DEPLOY_DIR/config-management-$cluster.yaml

echo -e "${OC}  * Applying ACM to $cluster ${NC}"
kubectl apply -f deploy/config-management-operator.yaml
kubectl apply -f deploy/config-management-$cluster.yaml

echo -e "${OC}  * Waiting for ACM to deploy (15 second delay)${NC}"
sleep 15
echo -e "${OC}  * Annotating Kubernetes Service Account${NC}"
kubectl annotate serviceaccount -n config-management-system importer iam.gke.io/gcp-service-account=$PROJECT_NUMBER-compute@developer.gserviceaccount.com

configure_git

deploy_repo

echo -e "${OC}  * Initializing $REPO_DIR as ACM repository${NC}"
nomos init --path=$FULL_REPO

echo -e "${OC}  * Committing ACM changes to git repository${NC}"
git -C $FULL_REPO add . 
git -C $FULL_REPO commit -a -m 'Intitial ACM Commit'
git -C $FULL_REPO push origin master

