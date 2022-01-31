#!/bin/bash

something() {
  ping -w 1 192.168.56.15 &> /dev/null;
  local istrue="${?}"
  return istrue
}

NAD=$(something)
echo $NAD