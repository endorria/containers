#!/usr/bin/env bash

if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  exit 255
fi

while getopts g:n: flag; do
  case "${flag}" in
  g) adGroup=${OPTARG} ;;
  n) shareName=${OPTARG} ;;
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

# check group creation
read -p "$adGroup should be created in the ADDC, is it done (y/n)?" response
if ! [[ "$response" =~ ^[Yy]$ ]]; then
  echo "Fail"
  exit 1
fi

# retrieve the group ID
group=$(wbinfo -r "$adGroup@arxit" | head -n 1)

# create the folder
mkdir -p /srv/samba/$shareName

# set the rights
chown root:"$group" /srv/samba/$shareName/
chmod 0770 /srv/samba/$shareName/

mkdir /srv/samba/$shareName/geoserver

# add the share in Samba conf
tee -a /etc/samba/smb.conf <<EOF

[$shareName]
    path = /srv/samba/$shareName
    read only = no
EOF

# restart the service
smbcontrol all reload-config
