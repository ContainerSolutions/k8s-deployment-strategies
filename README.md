Kubernetes deployment strategies
================================

In Kubernetes there is few different way to release an application, you have to carefully choose the right strategy
to make your infrastructure relisiant. Before experimenting, checkout the blog post about
[Kubernetes deployment strategies](https://container-solutions.com/kubernetes-deployment-strategies/)

- recreate: terminate the old version and release the new one
- ramped: release a new version on a rolling update fashion, one after the other
- blue/green: release a new version alongside the old version then switch traffic
- canary: release a new version to a subset of users, then proceed to a full rollout
- a/b testing: release a new version to a subset of users in a precise way (HTTP headers, cookie, weight, etc.). This doesn’t come out of the box with Kubernetes, it imply extra work to setup a more advanced infrastructure (Istio, Linkerd, Traeffik, custom nginx/haproxy, etc).


## Getting started

These examples were created and tested on [Minikube](http://github.com/kubernetes/minikube) running
with Kubernetes v1.7.2.

### Using minikube

```
# start Minikube
minikube start --kubernetes-version v1.7.2

# to speed up the deployment of the app, share Minikube Docker environment
eval $(minikube docker-env)

# build the Docker container used in the example
docker build -t docker build -t containersol/k8s-deployment-strategies-demo app
```
