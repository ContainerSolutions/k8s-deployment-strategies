Shadow deployment
=================

> Version B receives real-world traffic alongside version A and doesn’t impact
the response.

![kubernetes shadow deployment](grafana-shadow.png)

A shadow deployment consists of releasing version B alongside version A, fork
version A’s incoming requests and send them to version B as well without
impacting production traffic. This is particularly useful to test production
load on a new feature. A rollout of the application is triggered when stability
and performance meet the requirements.

This technique is fairly complex to setup and needs special requirements,
especially with egress traffic. For example, given a shopping cart platform,
if you want to shadow test the payment service you can end-up having customers
paying twice for their order. In this case, you can solve it by creating a
mocking service that replicates the response from the provider.

In this example, we make use of [Istio](https://istio.io) to mirror traffic to
the secondary deployment.

## Steps to follow

1. version 1 is serving HTTP traffic using Istio
1. deploy version 2
1. mirror version 1 incoming traffic to version 2
1. wait enought time to confirm that version 2 is stable and not throwing
   unexpected errors
1. switch incoming traffic from version 1 to version 2

## In practice

Before starting, it is recommended to know the basic concept of the
[Istio routing API](https://istio.io/blog/2018/v1alpha3-routing/).

### Deploy Istio

In this example, Istio 1.0.0 is used. To install Istio, follow the
[instructions](https://istio.io/docs/setup/kubernetes/helm-install/) from the
Istio website.

Automatic sidecar injection should be enabled by default. Then annotate the
default namespace to enable it.

```
$ kubectl label namespace default istio-injection=enabled
```

### Deploy both applications

Back to the shadow directory from this repo, deploy both applications using the
istioctl command to inject the Istio sidecar container which is used to proxy
requests:

```
$ kubectl apply -f app-v1.yaml -f app-v2.yaml
```

Expose both services via the Istio Gateway and create a VirtualService to match
requests to the my-app-v1 service:

```
$ kubectl apply -f ./gateway.yaml -f ./virtualservice.yaml
```

At this point, if you make a request against the Istio ingress gateway with the
given host `my-app.local`, you should only see version 1 responding:

```
$ curl $(minikube service istio-ingressgateway -n istio-system --url | head -n1) -H 'Host: my-app.local'
Host: my-app-v1-6d577d97b4-lxn22, Version: v1.0.0
```

### Enable traffic mirroring

```
$ kubectl apply -f ./virtualservice-mirror.yaml
```

Throw few requests to the service, only version 1 should be seen in the
response:

```
$ curl $(minikube service istio-ingressgateway -n istio-system --url | head -n1) -H 'Host: my-app.local'
```

If you check the logs from both pods, you should see all version 1 incoming
requests being mirrored to version 2:

```
$ kubectl logs deploy/my-app-v1 -c my-app
$ kubectl logs deploy/my-app-v2 -c my-app
```

### Cleanup

```
$ kubectl delete gateway/my-app virtualservice/my-app
$ kubectl delete -f ./app-v1.yaml -f ./app-v2.yaml
$ kubectl delete -f <PATH-TO-ISTIO>/install/kubernetes/istio-demo.yaml
```
