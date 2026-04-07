#!/bin/bash
set -e

IMAGE="bradlu4/ub2004-quecopen-v620-img:latest"
CONTAINER_NAME="ub2004-quecopen-v620-sdk"

HOST_USER=$(id -un)
HOST_UID=$(id -u)
HOST_GID=$(id -g)
HOST_GROUP=$(id -gn)

HOST_TEST_DIR="/home/${HOST_USER}/test"
HOST_DISK_DIR="/disk1/betty"

CONTAINER_TEST_DIR="/home/${HOST_USER}/test"
CONTAINER_DISK_DIR="/home/${HOST_USER}/disk1/betty"

echo "========== HOST INFO =========="
echo "USER        : $HOST_USER"
echo "UID         : $HOST_UID"
echo "GID         : $HOST_GID"
echo "GROUP       : $HOST_GROUP"
echo ""

echo "========== HOST DIR INFO =========="
echo "[TEST DIR] $HOST_TEST_DIR"
mkdir -p $HOST_TEST_DIR
ls -ld $HOST_TEST_DIR || echo "Not exist"
echo ""

echo "[DISK DIR] $HOST_DISK_DIR"
ls -ld $HOST_DISK_DIR || echo "Not exist"
echo ""

echo "========== DOCKER PULL =========="
docker pull $IMAGE

echo "========== RUN CONTAINER =========="

docker run -it --rm \
  -e LOCAL_UID=$HOST_UID \
  -e LOCAL_GID=$HOST_GID \
  -e LOCAL_USER=$HOST_USER \
  -e LOCAL_GROUP=$HOST_GROUP \
  -v $HOST_TEST_DIR:$CONTAINER_TEST_DIR \
  -v $HOST_DISK_DIR:$CONTAINER_DISK_DIR \
  --name $CONTAINER_NAME \
  $IMAGE \
  /bin/bash -c "

echo '========== CONTAINER INFO =========='
echo 'whoami        :' \$(whoami)
echo 'id            :' \$(id)
echo 'HOME          :' \$HOME
echo ''

echo '========== /etc/passwd =========='
grep \$(whoami) /etc/passwd || true
echo ''

echo '========== /etc/group =========='
grep \$(whoami) /etc/group || true
echo ''

echo '========== CONTAINER DIR INFO =========='

echo '[TEST DIR] $CONTAINER_TEST_DIR'
ls -ld $CONTAINER_TEST_DIR || echo 'Not exist'
echo ''

echo '[DISK DIR] $CONTAINER_DISK_DIR'
ls -ld $CONTAINER_DISK_DIR || echo 'Not exist'
echo ''

echo '========== FILE CREATE TEST =========='
touch $CONTAINER_TEST_DIR/testfile_from_container 2>/dev/null && echo 'Create OK' || echo 'Create FAILED'
ls -l $CONTAINER_TEST_DIR | tail -n 5
echo ''

echo '========== UID/GID CHECK =========='
stat -c '%n %u:%g' $CONTAINER_TEST_DIR 2>/dev/null || true
stat -c '%n %u:%g' $CONTAINER_DISK_DIR 2>/dev/null || true
echo ''

echo '========== DONE =========='
"

echo "========== AFTER CONTAINER (HOST CHECK) =========="
ls -l $HOST_TEST_DIR | tail -n 5 || true
echo ""

rm -rf $HOST_TEST_DIR
docker rmi $IMAGE
echo "========== DONE =========="
