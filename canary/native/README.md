Canary deployment using Kubernetes native functionnalities
==========================================================

> In the following example we apply the poor man's canary using Kubernetes
native features (replicas). If you want a finer grained control over traffic
shifting, check the [nginx-ingress](../nginx-ingress) example which use
[Nginx](http://nginx.org/) to split traffic or the [a/b testing](../../ab-testing)
example which shift traffic using [Istio](https://istio.io).

## Steps to follow

1. 10 replicas of version 1 is serving traffic
1. deploy 1 replicas version 2 (meaning ~10% of traffic)
1. wait enought time to confirm that version 2 is stable and not throwing
   unexpected errors
1. scale up version 2 replicas to 10
1. wait until all instances are ready
1. shutdown version 1

## In practice

```bash
# Deploy the first application
$ kubectl apply -f app-v1.yaml

# Test if the deployment was successful
$ curl $(minikube service my-app --url)
2018-01-28T00:22:04+01:00 - Host: host-1, Version: v1.0.0

# To see the deployment in action, open a new terminal and run a watch command.
# It will show you a better view on the progress
$ watch kubectl get po

# Then deploy version 2 of the application and scale down version 1 to 9 replicas at same time
$ kubectl apply -f app-v2.yaml
$ kubectl scale --replicas=9 deploy my-app-v1

# Only one pod with the new version should be running.
# You can test if the second deployment was successful
$ service=$(minikube service my-app --url)
$ while sleep 0.1; do curl "$service"; done

# If you are happy with it, scale up the version 2 to 10 replicas
$ kubectl scale --replicas=10 deploy my-app-v2

# Then, when all pods are running, you can safely delete the old deployment
$ kubectl delete deploy my-app-v1
```

### Cleanup

```bash
$ kubectl delete all -l app=my-app
```
