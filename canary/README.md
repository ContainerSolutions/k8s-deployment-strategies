Canary deployment
=================

> Version B is released to a subset of users, then proceed to a full rollout.

![kubernetes canary deployment](grafana-canary.png)

A canary deployment consists of gradually shifting production traffic from
version A to version B. Usually the traffic is split based on weight. For
example, 90 percent of the requests go to version A, 10 percent go to version B.

This technique is mostly used when the tests are lacking or not reliable or if
there is little confidence about the stability of the new release on the
platform.

*In the following example we apply the poor man's canary using Kubernetes native
features (replicas). If you want a finer grained control over traffic shifting,
check the [a/b testing example](../ab-testing) which contain an example of
traffic shifting using [Isio](https://istio.io)).*

## Steps to follow

1. 10 replicas of version 1 is serving traffic
1. deploy 1 replicas version 2 (meaning ~10% of traffic)
1. wait enought time to confirm that version 2 is stable and not throwing
   unexpected errors
1. scale up version 2 replicas to 10
1. wait until all instances are ready
1. shutdown version 1

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

To see the deployment in action, open a new terminal and run a watch command. It
will show you a better view on the progress:

```
$ watch kubectl get po
```

Then deploy the version 2 of the application:

```
$ kubectl apply -f app-v2.yaml
```

Only one pod with the new version should be running.

You can test if the second deployment was successful:

```
$ service=$(minikube service my-app --url)
$ while sleep 0.1; do curl "$service"; done
```

If you are happy with it, scale up the version 2 to 10 replicas:

```
kubectl scale --replicas=10 deploy my-app-v2
```

Then, when all pods are running, you can safely delete the old deployment:

```
kubectl delete deploy my-app-v1
```

### Cleanup

```
$ kubectl delete all -l app=my-app
```
