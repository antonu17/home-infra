FROM debian:bookworm AS base

ENV DEBIAN_FRONTEND=noninteractive

ADD https://www.flightaware.com/adsb/piaware/files/packages/pool/piaware/f/flightaware-apt-repository/flightaware-apt-repository_1.3_all.deb /tmp/flightaware-apt-repository_1.3_all.deb

RUN apt-get update && \
    apt-get install --no-install-recommends --yes procps apt-utils iputils-ping curl gpg ca-certificates && \
    dpkg -i /tmp/flightaware-apt-repository_1.3_all.deb && \
    mkdir -p /etc/apt/keyrings && \
    curl -L https://repo-feed.flightradar24.com/flightradar24.pub | gpg --dearmor > /etc/apt/keyrings/flightradar24.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/flightradar24.gpg] https://repo-feed.flightradar24.com flightradar24 raspberrypi-stable" > /etc/apt/sources.list.d/fr24feed.list && \
    apt-get update && \
    ln -s /bin/true /bin/systemctl && \
    ln -s /bin/true /bin/udevadm && \
    apt-get install --no-install-recommends --yes dump1090-fa fr24feed piaware && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    piaware -v
