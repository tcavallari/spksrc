#!/bin/bash
aptitude update && \
  aptitude upgrade -y && \
  aptitude install -y locales && \
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
  LANG=en_US.UTF-8 locale-gen --purge en_US.UTF-8 && \
  echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US.UTF-8"\n' > /etc/default/locale && \
  echo "Europe/Rome" > /etc/timezone && \
  dpkg-reconfigure -f noninteractive tzdata
