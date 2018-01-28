A/B testing using Istio
=======================

> Version B is released to a subset of users under specific condition.

A/B testing deployments consists of routing a subset of users to a new
functionality under specific conditions. It is usually a technique for making
business decisions based on statistics, rather than a deployment strategy.
However, it is related and can be implemented by adding extra functionality to a
canary deployment so we will briefly discuss it here.

This technique is widely used to test conversion of a given feature and only
roll-out the version that converts the most.

Here is a list of conditions that can be used to distribute traffic amongst the
versions:

- Weight
- Cookie value
- Query parameters
- Geolocalisation
- Technology support: browser version, screen size, operating system, etc.
- Language

## Steps to follow

1. version 1 with Istio sidecar container is serving HTTP traffic
1. create RouteRule via Istio, 100% version 1, 0% version 2
1. deploy version 2
1. wait until all instances are ready
1. update Istio RouteRule with 90% version 1, 0% version 2

## In practice

### Deploy Istio

In this example, Istio 0.4.0 is used.

```
$ curl -L https://git.io/getLatestIstio | sh -
$ cd istio-0.4.0
$ export PATH=$PWD/bin:$PATH
$ kubectl apply -f install/kubernetes/istio.yaml
```

### Deploy the application

Back to the a/b testing directory from this repo, deploy the service and
ingress:

```
$ kubectl apply -f ./service.yaml
$ kubectl apply -f ./ingress.yaml
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

### Shift traffic based on weight

Apply the load balancing rule:

```
$ kubectl apply -f ./rules-weight.yaml
```

You can now test if the traffic is correctly splitted amongst both versions:

```
$ service=$(minikube service istio-ingress --url -n istio-system | head -n1)
$ while sleep 0.1; do curl "$service"; done
```

You should see 1 request on 10 ending up in the version 2.

In the rules.yaml file, you can edit the weight of each route and apply the
changes as follow:

```
$ kubectl apply -f ./rules-weight.yaml
```

### Shift traffic based on headers

If you have been following the steps above, you need to remove the previously
create RouteRule:

```
$ kubectl delete routerule my-app
```

Then apply the matching rule:

```
$ kubectl apply -f ./rules-match.yaml
```

Test if the traffic is hitting the correct set of instances:

```
$ service=$(minikube service istio-ingress --url -n istio-system | head -n1)
$ curl $service -H 'X-API-Version: v1.0.0'
Host: my-app-v1-5869685788-j4slc, Version: v1.0.0

$ curl $service -H 'X-API-Version: v2.0.0'
Host: my-app-v2-5cf5f5bc7d-kcjdn, Version: v2.0.0
```

### Cleanup

```
$ kubectl delete all -l app=my-app
$ kubectl delete -f <PATH-TO-ISTIO>/install/kubernetes/istio.yaml
```
