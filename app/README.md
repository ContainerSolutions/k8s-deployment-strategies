Dummy show hostname and version application
===========================================

> Really simple GoLang webserver which purpose is to reply with the hostname and, if existing, the environment variable VERSION

## Getting started

```
# Compile
$ CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

# Build
$ docker build -t containersol/k8s-deployment-strategies-demo .

# Run
$ docker run -d -p 8080:8080 -h host-1 -e VERSION=v1.0.0 containersol/k8s-deployment-strategies-demo

# Query
$ curl localhost:8080
> 2017-09-20 12:00:55.425290606 +0000 UTC m=+2.506207642 - Host: host-1, Version: v1.0.0
```
