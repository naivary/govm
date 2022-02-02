#!/bin/bash


validateUsedIPFileState() {
  IP_TO_ID="$(grep '192.168.56.13' used_ip.txt | cut -d '=' -f 2 used_ip.txt)"
  ID_TO_IP="$(grep '4c350b6ebd' used_ip.txt | cut -d '=' -f 1 used_ip.txt)"
  echo ${ID_TO_IP}
  echo ${IP_TO_ID}
}

validateUsedIPFileState