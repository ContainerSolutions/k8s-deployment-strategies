# Canary deployment using Istio service mesh

> In the following example, we will use the Istio service mesh provied by Azure to control
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

### Deploy the application

Deploy all of the yaml files in this directory

```bash
$ kubectl apply -f app-v1.yaml -f app-v2.yaml -f hpa.yaml -f istio.yaml
namespace/ns-canary-istio configured
deployment.apps/deployment-my-app-v1 created
service/svc-my-app created
namespace/ns-canary-istio unchanged
deployment.apps/deployment-my-app-v2 created
horizontalpodautoscaler.autoscaling/hpa-my-app-v1 created
horizontalpodautoscaler.autoscaling/hpa-my-app-v2 created
gateway.networking.istio.io/http-gateway created
virtualservice.networking.istio.io/vs-my-app created
destinationrule.networking.istio.io/my-app created
```

Ensure that both application pods are running

```bash
$ watch kubectl get pod -n ns-canary-istio
NAME                                    READY   STATUS    RESTARTS   AGE
deployment-my-app-v1-646c647798-926cj   2/2     Running   0          72s
deployment-my-app-v2-694f6f4698-d4jtb   2/2     Running   0          70s
```

In a new terminal, test if the deployments, services and routing rules are
working by sending lots of requests to the ingress gateway. v1.0.0 should
serve 50% of requests, and v2.0.0 should serve 50%

```bash
# Get the Istio ingress gateway IP
$ export ISTIO_INGRESS_GATEWAY_IP=$(kubectl get service aks-istio-ingressgateway-external \
    --namespace=aks-istio-ingress \
    --output='jsonpath={.status.loadBalancer.ingress[0].ip}')
$ echo $ISTIO_INGRESS_GATEWAY_IP
x.x.x.x

$ ./curl.py $ISTIO_INGRESS_GATEWAY_IP
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v1-646c647798-926cj, Version: v1.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v1-646c647798-926cj, Version: v1.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v1-646c647798-926cj, Version: v1.0.0
Host: deployment-my-app-v1-646c647798-926cj, Version: v1.0.0
Host: deployment-my-app-v1-646c647798-926cj, Version: v1.0.0
Host: deployment-my-app-v1-646c647798-926cj, Version: v1.0.0
Host: deployment-my-app-v1-646c647798-926cj, Version: v1.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
...omit...
```

Check the state of the horizontal pod autoscalers

```bash
$ kubectl get hpa -n ns-canary-istio
NAME            REFERENCE                         TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
hpa-my-app-v1   Deployment/deployment-my-app-v1   4%/50%    1         10        1          56m
hpa-my-app-v2   Deployment/deployment-my-app-v2   4%/50%    1         10        1          56m
```

Change the traffic distribution weights in istio.yaml so v2.0.0 serves 100% of
requests and v1.0.0 serves 0%, and reapply the file.
The fields can be found under VirtualService.spec.route[].weight

```bash
$ kubectl apply -f istio.yaml
gateway.networking.istio.io/istio-http-gateway configured
virtualservice.networking.istio.io/vs-my-app configured
destinationrule.networking.istio.io/my-app configured

# Run curl in watch in 2 or 3 terminals to induce more traffic so the horizontal pod autoscalers spin up more pods. Validate that all traffic is served by v2.0.0

$ ./curl.py x.x.x.x
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
Host: deployment-my-app-v2-694f6f4698-d4jtb, Version: v2.0.0
...omit...
```

### Cleanup

```bash
$ kubectl delete -f .
namespace "ns-canary-istio" deleted
deployment.apps "deployment-my-app-v1" deleted
service "svc-my-app" deleted
namespace "ns-canary-istio" deleted
deployment.apps "deployment-my-app-v2" deleted
horizontalpodautoscaler.autoscaling "hpa-my-app-v1" deleted
horizontalpodautoscaler.autoscaling "hpa-my-app-v2" deleted
gateway.networking.istio.io "istio-http-gateway" deleted
virtualservice.networking.istio.io "vs-my-app" deleted
destinationrule.networking.istio.io "my-app" deleted
```
