# Kubernetes deployment strategies (Azure Edition)

> In Kubernetes there are a few different ways to release an application, you have
to carefully choose the right strategy to make your infrastructure resilient.

- [ ] [recreate](recreate/): terminate the old version and release the new one
  - [x] Application Gateway Ingress Controller
  - [ ] Azure Load Balancer + Istio service mesh
- [ ] [ramped](ramped/): release a new version on a rolling update fashion, one
  after the other
  - [x] Application Gateway Ingress Controller
  - [ ] Azure Load Balancer + Istio service mesh
- [ ] [blue/green](blue-green/): release a new version alongside the old version
  then switch traffic
  - [x] Application Gateway Ingress Controller
  - [ ] Azure Load Balancer + Istio service mesh
- [x] [canary](canary/): release a new version to a subset of users, then proceed
  to a full rollout
  - [x] Application Gateway Ingress Controller: Due to the lack of support for traffic weight functionality, we use manually modified replicas count to achieve the same effect.
  - [x] Azure Load Balancer + Istio service mesh
- [ ] [a/b testing](ab-testing/): release a new version to a subset of users in a precise way (HTTP headers, cookie, weight, etc.). This doesn’t come out of the box with Kubernetes, it imply extra work to setup a smarter loadbalancing system (Istio, Linkerd, Traeffik, custom nginx/haproxy, etc).
  - [ ] Azure Load Balancer + Istio service mesh
- [ ] [shadow](shadow/): release a new version alongside the old version. Incoming
  traffic is mirrored to the new version and doesn't impact the
  response.
  - [ ] Azure Load Balancer + Istio service mesh

![deployment strategy decision diagram](decision-diagram.png)

Before experimenting, checkout the following resources:

- [CNCF presentation](https://www.youtube.com/watch?v=1oPhfKye5Pg)
- [CNCF presentation slides](https://www.slideshare.net/EtienneTremel/kubernetes-deployment-strategies-cncf-webinar)
- [Kubernetes deployment strategies](https://container-solutions.com/kubernetes-deployment-strategies/)
- [Six Strategies for Application Deployment](https://thenewstack.io/deployment-strategies/).
- [Canary deployment using Istio and Helm](https://github.com/etiennetremel/istio-cross-namespace-canary-release-demo)
- [Automated rollback of Helm releases based on logs or metrics](https://container-solutions.com/automated-rollback-helm-releases-based-logs-metrics/)

## Getting started

These examples were created and tested on

- Azure Kubernetes Service v1.26.3
- Azure Service Mesh (Istio Service Mesh) v1.17
- Azure Application Gateway Ingress Controller (AGIC) Standard v2
- Azure Monitor managed service for Prometheus
- Azure Monitor managed service for Grafana v9.4.10 (5e7d575327)

## Deploy Azure Kubernetes Service and other resources

```bash
$ cd ./deploy
$ ./deploy-aks.sh
$ kubectl apply -f ama-metrics-prometheus-config.yml
$ kubectl apply -f ama-metrics-settings-configmap.yml
```

## Import Grafana dashboard in Azure Managed Grafana

![](./images/azure-managed-grafana.png)

Create a dashboard with a Time series or import the [JSON export](grafana-dashboard.json). Use the following query:

```
sum(rate(http_requests_total{app="my-app"}[2m])) by (version)
```

![](./images/prometheus-query.png)

Since we installed Prometheus with default settings, it is using the default scrape
interval of `1m` so the range cannot be lower than that.

To have a better overview of the version, add `{{version}}` in the legend field.

## Curl script

### Before you begin

```bash
pip3 install colorama
```

### Usage

This is a Python script that makes HTTP requests to a web link specified by the provided AIGC-PUBLIC-IP address. The script uses the requests library to send GET requests to the specified URL. It has error handling mechanisms to handle different types of exceptions that might occur during the request.

```bash
./curl.py AIGC-PUBLIC-IP
```

The script continues to run indefinitely, making periodic requests to the web link and monitoring for errors.

## Example graph

Recreate:

![Kubernetes deployment recreate](recreate/grafana-recreate.png)

Ramped:

![Kubernetes deployment ramped](ramped/grafana-ramped.png)

Blue/Green:

![Kubernetes deployment blue-green](blue-green/grafana-blue-green.png)

Canary:

![Kubernetes deployment canary](canary/grafana-canary.png)

A/B testing:

![kubernetes ab-testing deployment](ab-testing/grafana-ab-testing.png)

Shadow:

![kubernetes shadow deployment](shadow/grafana-shadow.png)


## Troubleshooting

### Troubleshoot collection of Prometheus metrics in Azure Monitor

Based on [Troubleshoot collection of Prometheus metrics in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/prometheus-metrics-troubleshoot)

```bash
kubectl port-forward ama-metrics-* -n kube-system 9090
```

![Port Forward prometheus](./images/port-forward-prometheus.png)