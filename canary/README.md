Canary deployment
=================

Deploy the first application:

```
$ kubectl apply -f app-v1.yaml
```

Test if the deployment was successful:

```
$ curl $(minikube service my-app --url)
> 2017-09-20 12:42:33.416123892 +0000 UTC m=+55.563375310 - Host: my-app-177300127-sbd1d, Version: v1.0.0
```

To see the deployment in action, open a new terminal and run a watch command to have a nice view on the progress:

```
$ watch -n1 kubectl get po
```

Then deploy the version 2 of the application:

```
$ kubectl apply -f app-v2.yaml
```

Only one pod with the new version should be running.

You can test if the second deployment was successful:

```
$ export SERVICE_URL=$(minikube service my-app --url)
$ while sleep 0.1; do curl $SERVICE_URL; done;
```

If you are happy with it, scale up the version 2 to 3 replicas:

```
kubectl scale --replicas=3 deploy my-app-v2
```

Then, when all pods are running, you can safely delete the old deployment:

```
kubectl delete deploy my-app-v1
```


Cleanup:

```
$ kubectl delete all -l app=my-app
```
