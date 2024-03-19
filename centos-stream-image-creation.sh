#!/bin/bash
set -ex
WORK_DIR=$(pwd)
# browse https://odcs.stream.centos.org/ to find a compose
COMPOSE_URL="${1-https://odcs.stream.centos.org/stream-10/production/latest-CentOS-Stream/compose/}"

COMPOSE_INFOFILE=composeinfo.json
curl -s -L ${COMPOSE_URL}/metadata/${COMPOSE_INFOFILE} -o ${COMPOSE_INFOFILE}
DATE=$(cat ${COMPOSE_INFOFILE} | jq .payload.compose.date | tr -d '"')
TYPE=$(cat ${COMPOSE_INFOFILE} | jq .payload.compose.type | tr -d '"')
RELEASE_NAME=$(cat ${COMPOSE_INFOFILE} | jq .payload.release.short | tr -d '"')
RELEASE_VERSION=$(cat ${COMPOSE_INFOFILE} | jq .payload.release.version | tr -d '"')
NAME="${RELEASE_NAME,,}-${RELEASE_VERSION}-${TYPE}-${DATE}"
rm ${COMPOSE_INFOFILE}

KS_FILE=centos-stream.ks
KS_TMP_FILE=${KS_FILE}.tmp
IMAGE_FILE=${NAME}.img
QCOW_IMAGE_FILE=${NAME}.qcow2
DISK_SIZE=10

cp ${KS_FILE} ${KS_TMP_FILE}
sed -i "s|COMPOSE_URL|${COMPOSE_URL}|" ${KS_TMP_FILE}

virt-install \
    --transient \
    --name=${NAME} \
    --ram=4096 \
    --arch=x86_64 \
    --cpu=host \
    --vcpus=4 \
    --os-variant=rhel9.0 \
    --initrd-inject="${KS_TMP_FILE}" \
    --extra-args="inst.ks=file:/${KS_TMP_FILE} console=tty0 console=ttyS0,115200 rd_NO_PLYMOUTH inst.noverifyssl" \
    --disk="${WORK_DIR}/${IMAGE_FILE},size=${DISK_SIZE},sparse=true,format=qcow2" \
    --location="${COMPOSE_URL}/BaseOS/x86_64/os" \
    --serial=pty \
    --nographics

virt-sysprep -a "${WORK_DIR}/${IMAGE_FILE}"
qemu-img convert -O qcow2 "${WORK_DIR}/${IMAGE_FILE}" "${WORK_DIR}/${QCOW_IMAGE_FILE}"

virt-install --name ${NAME} --ram 2048 --os-variant=rhel9.0 --disk ${IMAGE_FILE} --import
virsh console ${NAME}
