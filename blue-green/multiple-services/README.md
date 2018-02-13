Blue/green deployment to release multiple services simultaneously
=================================================================

> In this example, we release a new version of 2 services simultaneously using
the blue/green deployment strategy.

## Steps to follow

1. service a and b are serving traffic
1. deploy new version of both services
1. wait for all services to be ready
1. switch incoming traffic from version 1 to version 2
1. shutdown version 1

## In practice

###  Deploy Traefik with Helm

Install the latest version of [Helm](https://docs.helm.sh/using_helm/#installing-helm), then install Traefik:

```
$ helm install --name=traefik --version=1.17.1 stable/traefik
```

Deploy version 1 of application a and b:

```
$ kubectl apply -f app-a-v1.yaml -f app-b-v1.yaml
$ kubectl apply -f ingress-v1.yaml
```

Test if the deployment was successful:

```
$ ingress=$(minikube service traefik-traefik --url | head -n1)
$ curl $ingress -H 'Host: a.domain.com'
Host: my-app-a-v1-66fb8d6f99-hs8jr, Version: v1.0.0

$ curl $ingress -H 'Host: b.domain.com'
Host: my-app-b-v1-5766557f99-dpghc, Version: v1.0.0
```

To see the deployment in action, open a new terminal and run the following
command:

```
$ watch kubectl get po
```

Then deploy version 2 of both applications:

```
$ kubectl apply -f app-a-v2.yaml -f app-b-v2.yaml
```

Check the status of the deployment, then when all the pods are ready, you can
update the ingress:

```
$ kubectl apply -f ingress-v2.yaml
```

Test if the deployment was successful:

```
$ ingress=$(minikube service traefik-traefik --url | head -n1)
$ curl $ingress -H 'Host: a.domain.com'
Host: my-app-a-v2-6b58d47c5f-nmzds, Version: v2.0.0

$ curl $ingress -H 'Host: b.domain.com'
Host: my-app-b-v2-5c9dc59959-hp5kh, Version: v2.0.0
```

In case you need to rollback to the previous version:

```
$ kubectl apply -f ingress-v1.yaml
```

If everything is working as expected, you can then delete the v1.0.0 deployment:

```
$ kubectl delete -f ./app-a-v1.yaml -f ./app-b-v1.yaml
```

### Cleanup

```
$ kubectl delete all -l app=my-app
$ helm del --purge traefik
```
