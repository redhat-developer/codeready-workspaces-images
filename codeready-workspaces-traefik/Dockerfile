# https://access.redhat.com/containers/?tab=tags#/registry.access.redhat.com/ubi8-minimal 
FROM ubi8-minimal:8.3-298 

ENV SUMMARY="Red Hat CodeReady Workspaces - Traefik" \ 
    DESCRIPTION="Red Hat CodeReady Workspaces - Traefik" \ 
    PRODNAME="codeready-workspaces" \ 
    COMPNAME="traefik-rhel8" 

COPY asset-*.tar.gz /tmp/assets/ 

COPY script/ca-certificates.crt /etc/ssl/certs/
RUN microdnf -y install tar gzip && \ 
    tar xzf /tmp/assets/asset-traefik-$(uname -m).tar.gz -C / && \ 
    rm -fr /tmp/assets/ && \ 
    chmod 755 /traefik && \ 
    microdnf -y update || true && \ 
    microdnf -y remove tar gzip && \ 
    echo "Installed Packages" && rpm -qa | sort -V && echo "End Of Installed Packages" 

EXPOSE 80
VOLUME ["/tmp"]
ENTRYPOINT ["/traefik"]

LABEL summary="$SUMMARY" \ 
      description="$DESCRIPTION" \ 
      io.k8s.description="$DESCRIPTION" \ 
      io.k8s.display-name="$DESCRIPTION" \ 
      io.openshift.tags="$PRODNAME,$COMPNAME" \ 
      com.redhat.component="$PRODNAME-$COMPNAME-container" \ 
      name="$PRODNAME/$COMPNAME" \ 
      version="2.9" \ 
      license="EPLv2" \ 
      maintainer="Nick Boldt <nboldt@redhat.com>" \ 
      io.openshift.expose-services="" \ 
      usage=""