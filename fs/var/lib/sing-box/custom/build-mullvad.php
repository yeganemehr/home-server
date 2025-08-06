#!/usr/bin/php
<?php

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, "https://api.mullvad.net/app/v1/relays");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$data = curl_exec($ch);
if ($data === false) {
    die("Error fetching data: " . curl_error($ch));
}
curl_close($ch);

$data = json_decode($data, true);

$ips = array_merge(
    array_map(fn($ipv4) => $ipv4 . "/32", array_column($data['openvpn']['relays'], 'ipv4_addr_in')),
    array_map(fn($ipv4) => $ipv4 . "/32", array_column($data['wireguard']['relays'], 'ipv4_addr_in')),
    array_map(fn($ipv6) => $ipv6 . "/128", array_column($data['wireguard']['relays'], 'ipv6_addr_in')),
    array_map(fn($ipv4) => $ipv4 . "/32", array_column($data['bridge']['relays'], 'ipv4_addr_in')),
);

$ips = array_unique($ips);

$data = array(
    "version" => 3,
    "rules" => array(
        array(
            "ip_cidr" => $ips,
        )
    )
);
file_put_contents(
    __DIR__ . "/geoip-mullvad.json",
    json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
);
