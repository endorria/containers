#!/usr/bin/env bash

if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  exit 255
fi

while getopts g:n:p: flag; do
  case "${flag}" in
  g) adGroup=${OPTARG} ;;
  n) shareName=${OPTARG} ;;
  p) pkcs12Pass=${OPTARG} ;;
  esac
done

if [ -z "$adGroup" ]; then
  echo "!-- -g ad group is required --!"
  exit 404
fi
if [ -z "$shareName" ]; then
  echo "!-- -n share name is required --!"
  exit 404
fi
if [ -z "$pkcs12Pass" ]; then
  echo "!-- -p pkcs12 pass is required --!"
  exit 404
fi

# Function to find an available port
find_available_port() {
  local port=$1
  while true; do
    if ! ss -tuln | grep -q ":$port "; then
      echo $port
      break
    fi
    port=$((port + 1))
  done
}

mkdir ./$adGroup
mkdir ./$adGroup/certs

OUTPUT_FILE=./$adGroup/compose.yml
TEMPLATE_FILE=./compose-template.yml
GSDATA_PATH=/srv/samba/$shareName/geoserver/data
GSGWCDATA_PATH=/srv/samba/$shareName/geoserver/gwc
DBDATA_PATH=/srv/samba/$shareName/geoserver/database

mkdir -p $GSDATA_PATH
mkdir -p $GSGWCDATA_PATH
mkdir -p $DBDATA_PATH

group=$(wbinfo -r "$adGroup@arxit" | head -n 1)
chown -r root:"$group" /srv/samba/$shareName/

sed -e "s|__GSDATA_PATH__|$GSDATA_PATH|g" \
  -e "s|__GSGWCDATA_PATH__|$GSGWCDATA_PATH|g" \
  -e "s|__DBDATA_PATH__|$DBDATA_PATH|g" \
  "$TEMPLATE_FILE" >"$OUTPUT_FILE"

cp ./certs/certificate.pfx ./$adGroup/certs/certificate.pfx

# Generate env vars
gspass=$(gpg --gen-random --armor 1 14)
gsport=$(find_available_port 10000)
gsports=$(find_available_port $((gsport + 1)))
dbpass=$(gpg --gen-random --armor 1 14)
dbport=$(find_available_port $((gsports + 1)))
tee ./$adGroup/.env <<EOF
POSTGIS_VERSION_TAG=17-3.5
POSTGRES_PORT=$dbport
POSTGRES_DB=gis,gwc
POSTGRES_USER=starlord
POSTGRES_PASS=$dbpass
ALLOW_IP_RANGE=0.0.0.0/0

GS_VERSION=2.26.0
GEOSERVER_PORT=$gsport
GEOSERVER_SSL_PORT=$gsports
PKCS12_PASSWORD=$pkcs12Pass
GEOSERVER_ADMIN_USER=starlord
GEOSERVER_ADMIN_PASSWORD=$gspass
INITIAL_MEMORY=2G
MAXIMUM_MEMORY=4G
STABLE_EXTENSIONS=
COMMUNITY_EXTENSIONS=
GEOSERVER_CONTEXT_ROOT=
CONSOLE_HANDLER_LEVEL=WARNING
GEOSERVER_DATA_DIR=/opt/geoserver/data_dir
GEOWEBCACHE_CACHE_DIR=/opt/geoserver/data_dir/gwc
EXISTING_DATA_DIR=true
EOF

cat <<EOF

****** TO SAVE ******
Database access
pwd  : $dbpass 
port : $dbport

Geoserver access
user : starlord
pwd  : $gspass
EOF
