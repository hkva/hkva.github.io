#!/bin/sh
rm -rf ./public
hugo -D
sudo rm -rf /var/www/hkva
sudo cp -R ./public /var/www/hkva
