# Shadow deployment

> Version B receives real-world traffic alongside version A and doesn’t impact
the response.

![kubernetes shadow deployment](grafana-shadow.png)

A shadow deployment consists of releasing version B alongside version A, fork
version A’s incoming requests and send them to version B as well without
impacting production traffic. This is particularly useful to test production
load on a new feature. A rollout of the application is triggered when stability
and performance meet the requirements.

This technique is fairly complex to setup and needs special requirements,
especially with egress traffic. For example, given a shopping cart platform,
if you want to shadow test the payment service you can end-up having customers
paying twice for their order. In this case, you can solve it by creating a
mocking service that replicates the response from the provider.

In this example, we make use of [Istio](https://istio.io) to mirror traffic to
the secondary deployment.

## Steps to follow

1. version 1 is serving HTTP traffic using Istio
1. deploy version 2
1. mirror version 1 incoming traffic to version 2
1. wait enought time to confirm that version 2 is stable and not throwing
   unexpected errors
1. switch incoming traffic from version 1 to version 2

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
kubectl label namespace/ns-canary-istio istio.io/rev=asm-1-17
```

### Deploy both applications

Back to the shadow directory from this repo, deploy both applications using the
istioctl command to inject the Istio sidecar container which is used to proxy
requests:

```bash
$ kubectl apply -f app-v1.yaml -f app-v2.yaml
namespace/ns-shadow created
deployment.apps/deployment-my-app-v1 created
service/svc-my-app-v1 created
namespace/ns-shadow unchanged
deployment.apps/my-app-v2 created
service/svc-my-app-v2 created
```

Expose both services via the Istio Gateway and create a VirtualService to match
requests to the my-app-v1 service:

```bash
$ kubectl apply -f ./gateway.yaml -f ./virtualservice-wildcard.yaml
gateway.networking.istio.io/istio-http-gateway created
virtualservice.networking.istio.io/vs-wildcard-my-app created
```

At this point, if you make a request against the Istio ingress gateway with the
given host `shadow.aks.aliez.tw`, you should only see version 1 responding:

```bash
# Get the Istio ingress gateway IP
$ export ISTIO_INGRESS_GATEWAY_IP=$(kubectl get service aks-istio-ingressgateway-external \
    --namespace=aks-istio-ingress \
    --output='jsonpath={.status.loadBalancer.ingress[0].ip}')
$ echo $ISTIO_INGRESS_GATEWAY_IP
x.x.x.x

# Match virtualservice-wildcard rules, 100% traffic to v1.0.0
$ ./curl.py $ISTIO_INGRESS_GATEWAY_IP shadow.aks.aliez.tw
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
...omit...
```

### Enable traffic mirroring

```bash
$ kubectl apply -f ./virtualservice-mirror.yaml
virtualservice.networking.istio.io/vs-wildcard-my-app configured
```

Throw few requests to the service, only version 1 should be seen in the
response:

```bash
$ ./curl.py $ISTIO_INGRESS_GATEWAY_IP shadow.aks.aliez.tw
Host: deployment-my-app-v1-657c65694c-645mm, Version: v1.0.0
```

If you check the logs from both pods, you should see all version 1 incoming
requests being mirrored to version 2:

```bash
$ kubectl logs deployment/deployment-my-app-v1 -c my-app -n ns-shadow --tail=3
{"time":"2023-06-05T15:38:14Z","level":"info","version":"v1.0.0","host":"shadow.aks.aliez.tw","status":200,"size":61,"duration_ms":0.083701,"message":"request"}
{"time":"2023-06-05T15:38:14Z","level":"info","version":"v1.0.0","host":"shadow.aks.aliez.tw","status":200,"size":61,"duration_ms":0.091001,"message":"request"}
{"time":"2023-06-05T15:38:15Z","level":"info","version":"v1.0.0","host":"shadow.aks.aliez.tw","status":200,"size":61,"duration_ms":0.081701,"message":"request"}

$ kubectl logs deployment/deployment-my-app-v2 -c my-app -n ns-shadow --tail=3
{"time":"2023-06-05T15:39:11Z","level":"info","version":"v2.0.0","host":"shadow.aks.aliez.tw-shadow","status":200,"size":61,"duration_ms":0.101703,"message":"request"}
{"time":"2023-06-05T15:39:11Z","level":"info","version":"v2.0.0","host":"shadow.aks.aliez.tw-shadow","status":200,"size":61,"duration_ms":0.101502,"message":"request"}
{"time":"2023-06-05T15:39:12Z","level":"info","version":"v2.0.0","host":"shadow.aks.aliez.tw-shadow","status":200,"size":61,"duration_ms":0.096502,"message":"request"}
```

### Cleanup

```bash
$ kubectl delete -f .
namespace "ns-shadow" deleted
deployment.apps "deployment-my-app-v1" deleted
service "svc-my-app-v1" deleted
namespace "ns-shadow" deleted
deployment.apps "deployment-my-app-v2" deleted
service "svc-my-app-v2" deleted
gateway.networking.istio.io "istio-http-gateway" deleted
virtualservice.networking.istio.io "vs-mirror-my-app" deleted
virtualservice.networking.istio.io "vs-wildcard-my-app" deleted
```
