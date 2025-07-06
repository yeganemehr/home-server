
FROM debian:12

ARG DEBIAN_FRONTEND="noninteractive"

RUN apt update
RUN apt -y install zstd tasksel linux-image-amd64 firmware-linux-free console-setup-linux systemd-sysv
RUN tasksel install standard
RUN apt -y install dnsutils systemd-timesyncd wireguard curl jq tmux iptables openvpn unzip lm-sensors nload openssh-server nano network-manager htop zsh git cloud-guest-utils parted
RUN rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

RUN wget -O /root/.ssh/authorized_keys https://github.com/yeganemehr.keys && \
    chmod 0600 /root/.ssh/authorized_keys

RUN chsh -s $(which zsh) && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

RUN wget -O /tmp/sing-box.deb https://github.com/SagerNet/sing-box/releases/download/v1.11.13/sing-box_1.11.13_linux_amd64.deb && \
    dpkg -i /tmp/sing-box.deb && \
    mkdir -p /var/lib/sing-box && \
    cd /var/lib/sing-box && \
    git clone -b master --single-branch https://github.com/v2fly/domain-list-community.git && \
    git clone -b rule-set --single-branch https://github.com/Chocolate4U/Iran-sing-box-rules.git && \
    git clone -b rule-set --single-branch https://github.com/SagerNet/sing-geoip.git && \
    git clone -b rule-set --single-branch https://github.com/SagerNet/sing-geosite.git && \
    systemctl enable sing-box


COPY fs/ /

RUN update-rc.d set-timezone defaults && \
    update-rc.d update-initramfs defaults

RUN /var/lib/sing-box/custom/build.sh

RUN passwd -d root && passwd -e root
