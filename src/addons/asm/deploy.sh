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
# Add-on script to deploy ASM into clusters.

# ASM Prep work
echo -e "${OC}  * Ensuring proper tokens are present for meshconfig API${NC}"
curl --request POST --header "Authorization: Bearer $(gcloud auth print-access-token)" --data '' "https://meshconfig.googleapis.com/v1alpha1/projects/$PROJECT:initialize"

if [ -d "$DEPLOY_DIR/istio-$ASM_VER/" ];then 
  # this is mostly to not do this for every cluster in a loop
  echo -e "${OC}  * Istio binaries already downloaded${NC}"
else
  # Download the Istio installer and Signature
  echo -e "${OC}  * Downloading ASM Resources${NC}" 
  (cd $DEPLOY_DIR && curl -LO https://storage.googleapis.com/gke-release/asm/istio-$ASM_VER-linux-amd64.tar.gz)
  (cd $DEPLOY_DIR && curl -LO https://storage.googleapis.com/gke-release/asm/istio-$ASM_VER-linux-amd64.tar.gz.1.sig)
  
  # Verify the signature of the downloaded files
  echo -e "${OC}  * Verifying downloaded ASM resources${NC}"
  openssl dgst -verify addons/asm/asm.key -signature deploy/istio-$ASM_VER-linux-amd64.tar.gz.1.sig deploy/istio-$ASM_VER-linux-amd64.tar.gz
  
  FILE_VERIFICATION=$?
  
  if [ $FILE_VERIFICATION -ne 0 ];then
      echo -e "${EC}  * Downloaded files do not pass verification. Exiting${NC}"
      exit $FILE_VERIFICATION
  fi

  # Untar the Istio archive
  echo -e "${OC}  * Untarring ASM archive${NC}"
  tar -C $DEPLOY_DIR -xzf $DEPLOY_DIR/istio-$ASM_VER-linux-amd64.tar.gz
fi 

for cluster in "${CLUSTERS[@]}";do
  echo -e "${OC}  * Deploying ASM into $cluster"
  kpt pkg get https://github.com/GoogleCloudPlatform/anthos-service-mesh-packages.git/asm@release-1.6-asm $DEPLOY_DIR
  kpt cfg set $DEPLOY_DIR/asm gcloud.container.cluster $cluster
  kpt cfg set $DEPLOY_DIR/asm gcloud.core.project $PROJECT
  kpt cfg set $DEPLOY_DIR/asm gcloud.compute.location $REGION
  $DEPLOY_DIR/istio-$ASM_VER/bin/istioctl install -f $DEPLOY_DIR/asm/cluster/istio-operator.yaml
done