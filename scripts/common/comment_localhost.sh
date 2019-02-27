#!/bin/sh

sudo sed -i "s/^127.0.0.1.*$(hostname)/127.0.0.1 localhost/;s/^127.0.1.1/#127.0.1.1/" /etc/hosts
sudo sed -i "s/^nameserver 127.0/#nameserver 127.0/" /etc/resolv.conf
