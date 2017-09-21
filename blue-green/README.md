Blue green deployment
=====================


Deploy the first application

```
$ kubectl apply -f app-v1.yaml
```

Test if the deployment was successful

```
$ curl $(minikube service my-app --url)
> 2017-09-20 12:42:33.416123892 +0000 UTC m=+55.563375310 - Host: my-app-177300127-sbd1d, Version: v1.0.0
```

To see the deployment in action, open a new terminal and run the following command:

```
$ watch -n1 kubectl get po
```

Then deploy the version 2 of the application

```
$ kubectl apply -f app-v2.yaml
```

Side by side, 3 pods are running with version 2 but the service still send traffic to the first deployment.

If necessary, you can manually test one of the pod by port-forwarding it to your local environment.


Once your are ready, you can switch the traffic to the new version by patching the service to send traffic
to all pods with label version=v2.0.0:

```
$ kubectl patch service my-app -p '{"spec":{"selector":{"version":"v2.0.0"}}}'
```

Test if the second deployment was successful

```
$ export SERVICE_URL=$(minikube service my-app --url)
$ while sleep 0.1; do curl $SERVICE_URL; done;
```

In case you need to rollback to the previous version:

```
$ kubectl patch service my-app -p '{"spec":{"selector":{"version":"v1.0.0"}}}'
```

If everything is working as expected, you can then delete the v1.0.0 deployment:

```
$ kubectl delete deploy my-app-v1
```


Cleanup

```
$ kubectl delete all -l app=my-app
```
