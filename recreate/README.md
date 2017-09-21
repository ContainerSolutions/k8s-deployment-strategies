Recreate deployment
===================

Deploy the first application

```
$ kubectl apply -f app-v1.yaml
```

Test if the deployment was successful:

```
$ curl $(minikube service my-app --url)
> 2017-09-20 12:42:33.416123892 +0000 UTC m=+55.563375310 - Host: my-app-177300127-sbd1d, Version: v1.0.0
```

To see the deployment in action, open a new terminal and run the following command:

```
$ watch -n1 kubectl get po
```

Then deploy the version 2 of the application:

```
$ kubectl apply -f app-v2.yaml
```

Test the second deployment progress:

```
$ export SERVICE_URL=$(minikube service my-app --url)
$ while sleep 0.1; do curl $SERVICE_URL; done;
```


Cleanup:

```
$ kubectl delete all -l app=my-app
```
