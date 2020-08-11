# used to cleanup artifacts created by ASM deployment
LOG_PREFIX="ASM_CLEANUP"

echo "$LOG_PREFIX: Cleaning up ASM filesystem artifacts"
rm -rf $DEPLOY_DIR/istio-$ASM_VER
rm -f $DEPLOY_DIR/istio-$ASM_VER-linux-amd64.tar.gz.1.sig
rm -f $DEPLOY_DIR/istio-$ASM_VER-linux-amd64.tar.gz
rm -rf $DEPLOY_DIR/asm 