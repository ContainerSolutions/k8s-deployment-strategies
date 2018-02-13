Blue/green deployment
=====================

> Version B is released alongside version A, then the traffic is switched to
version B. Also known as red/black deployment.

![kubernetes blue-green deployment](grafana-blue-green.png)

The blue/green deployment strategy differs from a ramped deployment, version B
(green) is deployed alongside version A (blue) with exactly the same amount of
instances. After testing that the new version meets all the requirements the
traffic is switched from version A to version B at the load balancer level.

**You can apply the blue/green deployment technique for a single service or
multiple services using an Ingress controller:**

- [multiple services using Ingress](multiple-services/)
- [single service](single-service/)
