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
# cleans up artifacts created in GCP and on the filesystem to deploy ACM
LOG_PREFIX="CLEANUP_ACM"

echo "$LOG_PREFIX: Cleaning up ACM filesystem artifacts"
rm -rf $REPO_DIR
rm -f $DEPLOY_DIR/config-management-operator.yaml
rm -f $DEPLOY_DIR/config-management-$cluster.yaml
rm -rf $DEPLOY_DIR/nomos

echo "$LOG_PREFIX: Cleaning up ACM GCP artifacts"
gcloud source repos delete $REPO_NAME -q
gcloud projects remove-iam-policy-binding $PROJECT --member serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com --role roles/source.reader