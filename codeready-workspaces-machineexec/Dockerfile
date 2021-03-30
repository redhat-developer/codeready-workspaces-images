# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/rhel8/go-toolset
FROM rhel8/go-toolset:1.14.12-13 as builder
ENV GOPATH=/go/
USER root
WORKDIR /che-machine-exec/
COPY . .
RUN adduser unprivilegeduser && \
    CGO_ENABLED=0 GOOS=linux go build -mod=vendor -a -ldflags '-w -s' -a -installsuffix cgo -o che-machine-exec . && \
    mkdir -p /rootfs/tmp /rootfs/etc /rootfs/go/bin && \
    # In the `scratch` you can't use Dockerfile#RUN, because there is no shell and no standard commands (mkdir and so on).
    # That's why prepare absent `/tmp` folder for scratch image 
    chmod 1777 /rootfs/tmp && \
    cp -rf /etc/passwd /rootfs/etc && \
    cp -rf /che-machine-exec/che-machine-exec /rootfs/go/bin

FROM scratch

COPY --from=builder /rootfs /
COPY --from=builder /usr/bin/sleep /usr/bin/sleep

USER unprivilegeduser
ENTRYPOINT ["/go/bin/che-machine-exec"]

# append Brew metadata here
ENV SUMMARY="Red Hat CodeReady Workspaces machineexec container" \
    DESCRIPTION="Red Hat CodeReady Workspaces machineexec container" \
    PRODNAME="codeready-workspaces" \
    COMPNAME="machineexec-rhel8" 
LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="$DESCRIPTION" \
      io.openshift.tags="$PRODNAME,$COMPNAME" \
      com.redhat.component="$PRODNAME-$COMPNAME-container" \
      name="$PRODNAME/$COMPNAME" \
      version="2.8" \
      license="EPLv2" \
      maintainer="Nick Boldt <nboldt@redhat.com>" \
      io.openshift.expose-services="" \
      usage="" 