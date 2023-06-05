#!/bin/bash


while sleep 0.1;
    do curl --connect-timeout 1 http://localhost:54967/;
done
