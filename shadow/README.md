Shadow deployment
=================

> Version B receives real-world traffic alongside version A and doesn’t impact
the response.

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

**Recently, Istio added support for [traffic mirroring/shadowing](https://istio.io/docs/reference/config/traffic-rules/routing-rules.html#mirror).**

In this example, we make use of [GoReplay](https://github.com/buger/goreplay)
as sidecar container to capture and replay incoming traffic to version 2.

## Steps to follow

1. version is serving traffic
1. deploy version 2
1. wait enought time to confirm that version 2 is stable and not throwing
   unexpected errors
1. switch incoming traffic from version 1 to version 2

## In practice

Deploy the first application:

```
$ kubectl apply -f app-v1.yaml
```

Test if the deployment was successful:

```
$ curl $(minikube service my-app --url)
2018-01-28T00:22:04+01:00 - Host: host-1, Version: v1.0.0
```

Then deploy the version 2 of the application:

```
$ kubectl apply -f app-v2.yaml
```

Throw few requests to the service:

```
$ curl $(minikube service my-app --url)
```

If you check the logs from the second deployment, you should be able to see all
the incoming request of version 1 being mirrored to version 2:

```
$ kubectl logs deploy/my-app-v1 -c my-app
$ kubectl logs deploy/my-app-v2
```

### Cleanup

```
$ kubectl delete all -l app=my-app
```
