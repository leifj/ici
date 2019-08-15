# Use debian:stretch here, because with the SUNET Yubikey setup, the openssl engine can't be
# greater than 0.4.6 (the Yubikey has CKA_ALWAYS_AUTHENTICATE set, which breaks ICI usage).
#   https://bugzilla.redhat.com/show_bug.cgi?id=1728016
FROM debian:stretch AS build
ARG VERSION

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update && apt-get -y install \
    devscripts \
    git \
    help2man \
    opensc \
    softhsm2
COPY . /build/ici-${VERSION}
RUN mv /build/ici-${VERSION}/ici-${VERSION}.tar.gz /build/ici_${VERSION}.orig.tar.gz
WORKDIR /build/ici-${VERSION}
RUN (git describe; git log -n 1) > /build/revision.txt
RUN rm -rf ca .git
RUN dpkg-buildpackage -b
RUN find /build -type f -name '*.deb' -ls

# Use debian:stretch here, because with the SUNET Yubikey setup, the openssl engine can't be
# greater than 0.4.6 (the Yubikey has CKA_ALWAYS_AUTHENTICATE set, which breaks ICI usage).
#   https://bugzilla.redhat.com/show_bug.cgi?id=1728016
FROM debian:stretch
ARG VERSION
COPY --from=build /build/ici_${VERSION}-*.deb /build/revision.txt /
COPY scripts/inotify_issue_and_publish.sh /
COPY scripts/init_softhsm_ca.sh /

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get -y update && apt-get -y install \
    git \
    inotify-tools \
    libengine-pkcs11-openssl1.1 \
    opensc \
    openssl \
    procps \
    softhsm2 \
    usbutils
RUN ls -l /ici_${VERSION}-*.deb
RUN dpkg -i /ici_${VERSION}-*.deb

VOLUME ["/var/lib/ici", "/var/lib/softhsm"]
ENTRYPOINT ["/bin/bash"]
