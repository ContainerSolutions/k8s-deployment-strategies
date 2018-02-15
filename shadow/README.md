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

1. version is serving traffic
1. deploy version 2
1. wait enought time to confirm that version 2 is stable and not throwing
   unexpected errors
1. switch incoming traffic from version 1 to version 2

## In practice

### Deploy Istio

In this example, Istio 0.5.1 is used.

```
$ curl -L https://git.io/getLatestIstio | sh -
$ cd istio-0.5.1
$ export PATH=$PWD/bin:$PATH
$ kubectl apply -f install/kubernetes/istio.yaml
```

### Deploy the application

Back to the a/b testing directory from this repo, deploy the service, ingress
and Istio rules:

```
$ kubectl apply -f ./service.yaml -f ./ingress.yaml -f ./rules.yaml
```

Deploy the first application and use istioctl to inject a sidecar container to
proxy all in and out requests:

```
$ kubectl apply -f <(istioctl kube-inject -f app-v1.yaml)
```

Test if the deployment was successful:

```
$ curl $(minikube service istio-ingress --url -n istio-system | head -n1)
2018-01-28T00:22:04+01:00 - Host: host-1, Version: v1.0.0
```

Then deploy the version 2 of the application:

```
$ kubectl apply -f <(istioctl kube-inject -f app-v2.yaml)
```

Throw few requests to the service:

```
$ curl $(minikube service my-app --url)
```

If you check the logs from the second deployment, you should be able to see all
the incoming request of version 1 being mirrored to version 2:

```
$ kubectl logs deploy/my-app-v1 -c my-app
$ kubectl logs deploy/my-app-v2 -c my-app
```

### Cleanup

```
$ kubectl delete all -l app=my-app
$ kubectl delete -f <PATH-TO-ISTIO>/install/kubernetes/istio.yaml
```
