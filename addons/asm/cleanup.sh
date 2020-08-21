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

# used to cleanup artifacts created by ASM deployment
LOG_PREFIX="ASM_CLEANUP"

echo "$LOG_PREFIX: Cleaning up ASM filesystem artifacts"
rm -rf $DEPLOY_DIR/istio-$ASM_VER
rm -f $DEPLOY_DIR/istio-$ASM_VER-linux-amd64.tar.gz.1.sig
rm -f $DEPLOY_DIR/istio-$ASM_VER-linux-amd64.tar.gz
rm -rf $DEPLOY_DIR/asm 