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

```
# Deploy the first application
$ kubectl apply -f app-v1.yaml
namespace/ns-recreate created
ingress.networking.k8s.io/ingress-recreate created
service/svc-my-app created
deployment.apps/deployment-my-app created

# Test if the deployment was successful
$ curl http://AGIC-PUBLIC-IP
Host: deployment-my-app-6888dcf989-lf5jk, Version: v1.0.0

# To see the deployment in action, open a new terminal and run the following
# command
$ watch kubectl get pod -n ns-recreate
NAME                                 READY   STATUS    RESTARTS   AGE
deployment-my-app-6888dcf989-d8zsc   1/1     Running   0          94s
deployment-my-app-6888dcf989-m72j5   1/1     Running   0          94s
deployment-my-app-6888dcf989-rtd7x   1/1     Running   0          94s

# Test the second deployment progress
$ while sleep 0.1; do curl http://AGIC-PUBLIC-IP; done
Host: deployment-my-app-6888dcf989-m72j5, Version: v1.0.0
Host: deployment-my-app-6888dcf989-rtd7x, Version: v1.0.0
Host: deployment-my-app-6888dcf989-d8zsc, Version: v1.0.0
Host: deployment-my-app-6888dcf989-d8zsc, Version: v1.0.0
Host: deployment-my-app-6888dcf989-m72j5, Version: v1.0.0
Host: deployment-my-app-6888dcf989-rtd7x, Version: v1.0.0
...omit...


# Then deploy version 2 of the application
$ kubectl apply -f app-v2.yaml


```

### Cleanup

```bash
$ kubectl delete all -l app=my-app
```
