FROM debian:12

ARG DEBIAN_FRONTEND="noninteractive"

RUN apt update
RUN apt -y install zstd tasksel linux-image-amd64 firmware-linux-free console-setup-linux systemd-sysv
RUN tasksel install standard
RUN apt -y install dnsutils systemd-timesyncd wireguard curl jq tmux iptables openvpn unzip lm-sensors nload openssh-server nano network-manager htop zsh git cloud-guest-utils parted cups hplip \
    lsb-release ca-certificates && \
    curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb && \
    dpkg -i /tmp/debsuryorg-archive-keyring.deb

COPY fs/etc/apt/sources.list.d/php.sources /etc/apt/sources.list.d/php.sources

RUN apt update && \
    apt -y install php8.4-cli php8.4-curl php8.4-gd php8.4-intl php8.4-mbstring php8.4-opcache php8.4-readline php8.4-sqlite3 php8.4-xml php8.4-zip php-pear && \
    wget -O /usr/local/bin/composer https://getcomposer.org/download/latest-stable/composer.phar && \
    chmod +x /usr/local/bin/composer

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
    wget https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip && \
    unzip gh-pages.zip && \
    rm -f gh-pages.zip && \
    mv Yacd-meta-gh-pages ui && \
    systemctl enable sing-box

RUN --mount=type=bind,source=vpn-manager,target=/opt/vpn-manager \
    cp -R /opt/vpn-manager /tmp/vpn-manager && \
    cd /tmp/vpn-manager && \
    composer install --no-dev && \
    ./vpn-manager app:build --build-version=1.0.0 -n && \
    mv builds/vpn-manager /usr/local/bin/vpn-manager && \
    mv config/sing-box.php /var/lib/sing-box/template.php && \
    cd / && \
    rm -fr /tmp/vpn-manager && \
    vpn-manager sing-box:rebuild --output=/etc/sing-box/config.json


COPY fs/ /

RUN update-rc.d set-timezone defaults && \
    update-rc.d update-initramfs defaults

RUN /var/lib/sing-box/custom/build.sh

RUN passwd -d root && passwd -e root
