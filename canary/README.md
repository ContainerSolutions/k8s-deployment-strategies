# Canary deployment

> Version B is released to a subset of users, then proceed to a full rollout.

![kubernetes canary deployment](grafana-canary.png)

A canary deployment consists of gradually shifting production traffic from
version A to version B. Usually the traffic is split based on weight. For
example, 90 percent of the requests go to version A, 10 percent go to version B.

This technique is mostly used when the tests are lacking or not reliable or if
there is little confidence about the stability of the new release on the
platform.

**You can apply the canary deployment technique using the native way by
adjusting the number of replicas or if you use Nginx as Ingress controller you
can define fine grained traffic splitting via Ingress annotations.**

- [Application Gateway Ingress Controller](application-gateway-ingress-controller/)
- [Istio service mesh add-on](istio-service-mesh-addon/)


## Limitation

- Application Gateway Ingress Controller doesn't support Traffic Shifting.