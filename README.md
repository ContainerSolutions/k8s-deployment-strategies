Kubernetes deployment strategies
================================

> In Kubernetes there is few different way to release an application, you have
to carefully choose the right strategy to make your infrastructure relisiant.

Before experimenting, checkout the [CNCF prensentation](https://www.slideshare.net/EtienneTremel/kubernetes-deployment-strategies-cncf-webinar)
to the blog post about [Kubernetes deployment strategies](https://container-solutions.com/kubernetes-deployment-strategies/)
and [Six Strategies for Application Deployment](https://thenewstack.io/deployment-strategies/).

- [recreate](recreate/): terminate the old version and release the new one
- [ramped](ramped/): release a new version on a rolling update fashion, one
  after the other
- [blue/green](blue-green/): release a new version alongside the old version
  then switch traffic
- [canary](canary/): release a new version to a subset of users, then proceed
  to a full rollout
- [a/b testing](ab-testing/): release a new version to a subset of users in a
  precise way (HTTP headers, cookie, weight, etc.). This doesn’t come out of the
  box with Kubernetes, it imply extra work to setup a smarter
  loadbalancing system (Istio, Linkerd, Traeffik, custom nginx/haproxy, etc).
- [shadow](shadow/): release a new version alongside the old version. Incoming
  traffic is mirrored to the new version and doesn't impact the
  response.

![deployment strategy decision diagram](decision-diagram.png)


## Getting started

These examples were created and tested on GKE running with Kubernetes v1.8.8.

## Visualizing using Prometheus and Grafana

The following steps describe how to setup Prometheus and Grafana to visualize
the progress and performance of a deployment.

### Install Helm

To install Helm, follow the instructions provided on their
[website](https://github.com/kubernetes/helm/releases).

```
$ kubectl create serviceaccount tiller --namespace kube-system
$ kubectl create clusterrolebinding tiller \
      --clusterrole=cluster-admin \
      --serviceaccount=kube-system:tiller
$ helm init --upgrade --service-account tiller

```

### Install Prometheus

```
$ helm install \
    --name=prometheus \
    --version=5.0.1 \
    --set=serverFiles."prometheus\.yml".global.scrape_interval=3s \
    stable/prometheus
```

### Install Grafana

```
$ helm install \
   --name=grafana \
   --version=0.5.7 \
   --set=server.adminUser=admin \
   --set=server.adminPassword=admin \
   --set=server.service.type=LoadBalancer \
   stable/grafana
```

### Setup Grafana

Now that Prometheus and Grafana are up and running, you can access Grafana by
accessing its public IP:

```
$ kubectl get svc -o jsonpath="{.status.loadBalancer.ingress[0].ip}" grafana-grafana
```

To login, username: `admin`, password: `admin`.

Then you need to connect Grafana to Prometheus, to do so, add a DataSource:

```
Name: prometheus
Type: Prometheus
Url: http://prometheus-prometheus-server
Access: Proxy
```

Create a dashboard with a Graph. Use the following query:

```
sum(rate(http_requests_total{app="my-app"}[5m])) by (version)
```

To have a better overview of the version, add `{{version}}` in the legend field.

#### Example graph

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
