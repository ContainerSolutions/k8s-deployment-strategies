Blue/green deployment to release multiple services simultaneously
=================================================================

> In this example, we release a new version of 2 services simultaneously using
the blue/green deployment strategy. Azure [Application Gateway Ingress Controller](https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview) in used as
Ingress controller, this example would also work with the

- [Nginx Ingress controller](https://github.com/kubernetes/ingress-nginx).
- [Traefic Ingress Controller](https://traefik.io)
- [Contour Ingress Controller](https://projectcontour.io)

## Steps to follow

1. service a and b are serving traffic
1. deploy new version of both services
1. wait for all services to be ready
1. switch incoming traffic from version 1 to version 2
1. shutdown version 1

## In practice

```
# Deploy version 1 of application a and b and the ingress
$ kubectl apply -f app-a-v1.yaml -f app-b-v1.yaml -f ingress-v1.yaml
namespace/ns-bluegreen created
deployment.apps/deployment-my-app-a-v1 created
service/svc-my-app-a-v1 created
namespace/ns-bluegreen unchanged
deployment.apps/deployment-my-app-b-v1 created
service/svc-my-app-b-v1 created
ingress.networking.k8s.io/ingress-bluegreen created


# Test if you dont put header Host
$ export AGIC-PUBLIC-IP="apgw.aks.aliez.tw"
$ ./curl.py $AGIC-PUBLIC-IP
$ ./curl.py apgw.aks.aliez.tw
Error: Status code is 404 - count: 1
Error: Status code is 404 - count: 2
Error: Status code is 404 - count: 3
...omit...

# Test if the deployment was successful
$ export AGIC-PUBLIC-IP="apgw.aks.aliez.tw"
$ export SUBDOMAIN-A="a.aks.aliez.tw"
$ ./curl.py $AGIC-PUBLIC-IP $SUBDOMAIN-A
$ ./curl.py $SUBDOMAIN-A
$ ./curl.py a.aks.aliez.tw
$ ./curl.py apgw.aks.aliez.tw a.aks.aliez.tw
Host: deployment-my-app-a-v1-6f89cb4f67-xch6s, Version: v1.0.0
Host: deployment-my-app-a-v1-6f89cb4f67-xch6s, Version: v1.0.0
Host: deployment-my-app-a-v1-6f89cb4f67-m7b64, Version: v1.0.0
...omit...

$ ./curl.py $AGIC-PUBLIC-IP $SUBDOMAIN-B
$ ./curl.py $SUBDOMAIN-B
$ ./curl.py b.aks.aliez.tw
$ ./curl.py apgw.aks.aliez.tw b.aks.aliez.tw
Host: deployment-my-app-b-v1-755b6c7fb5-kgsth, Version: v1.0.0
Host: deployment-my-app-b-v1-755b6c7fb5-lcx89, Version: v1.0.0
Host: deployment-my-app-b-v1-755b6c7fb5-lcx89, Version: v1.0.0
...omit...

# To see the deployment in action, open a new terminal and run the following
# command
$ watch kubectl get pod -n ns-bluegreen
NAME                                      READY   STATUS    RESTARTS   AGE
deployment-my-app-a-v1-6f89cb4f67-m7b64   1/1     Running   0          15m
deployment-my-app-a-v1-6f89cb4f67-xch6s   1/1     Running   0          15m
deployment-my-app-b-v1-755b6c7fb5-kgsth   1/1     Running   0          15m
deployment-my-app-b-v1-755b6c7fb5-lcx89   1/1     Running   0          15m

# Then deploy version 2 of both applications
$ kubectl apply -f app-a-v2.yaml -f app-b-v2.yaml
namespace/ns-bluegreen unchanged
deployment.apps/deployment-my-app-a-v2 created
service/svc-my-app-a-v2 created
namespace/ns-bluegreen unchanged
deployment.apps/deployment-my-app-b-v2 created
service/svc-my-app-b-v2 created

# Wait for both applications to be running
$ kubectl rollout status deployment/deployment-my-app-a-v2 -n ns-bluegreen -w
deployment "deployment-my-app-a-v2" successfully rolled out

$ kubectl rollout status deployment/deployment-my-app-b-v2 -n ns-bluegreen -w
deployment "deployment-my-app-b-v2" successfully rolled out

# To see the deployment in action, open a new terminal and run the following
# command
$ watch kubectl get pod -n ns-bluegreen
NAME                                      READY   STATUS    RESTARTS   AGE
deployment-my-app-a-v1-6f89cb4f67-m7b64   1/1     Running   0          19m
deployment-my-app-a-v1-6f89cb4f67-xch6s   1/1     Running   0          19m
deployment-my-app-a-v2-784d495c9f-5pwv5   1/1     Running   0          3m17s
deployment-my-app-a-v2-784d495c9f-bsdvb   1/1     Running   0          3m17s
deployment-my-app-b-v1-755b6c7fb5-kgsth   1/1     Running   0          19m
deployment-my-app-b-v1-755b6c7fb5-lcx89   1/1     Running   0          19m
deployment-my-app-b-v2-86b59d6bf7-pprnl   1/1     Running   0          3m16s
deployment-my-app-b-v2-86b59d6bf7-vc9dg   1/1     Running   0          3m16s
...omit...

# Check the status of the deployment, then when all the pods are ready, you can update the ingress
$ kubectl apply -f ingress-v2.yaml
ingress.networking.k8s.io/ingress-bluegreen configured

# Test if the deployment was successful
$ ./curl.py $AGIC-PUBLIC-IP $SUBDOMAIN-A
$ ./curl.py apgw.aks.aliez.tw a.aks.aliez.tw
...omit...
Host: deployment-my-app-a-v1-6f89cb4f67-xch6s, Version: v1.0.0
Host: deployment-my-app-a-v1-6f89cb4f67-m7b64, Version: v1.0.0
Host: deployment-my-app-a-v1-6f89cb4f67-m7b64, Version: v1.0.0
Host: deployment-my-app-a-v2-784d495c9f-bsdvb, Version: v2.0.0
Host: deployment-my-app-a-v2-784d495c9f-bsdvb, Version: v2.0.0
Host: deployment-my-app-a-v2-784d495c9f-5pwv5, Version: v2.0.0
...omit...


$ ./curl.py $AGIC-PUBLIC-IP $SUBDOMAIN-B
$ ./curl.py apgw.aks.aliez.tw b.aks.aliez.tw
...omit...
Host: deployment-my-app-b-v1-755b6c7fb5-lcx89, Version: v1.0.0
Host: deployment-my-app-b-v1-755b6c7fb5-kgsth, Version: v1.0.0
Host: deployment-my-app-b-v1-755b6c7fb5-lcx89, Version: v1.0.0
Host: deployment-my-app-b-v2-86b59d6bf7-pprnl, Version: v2.0.0
Host: deployment-my-app-b-v2-86b59d6bf7-pprnl, Version: v2.0.0
Host: deployment-my-app-b-v2-86b59d6bf7-vc9dg, Version: v2.0.0
...omit...

# In case you need to rollback to the previous version
$ kubectl apply -f ingress-v1.yaml
ingress.networking.k8s.io/ingress-bluegreen configured

# If everything is working as expected, you can then delete the v1.0.0
# deployment
$ kubectl delete -f ./app-a-v1.yaml -f ./app-b-v1.yaml
```

### Cleanup

```bash
$ kubectl delete all -l app=my-app -n ns-bluegreen
```
