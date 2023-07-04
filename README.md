# Kubernetes deployment strategies (Azure Edition)

> In Kubernetes there are a few different ways to release an application, you have
to carefully choose the right strategy to make Microsoft Azure infrastructure resilient.

- [ ] [recreate](recreate/): terminate the old version and release the new one
  - [x] Application Gateway Ingress Controller
  - [ ] Azure Load Balancer + Istio service mesh add-on
  - [ ] Azure Load Balancer + Web Application Routing add-on
- [ ] [ramped](ramped/): release a new version on a rolling update fashion, one
  after the other
  - [x] Application Gateway Ingress Controller
  - [ ] Azure Load Balancer + Istio service mesh add-on
  - [ ] Azure Load Balancer + Web Application Routing add-on
- [ ] [blue/green](blue-green/): release a new version alongside the old version
  then switch traffic
  - [x] Application Gateway Ingress Controller
  - [ ] Azure Load Balancer + Istio service mesh add-on
  - [ ] Azure Load Balancer + Web Application Routing add-on
- [x] [canary](canary/): release a new version to a subset of users, then proceed
  to a full rollout
  - [x] Application Gateway Ingress Controller
  - [x] Azure Load Balancer + Istio service mesh add-on
  - [ ] Azure Load Balancer + Web Application Routing add-on
- [x] [a/b testing](ab-testing/): release a new version to a subset of users in a precise way (HTTP headers, cookie, weight, etc.). This doesn’t come out of the box with Kubernetes, it imply extra work to setup a smarter loadbalancing system (Istio, Linkerd, Traeffik, custom nginx/haproxy, etc).
  - [x] Azure Load Balancer + Istio service mesh add-on
  - [ ] Azure Load Balancer + Web Application Routing add-on
- [x] [shadow](shadow/): release a new version alongside the old version. Incoming
  traffic is mirrored to the new version and doesn't impact the
  response.
  - [x] Azure Load Balancer + Istio service mesh add-on
  - [ ] Azure Load Balancer + Web Application Routing add-on

## Deployment strategy Decision Diagram

![deployment strategy decision diagram](decision-diagram.png)

Before experimenting, checkout the following resources:

- [CNCF presentation](https://www.youtube.com/watch?v=1oPhfKye5Pg)
- [CNCF presentation slides](https://www.slideshare.net/EtienneTremel/kubernetes-deployment-strategies-cncf-webinar)
- [Kubernetes deployment strategies](https://container-solutions.com/kubernetes-deployment-strategies/)
- [Six Strategies for Application Deployment](https://thenewstack.io/deployment-strategies/).
- [Canary deployment using Istio and Helm](https://github.com/etiennetremel/istio-cross-namespace-canary-release-demo)
- [Automated rollback of Helm releases based on logs or metrics](https://container-solutions.com/automated-rollback-helm-releases-based-logs-metrics/)

## Support Strategy Matrix for Kubernetes Application Deployment on Azure Kubernetes Service

|   Strategy  | Use Applicationg Gateway Ingress Controller | Use Istio Service Mesh |                               Note                               |
|:-----------:|:-----------------:|:-----------------------:|----------------------------------------------------------------|
| Recreate    |        Yes        |           Yes           | Regardless of whether the Ingress Controller is selected or not. |
| Ramped      |        Yes        |           Yes           | One of the key functionalities of [Kubernetes Deployment][8]. |
| Blue/Green  |        Yes        |           Yes           | At the Kubernetes Deployment level, it is archieved by switching Kubernetes services. At the Kubernetes Cluster level, it is accomplished by utilizing Azure Traffic Manager or Azure FrontDoor for switching. |
| Canary      | Yes, but manually |           Yes           | Manually adjusting the number of replicas within the Kubernetes Deployment, or utilizing an Ingress Controller that supports the Traffic Shifting mechanism. |
| A/B Testing |         No        |           Yes           | The ingress controller needs to have a rule match mechanism (e.g. HTTP headers, cookie, weight, etc.) to determine the direction of traffic. |
| Shadow      |         No        |           Yes           | Currently, achieving this requires the use of a service mesh such as Istio. |

## Comparison of Azure Kubernetes Service Ingress Controllers

| Ingress Controller | Application Gateway Ingress Controller | Isito Ingress Gateway add-on | Web Application Routing add-on |
|--------------------|---------------------------------------|------------------------------|--------------------------------|
| Based on | Azure Application Gateway | Istio Ingress Gateway | Kubernetes Ingress-Nginx Controller |
| Docs | [AGIC](https://learn.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing) | [https://istio.io/](https://istio.io/)| [https://kubernetes.github.io/ingress-nginx/](https://kubernetes.github.io/ingress-nginx/) |
| Managed by | Azure | Azure | Azure |
| HTTP | Yes | Yes | Yes |
| HTTPS | Yes | Yes | Yes |
| TCP | No | Yes | Yes |
| UDP | No | No | Yes |
| Websocket | Yes | Yes | No |


## Getting started

### 1. Deploy Azure Kubernetes Service and other resources

These examples were created and tested on

|                       Azure Service                      | Azure Support Status |        Version       | Dependencies         |
|----------------------------------------------------------|:--------------------:|----------------------|----------------------|
| [Azure Kubernetes Service][9]                            | GA                   | v1.26.3              | N/A |
| [Azure Monitor managed service for Prometheus][1]        | GA                   |                      | N/A |
| [Azure Managed Grafana][4]                               | GA                   | v9.4.10 (5e7d575327) | Azure Monitor managed service |
| [Azure Application Gateway Ingress Controller (AGIC)][3] | GA                   | Standard_v2          | Azure Application Gateway |
| [Azure Service Mesh add-on (a.k.a Azure Managed Istio Service Mesh)][2]| Preview | v1.17 | Azure Load Balancer |
| [Web Application Routing add-on (a.k.a Azure Managed ingress-nginx)][10] | Preview | [v1.2.1][11] | Azure Application Gateway |
| Network Observability add-on | Preview | | Azure Monitor managed service for Prometheus / Azure Container Insight |

```bash
$ cd ./deploy
$ ./deploy-aks.sh
$ kubectl apply -f ama-metrics-prometheus-config.yml
$ kubectl apply -f ama-metrics-settings-configmap.yml
```

### 2. Import existing Grafana dashboard in Azure Managed Grafana

![](./images/azure-managed-grafana.png)

Create a dashboard with a Time series or import the [JSON export](grafana-dashboard.json).

Use the following query:

```yaml
sum(rate(http_requests_total{app="my-app"}[2m])) by (version)
```

![](./images/prometheus-query.png)

Since we installed [Azure Managed Prometheus][1] with cutomized settings, it is using the short scrape
interval of `10s` so the range cannot be lower than that.

To have a better overview of the version, add `{{version}}` in the legend field.

## 3. Show necessary information

The given code is a Bash script that retrieves information about various Azure and Kubernetes resources and displays them.

```bash
#!/bin/bash
RESOURCE_GROUP_NAME="rg-poc-aks"
AGIC_NAME="agic-poc-aks"
GRAFANA_NAME="grafana-poc-aks"

AKS_RESOURCE_GROUPNAME=$(az aks show -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP_NAME} --query "nodeResourceGroup" -o tsv)
APPGW_PIP=$(az network public-ip show --name ${AGIC_NAME}-appgwpip --resource-group ${AKS_RESOURCE_GROUPNAME} --query "ipAddress" -o tsv)
GRAFANA_URL=$(az grafana show -g ${RESOURCE_GROUP_NAME} -n ${GRAFANA_NAME} --query "properties.endpoint" -o tsv)
ISTIO_INGRESS_GATEWAY_PIP=$(kubectl get service -n aks-istio-ingress aks-istio-ingressgateway-external  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo
echo "Azure Application Gateway IP: ${APPGW_PIP}"
echo "Azure Managed Grafana URL: ${GRAFANA_URL}"
echo "Istio Ingress Gateway IP: ${ISTIO_INGRESS_GATEWAY_PIP}"
echo
```

## 4. Test script

![](./images/test-script.gif)

### Usage

This is a Python script that makes HTTP requests to a web link specified by the provided `AGIC-PUBLIC-IP` address. The script uses the requests library to send GET requests to the specified URL. It has error handling mechanisms to handle different types of exceptions that might occur during the request.

```bash
# Install colorama for colorized output if not already installed
pip3 install colorama

# Run the script
# Example:
# ./curl.py x.x.x.x
./curl.py $AGIC-PUBLIC-IP

# Run the script with a custom header
# Example:
# ./curl.py x.x.x.x test.aks.aliez.tw
./curl.py $AGIC-PUBLIC-IP $HEADER_HOST
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

### Cannot login Azure managed Grafana

it's a known issue, and wait to fix the issue.

Workaround with manual join permission before fixing the issue

1. Click "Azure Managed Grafana"
2. Click "Access control (IAM)"
3. Click "Add role assignment"
4. Select "Job function role: Grafana Admin" and Next
5. Click "+Select members" and choose your user account
6. Click "Review + assign"
7. Wait 3 mins for the role to be assigned
8. Login Grafana dashboard

### Troubleshoot collection of Prometheus metrics in Azure Monitor

Based on [Troubleshoot collection of Prometheus metrics in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/prometheus-metrics-troubleshoot)

```bash
kubectl port-forward ama-metrics-* -n kube-system 9090
```

![Port Forward prometheus](./images/port-forward-prometheus.png)


### Minimizing Downtime During Deployments with Azure Application Gateway Ingress Controller

Strong recommendation to read [Minimizing Downtime During Deployments](https://azure.github.io/application-gateway-kubernetes-ingress/how-tos/minimize-downtime-during-deployments/)

1. Regarding the `spec.terminationGracePeriodSeconds` parameter, please refer to [ramped/app-v1.yaml#30][5]
2. Regarding the `spec.containers[0].lifecycle.preStop` parameter, please refer to [ramped/app-v1.yaml#L53-L56][6]
3. Add connection draining annotation to the Ingress read by AGIC to allow for in-flight connections to complete, please refer to [ramped/app-v1.yaml#L65-L66][7]

[1]: https://learn.microsoft.com/en-Us/azure/azure-monitor/essentials/prometheus-metrics-overview
[2]: https://learn.microsoft.com/en-us/azure/aks/istio-about
[3]: https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview
[4]: https://learn.microsoft.com/en-us/azure/managed-grafana/
[5]: https://github.com/pichuang/k8s-deployment-strategies-azure-edition/blob/master/ramped/app-v1.yaml#L30
[6]: https://github.com/pichuang/k8s-deployment-strategies-azure-edition/blob/master/ramped/app-v1.yaml#L53-L56
[7]: https://github.com/pichuang/k8s-deployment-strategies-azure-edition/blob/master/ramped/app-v1.yaml#L65-L66
[8]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy
[9]: https://learn.microsoft.com/en-us/azure/aks/
[10]: https://learn.microsoft.com/en-us/azure/aks/web-app-routing?tabs=without-osm
[11]: https://github.com/Azure/AKS/blob/master/vhd-notes/aks-ubuntu/AKSUbuntu-2204/202305.24.0.txt#L80
