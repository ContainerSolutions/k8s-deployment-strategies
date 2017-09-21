Kubernetes deployment strategies
================================

In Kubernetes there is few different way to release an application, you have to carefully choose the right strategy
to make your infrastructure relisiant. Before experimenting, checkout the blog post about
[Kubernetes deployment strategies](link)


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
