# Copyright (c) 2020 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/ubi8-minimal
FROM ubi8-minimal:8.4-200.1622548483

USER root

ENV HOME=/home/jboss \
    NODEJS_VERSION=12 \
    MAVEN_VERSION="3.6.3" \
    LOMBOK_VERSION="1.18.18" \
    PYTHON_VERSION="3.8" \
    JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:/opt/app-root/src/.npm-global/bin/:/usr/lib/jvm/java-1.8.0-openjdk:/opt/apache-maven/bin:/usr/bin:$PATH \
    MANPATH="/usr/share/man:${MANPATH}" \
    JAVACONFDIRS="/etc/java${JAVACONFDIRS:+:}${JAVACONFDIRS:-}" \
    XDG_CONFIG_DIRS="/etc/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}" \
    XDG_DATA_DIRS="/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    M2_HOME="/opt/apache-maven"

# built in Brew, use get-sources-jenkins.sh to pull latest
COPY . /tmp/assets/
COPY lombok-${LOMBOK_VERSION}.jar /lombok.jar

# NOTE: uncomment for local build. Must also set full registry path in FROM to registry.redhat.io
# COPY content_set*.repo /etc/yum.repos.d/

# For OpenShift Client 4 (oc): rhocp-4.7-for-rhel-8-x86_64-rpms
# must hard code a version because otherwise we fail with
## Failed component comparison for components: openshift-clients
# http://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/x86_64/rhocp/4.7/os/Packages/o/openshift-clients-4.7.0-202106032231.p0.git.e29b355.el8.x86_64.rpm
# http://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/s390x/rhocp/4.7/os/Packages/o/openshift-clients-4.7.0-202106032231.p0.git.e29b355.el8.s390x.rpm
# http://rhsm-pulp.corp.redhat.com/content/dist/layered/rhel8/ppc64le/rhocp/4.7/os/Packages/o/openshift-clients-4.7.0-202106032231.p0.git.e29b355.el8.ppc64le.rpm
RUN microdnf -y install yum && \
    yum -y -q install bash tar gzip unzip which shadow-utils findutils wget curl openshift-clients-4.7.0-202106032231.p0.git.e29b355.el8 \
    java-1.8.0-openjdk java-1.8.0-openjdk-devel java-1.8.0-openjdk-headless \
    # CRW-919 java8/mvn + python/pip + node/npm: combine forces and make one all-in-one useful image
    sudo git procps-ng bzip2 && \
    # BEGIN copy from https://catalog.redhat.com/software/containers/ubi8/nodejs-12/5d3fff015a13461f5fb8635a?container-tabs=dockerfile
        yum -y -q module reset nodejs && \
        yum -y -q module enable nodejs:$NODEJS_VERSION && \
        INSTALL_PKGS="nodejs npm nodejs-nodemon nss_wrapper" && ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
        yum -y -q remove $INSTALL_PKGS && \
        yum -y -q install --setopt=tsflags=nodocs $INSTALL_PKGS && rpm -V $INSTALL_PKGS && \
        yum -y -q clean all --enablerepo='*' && \
    # END copy from https://catalog.redhat.com/software/containers/ubi8/nodejs-12/5d3fff015a13461f5fb8635a?container-tabs=dockerfile
    # BEGIN update to python 3.8 per https://catalog.redhat.com/software/containers/ubi8/python-38/5dde9cacbed8bd164a0af24a?container-tabs=dockerfile
        yum -y -q module reset python38 && \
        yum -y -q module enable python38:${PYTHON_VERSION} && \
        yum -y -q install python38 python38-devel python38-setuptools python38-pip && \
    # END update to python 3.8 per https://catalog.redhat.com/software/containers/ubi8/python-38/5dde9cacbed8bd164a0af24a?container-tabs=dockerfile
    # CVE updates
    yum -y -q update && \
    yum -y -q clean all && rm -rf /var/cache/yum && \
    # TODO: why do we need this jboss user?
    useradd -u 1000 -G wheel,root -d ${HOME} --shell /bin/bash -m jboss && \
    mkdir -p ${HOME}/che /projects && \
    for f in "${HOME}" "/etc/passwd" "/etc/group" "/projects"; do \
        chgrp -R 0 ${f} && \
        chmod -R g+rwX ${f}; \
    done && \
    # Generate passwd.template \
    cat /etc/passwd | \
    sed s#jboss:x.*#jboss:x:\${USER_ID}:\${GROUP_ID}::\${HOME}:/bin/bash#g \
    > ${HOME}/passwd.template && \
    # Generate group.template \
    cat /etc/group | \
    sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g \
    > ${HOME}/group.template && \
    echo "jboss	ALL=(ALL)	NOPASSWD: ALL" >> /etc/sudoers && \
    \
    # maven stuff \
    mkdir -p /opt; \
    tar xzf /tmp/assets/apache-maven-${MAVEN_VERSION}-bin.tar.gz -C /opt && \
    mv /opt/apache-maven-${MAVEN_VERSION} /opt/apache-maven && \
    rm -f /tmp/assets/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    # fix permissions in bin/* files \
    for d in $(find /opt/apache-maven -name bin -type d); do echo $d; chmod +x $d/*; done && \
    \
    # additional node stuff \
    mkdir -p ${HOME}/lang-server /opt/app-root/src/.npm-global/bin && \
    ln -s /usr/bin/node /usr/bin/nodejs && \
    if [[ -f /tmp/assets/codeready-workspaces-stacks-language-servers-dependencies-node10-$(uname -m).tar.gz ]]; then \
        tar xzf /tmp/assets/codeready-workspaces-stacks-language-servers-dependencies-node10-$(uname -m).tar.gz -C ${HOME}/lang-server/ && \
        ln -s ${HOME}/lang-server/node_modules/typescript-language-server/lib/cli.js /opt/app-root/src/.npm-global/bin/typescript-language-server && \
        ln -s ${HOME}/lang-server/node_modules/nodemon/bin/nodemon.js /opt/app-root/src/.npm-global/bin/nodemon && \
        ln -s ${HOME}/lang-server/node_modules/typescript/bin/tsc /opt/app-root/src/.npm-global/bin/tsc && \
        ln -s ${HOME}/lang-server/node_modules/typescript/bin/tsserver /opt/app-root/src/.npm-global/bin/tsserver && \
        for f in "/opt/app-root/src/.npm-global"; do chgrp -R 0 ${f}; chmod -R g+rwX ${f}; done; \
    else \
        echo "[WARNING] Node lang server dependency tarball not found. Node support may be more limited on $(uname -m)"; \
    fi
RUN \
    # additional python stuff
    ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -s /usr/bin/pip${PYTHON_VERSION} /usr/bin/pip && \
    if [[ -f /tmp/assets/codeready-workspaces-stacks-language-servers-dependencies-python-$(uname -m).tar.gz ]]; then \
        mkdir -p /tmp/py-unpack && \
        tar -xf /tmp/assets/codeready-workspaces-stacks-language-servers-dependencies-python-$(uname -m).tar.gz -C /tmp/py-unpack && \
        for f in /tmp/py-unpack; do chgrp -R 0 ${f}; chmod -R g+rwX ${f}; done; \
        cp -R /tmp/py-unpack/bin/* /usr/bin && \
        cp -R /tmp/py-unpack/lib/* /usr/lib && \
        cp -R /tmp/py-unpack/lib64/* /usr/lib64 && \
        cp -R /tmp/py-unpack/.venv "${HOME}/.venv-tmp" && \
        chgrp -R 0 "${HOME}/.venv-tmp" && chmod -R g+rwX "${HOME}/.venv-tmp" && \
        rm -fr /tmp/py-unpack \
    else \
        echo "[WARNING] Python lang server dependency tarball not found. Python support may be more limited on $(uname -m)"; \
    fi
RUN \
    # cleanup and summaries
    rm -fr /tmp/assets/ && \
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages" && \
    echo "========" && \
    java -version && \
    mvn -version && \
    echo "========" && \
    echo -n "Node "; node --version && \
    echo -n "npm ";  npm --version && \
    echo "========" && \
    python -V && \
    pip -V && \
    pylint --version && \
    echo "========"

ADD entrypoint.sh ${HOME}/
RUN chmod +x ${HOME}/*.sh

USER jboss
ENTRYPOINT ["/home/jboss/entrypoint.sh"]
WORKDIR /projects
CMD tail -f /dev/null

# append Brew metadata here
ENV SUMMARY="Red Hat CodeReady Workspaces - OpenJDK 8 + Node 12 + Python 3.8 plugin container" \
    DESCRIPTION="Red Hat CodeReady Workspaces - OpenJDK 8 + Node 12 + Python 3.8 plugin container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="plugin-java8-rhel8"

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="$DESCRIPTION" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME-container" \
      name="$PRODNAME/$COMPNAME" \
      version="2.10" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage=""

# insert generated LABELs below this line
LABEL \
	  jenkins.build.url="https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/CRW_CI/view/CRW_CI/view/Pipelines/job/crw-deprecated_2.x/375/" \
	  jenkins.artifact.url="https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/CRW_CI/view/CRW_CI/view/Pipelines/job/crw-deprecated_2.x/375/artifact/**/::apache-maven-3.6.3-bin.tar.gz" \
	  jenkins.artifact.url="https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/CRW_CI/view/CRW_CI/view/Pipelines/job/crw-deprecated_2.x/375/artifact/**/codeready-workspaces-stacks-language-servers-dependencies-node10-x86_64.tar.gz" \
	  jenkins.artifact.url="https://main-jenkins-csb-crwqe.apps.ocp4.prod.psi.redhat.com/job/CRW_CI/view/CRW_CI/view/Pipelines/job/crw-deprecated_2.x/375/artifact/**/codeready-workspaces-stacks-language-servers-dependencies-python-x86_64.tar.gz" \
	  jenkins.build.number="375"
