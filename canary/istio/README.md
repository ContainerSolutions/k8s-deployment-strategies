Canary deployment using Istio service mesh
==========================================================

> In the following example, we will use the Istio service mesh to control
traffic distribution for a canary deployment using an example application
This is very similar to the Istio A/B testing example, however instead of
serving a specific subset of clients based on headers, we are simply dividing
the traffic in the desired ratios. As stateful connections could be a problem
in this scenario, it is reccomended to serve clients based on some identifying
data (ie. cookies or headers) like the A/B example if needed.

## Steps to follow

1. Deploy istio on the cluster
1. Deploy two versions of the application
1. Set up an istio virtual service and rule to control the traffic distribution
1. Set up autoscaling on both deployments
1. Verify that traffic is divided as expected and pods scale accordingly
1. Change the traffic distribution
1. Verify that traffic is divided as expected
1. Increase traffic
1. Verify pods scale accordingly

## In practice

If you're using minikube you'll need to prepare the environment for horizontal
pod autoscaling and load balancing:

```bash
# Enable heapster and metrics-server
$ minikube addons enable heapster
$ minikube addons enable metrics-server

# Start minikube tunnel in a seperate terminal to route traffic from outside
# the cluster to the istio-ingressgateway clusterIP
$ minikube tunnel
```

Deploy istio to your cluster

```bash
$ curl -L https://git.io/getLatestIstio | ISTIO_VERSION=1.1.1 sh -
$ cd istio-1.1.1
$ for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
$ kubectl apply -f install/kubernetes/istio-demo.yaml
$ cd ..
```

Watch and verify that all istio pods have are running/completed
This may take a few minutes and some crashes are normal

```bash
$ watch kubectl get po --namespace=istio-system
```

Deploy all of the yaml files in this directory

TODO: Split files and apply/verify seperately

```bash
$ kubectl apply -f .
```

Ensure that both application pods are running

```bash
$ watch kubectl get po
```

In a new terminal, test if the deployments, services and routing rules are
working by sending lots of requests to the ingress gateway. v1.0.0 should
serve 90% of requests, and v2.0.0 should serve 10%

```bash
$ watch -n 0.1 'curl $(kubectl get service istio-ingressgateway \
    --namespace=istio-system \
    --output='jsonpath={.spec.clusterIP}')
```

Check the state of the horizontal pod autoscalers

```bash
$ kubectl get hpa
```

Change the traffic distribution weights in istio.yaml so v2.0.0 serves 100% of
requests and v1.0.0 serves 0%, and reapply the file.
The fields can be found under VirtualService.spec.route[].weight

TODO: use sed to change values or kubectl edit...?

```bash
$ kubectl apply -f istio.yaml
```

Run curl in watch in 2 or 3 terminals to induce more traffic so the
horizontal pod autoscalers spin up more pods. Validate that all traffic is 
served by v2.0.0

```bash
$ watch -n 0.1 'curl $(kubectl get service istio-ingressgateway \
    --namespace=istio-system \
    --output='jsonpath={.spec.clusterIP}')
```

Watch the v2 pods scale up as the cpu load increases

```bash
$ watch kubectl get hpa
```

### Cleanup

```bash
$ kubectl delete -f .
$ cd istio-1.1.1
$ kubectl delete -f install/kubernetes/istio-demo.yaml
$ for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl delete -f $i; done
```
