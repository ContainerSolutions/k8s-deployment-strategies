Dummy application which display hostname and version
====================================================

> GoLang webserver which purpose is to reply with the hostname and if existing,
the environment variable VERSION.

## Getting started

### Development

Install dependencies using [dep](https://github.com/golang/dep):

```
$ dep ensure
$ go run main.go
```

### Docker

#### Build

```
$ docker build -t containersol/k8s-deployment-strategies .
```

#### Run

```
$ docker run -d \
    --name app \
    -p 8080:8080 \
    -h host-1 \
    -e VERSION=v1.0.0
    containersol/k8s-deployment-strategies
```

#### Test

```
$ curl localhost:8080
2018-01-28T00:22:04+01:00 - Host: host-1, Version: v1.0.0
```

Liveness and readiness probes are replying on `:8086/live` and `:8086/ready`.

Prometheus metrics are served at `:9101/metrics`.

#### Cleanup

```
$ docker stop app
```
