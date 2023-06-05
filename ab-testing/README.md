# A/B testing using Istio service mesh

> Version B is released to a subset of users under specific condition.

![kubernetes ab-testing deployment](grafana-ab-testing.png)

A/B testing deployments consists of routing a subset of users to a new
functionality under specific conditions. It is usually a technique for making
business decisions based on statistics rather than a deployment strategy.
However, it is related and can be implemented by adding extra functionality to a
canary deployment so we will briefly discuss it here.

This technique is widely used to test conversion of a given feature and only
roll-out the version that converts the most.

Here is a list of conditions that can be used to distribute traffic amongst the
versions:

- [Weight](https://istio.io/latest/docs/reference/config/networking/virtual-service/#RouteDestination)
- [Headers](https://istio.io/latest/docs/reference/config/networking/virtual-service/#Headers)
- Query parameters
- Geolocalisation
- Technology support: browser version, screen size, operating system, etc.
- Language

## Steps to follow

1. version 1 is serving HTTP traffic using Istio service mesh
2. deploy version 2
3. wait until all instances are ready
4. update Istio VirtualService with 80% traffic targetting version 1 and 20% traffic targetting version 2

## In practice

### Verify Istio service mesh add-on is enabled and workable

Watch and verify that all `aks-istio-*` pods have are running/completed

```bash
$ watch kubectl get pods -n aks-istio-system
NAME                             READY   STATUS    RESTARTS   AGE
istiod-asm-1-17-bd9bc86f-9rnbs   1/1     Running   0          3h32m
istiod-asm-1-17-bd9bc86f-m9xjj   1/1     Running   0          3h33m

$ watch kubectl get svc aks-istio-ingressgateway-external -n aks-istio-ingress
NAME                                TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                                      AGE
aks-istio-ingressgateway-external   LoadBalancer   10.0.216.248   x.x.x.x   15021:32542/TCP,80:31236/TCP,443:31306/TCP   87m
```

### Enable sidecar injection for the namespace level

To automatically install sidecar to any new pods, annotate your namespaces:

```yaml
# The default istio-injection=enabled labeling doesn't work. Explicit versioning (istio.io/rev=asm-1-17) is required.
kubectl label namespace/ns-ab-testing istio.io/rev=asm-1-17
```

### Deploy both applications

```bash
$ kubectl apply -f app-v1.yaml -f app-v2.yaml
namespace/ns-ab-testing created
deployment.apps/deployment-my-app-v1 created
service/svc-my-app-v1 created
namespace/ns-ab-testing unchanged
deployment.apps/deployment-my-app-v2 created
service/my-app-v2 created
```

Expose both services via the Istio Gateway and create a VirtualService to match requests to the my-app-v1 service:

```bash
$ kubectl apply -f ./gateway.yaml -f ./virtualservice-wildcard.yaml
gateway.networking.istio.io/istio-http-gateway created
virtualservice.networking.istio.io/vs-wildcard-my-app created
```

At this point, if you make a request against the Istio ingress gateway with the
given host `test.aks.aliez.tw`, you should only see version 1 responding:

```bash
# Get the Istio ingress gateway IP
$ export ISTIO_INGRESS_GATEWAY_IP=$(kubectl get service aks-istio-ingressgateway-external \
    --namespace=aks-istio-ingress \
    --output='jsonpath={.status.loadBalancer.ingress[0].ip}')
$ echo $ISTIO_INGRESS_GATEWAY_IP
x.x.x.x

# Match virtualservice-wildcard rules, 100% traffic to v1.0.0
$ ./curl.py $ISTIO_INGRESS_GATEWAY_IP
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
...omit...
```

### Shift traffic based on weight

Apply the Istio VirtualService rule based on weight:

```bash
$ kubectl apply -f ./virtualservice-weight.yaml
virtualservice.networking.istio.io/vs-weight-my-app configured
```

You can now test if the traffic is correctly splitted amongst both versions:

```bash
# Match virtualservice-weight rules, 20% traffic to v1.0.0, 80% traffic to v2.0.0
# Host: test.aks.aliez.tw
$ ./curl.py $ISTIO_INGRESS_GATEWAY_IP test.aks.aliez.tw
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
Host: deployment-my-app-v2-6f976cb5c9-nkx69, Version: v2.0.0
Host: deployment-my-app-v2-6f976cb5c9-nkx69, Version: v2.0.0
Host: deployment-my-app-v2-6f976cb5c9-nkx69, Version: v2.0.0
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
Host: deployment-my-app-v2-6f976cb5c9-nkx69, Version: v2.0.0
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
Host: deployment-my-app-v2-6f976cb5c9-nkx69, Version: v2.0.0
Host: deployment-my-app-v2-6f976cb5c9-nkx69, Version: v2.0.0
Host: deployment-my-app-v2-6f976cb5c9-nkx69, Version: v2.0.0
...omit...
```

You should approximately see 8 requests on 10 ending up in the version 2.

In the `./virtualservice-weight.yaml` file, you can edit the weight of each
destination and apply the updated rule to Minikube:

```bash
$ kubectl apply -f ./virtualservice-weight.yaml
virtualservice.networking.istio.io/vs-weight-my-app configured
```

### Shift traffic based on headers

Apply the Istio VirtualService rule based on headers:

```bash
$ kubectl apply -f ./virtualservice-match.yaml
virtualservice.networking.istio.io/vs-match-my-app configured
```

You can now test if the traffic is hitting the correct set of instances:

```bash
$ curl $ISTIO_INGRESS_GATEWAY_IP -H 'Host: uat.aks.aliez.tw' -H 'X-API-Version: v1.0.0'
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0

$ curl $ISTIO_INGRESS_GATEWAY_IP -H 'Host: uat.aks.aliez.tw' -H 'X-API-Version: v2.0.0'
Host: deployment-my-app-v2-6f976cb5c9-nkx69, Version: v2.0.0
```

### Cleanup

```bash
$ kubectl delete -f .
namespace "ns-ab-testing" deleted
deployment.apps "deployment-my-app-v1" deleted
service "svc-my-app-v1" deleted
namespace "ns-ab-testing" deleted
deployment.apps "deployment-my-app-v2" deleted
service "svc-my-app-v2" deleted
gateway.networking.istio.io "istio-http-gateway" deleted
virtualservice.networking.istio.io "vs-match-my-app" deleted
virtualservice.networking.istio.io "vs-weight-my-app" deleted
virtualservice.networking.istio.io "vs-wildcard-my-app" deleted
```
