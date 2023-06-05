#!/bin/bash

AGIC-PUBLIC-IP="4.157.48.202"

while sleep 0.1;
    do curl --connect-timeout 1 http://apgw.aks.aliez.tw;
done
