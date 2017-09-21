A/B testing using Istio
=======================

Deploy Istio to minikube using Helm:

```
$ helm init
$ helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
$ helm install --name service-mesh incubator/istio
```

Deploy the service and ingress:

```
$ kubectl apply -f ./service.yaml
$ kubectl apply -f ./ingress.yaml
```

Deploy the first application and use istioctl to inject a sidecar container to proxy all in and out
requests:

```
$ kubectl apply -f <(istioctl kube-inject -f app-v1.yaml)
```

Test if the deployment was successful:

```
$ curl $(minikube service istio-ingress --url | head -n1)
> 2017-09-20 12:42:33.416123892 +0000 UTC m=+55.563375310 - Host: my-app-177300127-sbd1d, Version: v1.0.0
```

Then deploy the version 2 of the application:

```
$ kubectl apply -f <(istioctl kube-inject -f app-v2.yaml)
```

Apply the load balancing rule:

```
$ istioctl create -f ./rules.yaml
```

You can now test if the traffic is correctly splitted amongst both versions:

```
$ export SERVICE_URL=$(minikube service istio-ingress --url | head -n1)
$ while sleep 0.1; do curl $SERVICE_URL; done;
```

You should see 1 request on 10 ending up in the version 2.

In the rules.yaml file, you can edit the weight of each route and apply the changes as follow:

```
$ istioctl replace -f ./rules.yaml
```



Cleanup:

```
$ kubectl delete all -l app=my-app
$ helm delete service-mesh
$ helm reset
```
