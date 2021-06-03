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
# convert che-machine-exec upstream to crw-machineexec downstream using sed

set -e

SCRIPTS_DIR=$(cd "$(dirname "$0")"; pwd)

# defaults
CSV_VERSION=2.y.0 # csv 2.y.0
CRW_VERSION=${CSV_VERSION%.*} # tag 2.y

usage () {
    echo "
Usage:   $0 -v [CRW CSV_VERSION] [-s /path/to/che-machine-exec] [-t /path/to/generated]
Example: $0 -v 2.y.0 -s ${HOME}/projects/che-machine-exec -t /tmp/crw-machineexec"
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
    '--help'|'-h') usage;;
  esac
  shift 1
done

if [[ ! -d "${SOURCEDIR}" ]]; then usage; fi
if [[ ! -d "${TARGETDIR}" ]]; then usage; fi
if [[ "${CSV_VERSION}" == "2.y.0" ]]; then usage; fi

# global / generic changes
echo ".github/
.git/
.gitattributes
build/scripts/sync.sh
/container.yaml
/content_sets.*
/cvp.yml
get-sources-jenkins.sh
tests/basic-test.yaml
sources
/Dockerfile
RELEASE.md
make-release.sh
.dockerignore
" > /tmp/rsync-excludes
echo "Rsync ${SOURCEDIR} to ${TARGETDIR}"
rsync -azrlt --checksum --exclude-from /tmp/rsync-excludes --delete ${SOURCEDIR}/ ${TARGETDIR}/
rm -f /tmp/rsync-excludes

# ensure shell scripts are executable
find ${TARGETDIR}/ -name "*.sh" -exec chmod +x {} \;

sed ${SOURCEDIR}/build/dockerfiles/rhel.Dockerfile -r \
    `# Replace ubi8 with rhel8 version` \
    -e "s#ubi8/go-toolset#rhel8/go-toolset#g" \
    `# more replacements` \
    -e "s#FROM registry.redhat.io/#FROM #g" \
    -e "s#FROM registry.access.redhat.com/#FROM #g" \
> ${TARGETDIR}/Dockerfile
cat << EOT >> ${TARGETDIR}/Dockerfile
ENV SUMMARY="Red Hat CodeReady Workspaces machineexec container" \\
    DESCRIPTION="Red Hat CodeReady Workspaces machineexec container" \\
    PRODNAME="codeready-workspaces" \\
    COMPNAME="machineexec-rhel8"
LABEL summary="\$SUMMARY" \\
      description="\$DESCRIPTION" \\
      io.k8s.description="\$DESCRIPTION" \\
      io.k8s.display-name="\$DESCRIPTION" \\
      io.openshift.tags="\$PRODNAME,\$COMPNAME" \\
      com.redhat.component="\$PRODNAME-\$COMPNAME-container" \\
      name="\$PRODNAME/\$COMPNAME" \\
      version="${CRW_VERSION}" \\
      license="EPLv2" \\
      maintainer="Anatolii Bazko <abazko@redhat.com>, Nick Boldt <nboldt@redhat.com>" \\
      io.openshift.expose-services="" \\
      usage=""
EOT
echo "Converted Dockerfile"

# add ignore for the tarballs in mid and downstream
echo "/codeready-workspaces-sleep*.gz" >> ${TARGETDIR}/.gitignore
echo "Adjusted .gitignore"
