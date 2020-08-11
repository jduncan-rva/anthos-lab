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