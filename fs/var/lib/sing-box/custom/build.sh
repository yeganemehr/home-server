#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR;

sing-box rule-set compile geoip-bunny.json
sing-box rule-set compile geoip-mullvad.json
sing-box rule-set compile geoip-rustdesk.json
sing-box rule-set compile geosite-google-direct.json
sing-box rule-set compile geosite-postman.json
sing-box rule-set compile geosite-rustdesk.json
