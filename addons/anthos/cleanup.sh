echo "$FUNCNAME: Cleaning up core filesystem artifacts"
rm -f $DEPLOY_DIR/$ACCT.json
rm -rf $DEPLOY_DIR


for cluster in ${CLUSTERS[@]};do
  echo "$FUNCNAME: Cleaning up cluster $cluster"
  gcloud iam service-accounts delete $cluster-sa@$PROJECT.iam.gserviceaccount.com -q
  gcloud container hub memberships delete $cluster -q
  gcloud container clusters delete $cluster -q
done