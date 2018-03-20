Recreate deployment
===================

> Version A is terminated then version B is rolled out.

![kubernetes recreate deployment](grafana-recreate.png)

The recreate strategy is a dummy deployment which consists of shutting down
version A then deploying version B after version A is turned off. This technique
implies downtime of the service that depends on both shutdown and boot duration
of the application.

## Steps to follow

1. version 1 is service traffic
1. delete version 1
1. deploy version 2
1. wait until all replicas are ready

## In practice

### Deploy the first application

```
$ kubectl apply -f app-v1.yaml
```

Wait until the service IP is available:

```
$ kubectl get svc my-app
```

Test if the deployment was successful:

```
$ curl $(kubectl get svc -o jsonpath="{.status.loadBalancer.ingress[0].ip}" my-app)
2018-01-28T00:22:04+01:00 - Host: host-1, Version: v1.0.0
```

Before deploying the new release, open a new terminal and run the following
command To see the deployment in action:

```
$ watch kubectl get po
```

Then, in the previous terminal, deploy version 2 of the application:

```
$ kubectl apply -f app-v2.yaml
```

Test the second deployment progress:

```
$ service=$(kubectl get svc -o jsonpath="{.status.loadBalancer.ingress[0].ip}" my-app)
$ while sleep 0.1; do curl "$service" --connect-timeout 0; done
```

### Cleanup

```
$ kubectl delete all -l app=my-app
```
