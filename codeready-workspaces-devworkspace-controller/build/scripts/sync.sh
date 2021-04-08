#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#
# convert devworkspace-operator upstream to downstream using yq, jq, sed & perl transforms, and deleting files

set -e

SCRIPTS_DIR=$(cd "$(dirname "$0")"; pwd)

# defaults
CSV_VERSION=2.y.0 # csv 2.y.0
CRW_VERSION=${CSV_VERSION%.*} # tag 2.y
UBI_TAG=8.3

UPDATE_VENDOR=1 # update the vendor folder via bootstrap.Dockerfile

usage () {
    echo "
Usage:   $0 -v [CRW CSV_VERSION] [-s /path/to/sources] [-t /path/to/generated]
Example: $0 -v 2.y.0 -s ${HOME}/projects/devworkspace-operator -t /tmp/devworkspace-controller
Options:
	--ubi-tag ${UBI_TAG}
	--no-vendor # don't rebuild the vendor folder
"
    exit
}

if [[ $# -lt 6 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    # for CSV_VERSION = 2.2.0, get CRW_VERSION = 2.2
    '-v') CSV_VERSION="$2"; CRW_VERSION="${CSV_VERSION%.*}"; shift 1;;
    # paths to use for input and ouput
    '-s') SOURCEDIR="$2"; SOURCEDIR="${SOURCEDIR%/}"; shift 1;;
    '-t') TARGETDIR="$2"; TARGETDIR="${TARGETDIR%/}"; shift 1;;
    '--no-vendor') UPDATE_VENDOR=0;;
    '--help'|'-h') usage;;
    # optional tag overrides
    '--ubi-tag') UBI_TAG="$2"; shift 1;;
  esac
  shift 1
done

if [ "${CSV_VERSION}" == "2.y.0" ]; then usage; fi

CRW_RRIO="registry.redhat.io/codeready-workspaces"
CRW_DWO_IMAGE="${CRW_RRIO}/devworkspace-controller-rhel8:${CRW_VERSION}"
CRW_MACHINEEXEC_IMAGE="${CRW_RRIO}/machineexec-rhel8:${CRW_VERSION}"
UBI_IMAGE="registry.redhat.io/ubi8/ubi-minimal:${UBI_TAG}"

# step one - build the builder image
BUILDER=$(command -v podman || true)
if [[ ! -x $BUILDER ]]; then
  echo "[WARNING] podman is not installed, trying with docker"
  BUILDER=$(command -v docker || true)
  if [[ ! -x $BUILDER ]]; then
      echo "[ERROR] must install docker or podman. Abort!"; exit 1
  fi
fi

pushd "${SOURCEDIR}" >/dev/null

# global / generic changes
echo ".github/
.git/
.gitignore
.gitattributes
" > /tmp/rsync-excludes
echo "Rsync ${SOURCEDIR} to ${TARGETDIR}"
rsync -azrlt --checksum --exclude-from /tmp/rsync-excludes ./* ${TARGETDIR}/
rm -f /tmp/rsync-excludes

# transform rhel.Dockefile -> Dockerfile
sed build/rhel.Dockerfile -r \
-e "s#FROM registry.redhat.io/#FROM #g" \
-e "s#FROM registry.access.redhat.com/#FROM #g" \
-e "s/(RUN go mod download$)/#\1/g" \
-e "s/# *RUN yum /RUN yum /g" \
> Dockerfile

if [[ ${UPDATE_VENDOR} -eq 1 ]]; then
    DOCKERFILELOCAL=bootstrap.Dockerfile
    cat build/rhel.Dockerfile | sed -r \
    `# CRW-1680 ignore vendor folder and fetch new content` \
    -e "s@(\ +)(.+go build)@\1go mod vendor \&\& go get -d -t -u \&\& \2@" \
    > ${DOCKERFILELOCAL}
    tag=$(pwd);tag=${tag##*/}
    ${BUILDER} build . -f ${DOCKERFILELOCAL} --target builder -t ${tag}:bootstrap
    rm -f ${DOCKERFILELOCAL}

    # step two - extract vendor folder to tarball
    ${BUILDER} run --rm --entrypoint sh ${tag}:bootstrap -c 'tar -pzcf - /devworkspace-operator/vendor' > "asset-vendor-$(uname -m).tgz"
    ${BUILDER} rmi ${tag}:bootstrap

    # step three - include that tarball's contents in this repo, under the vendor folder
    tar --strip-components=1 -xzf "asset-vendor-$(uname -m).tgz" 
    rm -f "asset-vendor-$(uname -m).tgz"

    git add vendor || true
fi

# header to reattach to yaml files after yq transform removes it
COPYRIGHT="#
#  Copyright (c) 2021 Red Hat, Inc.
#    This program and the accompanying materials are made
#    available under the terms of the Eclipse Public License 2.0
#    which is available at https://www.eclipse.org/legal/epl-2.0/
#
#  SPDX-License-Identifier: EPL-2.0
#
#  Contributors:
#    Red Hat, Inc. - initial API and implementation
"

# transform deployment yamls
    # - name: RELATED_IMAGE_devworkspace_webhook_server                         CRW_DWO_IMAGE
    #   value: quay.io/devfile/devworkspace-controller:next
    # - name: RELATED_IMAGE_plugin_redhat_developer_web_terminal_4_5_0          CRW_MACHINEEXEC_IMAGE
    #   value: quay.io/eclipse/che-machine-exec:nightly
    # - name: RELATED_IMAGE_web_terminal_tooling                            REMOVE
    #   value: quay.io/wto/web-terminal-tooling:latest
    # - name: RELATED_IMAGE_openshift_oauth_proxy                           REMOVE
    #   value: openshift/oauth-proxy:latest
    # - name: RELATED_IMAGE_default_tls_secrets_creation_job                REMOVE
    #   value: quay.io/eclipse/che-tls-secret-creator:alpine-3029769
    # - name: RELATED_IMAGE_pvc_cleanup_job                                     UBI_IMAGE
    #   value: quay.io/libpod/busybox:1.30.1
    # - name: RELATED_IMAGE_async_storage_server                            REMOVE
    #   value: quay.io/eclipse/che-workspace-data-sync-storage:0.0.1
    # - name: RELATED_IMAGE_async_storage_sidecar                           REMOVE
    #   value: quay.io/eclipse/che-sidecar-workspace-data-sync:0.0.1

    # image: quay.io/devfile/devworkspace-controller:next
declare -A operator_replacements=(
    ["RELATED_IMAGE_devworkspace_webhook_server"]="${CRW_DWO_IMAGE}"
    ["RELATED_IMAGE_plugin_redhat_developer_web_terminal_4_5_0"]="${CRW_MACHINEEXEC_IMAGE}"
    ["RELATED_IMAGE_pvc_cleanup_job"]="${UBI_IMAGE}"
)
while IFS= read -r -d '' d; do
    for updateName in "${!operator_replacements[@]}"; do
        changed="$(cat "${TARGETDIR}/${d}" | \
yq  -y --arg updateName "${updateName}" --arg updateVal "${operator_replacements[$updateName]}" \
'.spec.template.spec.containers[].env = [.spec.template.spec.containers[].env[] | if (.name == $updateName) then (.value = $updateVal) else . end]')" && \
        echo "${COPYRIGHT}${changed}" > "${TARGETDIR}/${d}"
    done
    if [[ $(diff -u "$d" "${TARGETDIR}/${d}") ]]; then
        echo "Converted (yq #1) ${d}"
    fi
done <   <(find deploy -type f -name "*Deployment.yaml" -print0)

declare -A operator_deletions=(
    ["RELATED_IMAGE_web_terminal_tooling"]=""
    ["RELATED_IMAGE_openshift_oauth_proxy"]=""
    ["RELATED_IMAGE_default_tls_secrets_creation_job"]=""
    ["RELATED_IMAGE_async_storage_server"]=""
    ["RELATED_IMAGE_async_storage_sidecar"]=""
)
while IFS= read -r -d '' d; do
    for updateName in "${!operator_deletions[@]}"; do
        changed="$(cat "${TARGETDIR}/${d}" | \
yq  -y --arg updateName "${updateName}" 'del(.spec.template.spec.containers[0].env[] | select(.name == "$updateName"))')" && \
        echo "${COPYRIGHT}${changed}" > "${TARGETDIR}/${d}"
    done
    if [[ $(diff -u "$d" "${TARGETDIR}/${d}") ]]; then
        echo "Converted (yq #2) ${d}"
    fi
done <   <(find deploy -type f -name "*Deployment.yaml" -print0)

    # sort env vars
    # while IFS= read -r -d '' d; do
    #     cat "${d}" | yq -Y '.spec.install.spec.deployments[].spec.template.spec.containers[].env |= sort_by(.name)' > "${d}.2"
    #     mv "${d}.2" "${d}"
    # done <   <(find deploy -type f -name "*Deployment.yaml" -print0)

popd >/dev/null || exit
