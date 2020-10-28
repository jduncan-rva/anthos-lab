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

for cluster in $CLUSTERS;do
  echo -e "${OC}  * Creating GKE cluster - $cluster ${NC}"
  gcloud beta container clusters create $cluster --scopes=cloud-platform --machine-type=e2-standard-4 --num-nodes=2 --workload-pool=$WORKLOAD_POOL --enable-stackdriver-kubernetes --subnetwork=default --labels=mesh_id=$MESH_ID --release-channel=regular

  echo -e "${OC}  * Getting Kubernetes credentials - $cluster ${NC}"
  gcloud container clusters get-credentials $cluster

  echo -e "${OC}  * Setting Kube Clusterrolebinding - $cluster ${NC}"
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
  kubectl create namespace istio-system

  echo -e "${OC}  * Registering GKE cluster with Anthos Hub - $cluster ${NC}"
  gcloud container hub memberships register $cluster --project=$PROJECT --gke-uri=https://container.googleapis.com/projects/$PROJECT/locations/$REGION/clusters/$cluster --service-account-key-file=anthos-lab-sa.json
done