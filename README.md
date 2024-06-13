# Demo Kube Startup CPU Boost

This is repository contains a demo script to showcase the [Kube Startup CPU Boost](https://github.com/google/kube-startup-cpu-boost) controller and was used during the lightning talk at the 2024 Kubernetes Community Day in Zurich.

## Demo on GKE

```sh
gcloud services enable container.googleapis.com --project $PROJECT_ID
gcloud compute networks create demo-network --subnet-mode=auto --project $PROJECT_ID
gcloud container clusters create demo-cluster \
  --enable-kubernetes-alpha --no-enable-autorepair --no-enable-autoupgrade \
  --region europe-west1-b --network demo-network \
  --num-nodes 1 --machine-type=e2-standard-4 \
  --project $PROJECT_ID

gcloud container node-pools create experiment \
  --cluster demo-cluster\
  --no-enable-autorepair --no-enable-autoupgrade \
  --node-taints dedicated=experiment:NoSchedule \
  --zone europe-west1-b \
  --num-nodes 4 --machine-type=e2-standard-4 \
  --project $PROJECT_ID
```

check if the ALPHA feature gate is enabled:

```sh
kubectl get --raw /metrics | grep kubernetes_feature_enabled | grep InPlacePodVerticalScaling
```

This should return something like:

```txt
kubernetes_feature_enabled{name="InPlacePodVerticalScaling",stage="ALPHA"} 1
```

## Install Kube Startup CPU Boost Resources

```sh
kubectl apply -f https://github.com/google/kube-startup-cpu-boost/releases/download/v0.8.1/manifests.yaml
```

Check the controller is up and running:

```sh
kubectl get po -n kube-startup-cpu-boost-system
kubectl logs deploy/kube-startup-cpu-boost-controller-manager -n kube-startup-cpu-boost-system
```

## Create the experiment namespace

```sh
kubectl create ns experiment
```

## Manual Live Pod Resources Update

In one terminal window run the following watch command to observe the pod's resources:


```sh
watch kubectl get pods -n experiment -o jsonpath='{.items[*].spec.containers[*].resources}'
```

In another terminal window run starte the demo pod in the example namespace:

```sh
kubectl apply -k demo-app/base -n experiment 
POD_NAME=$(kubectl get po -l app.kubernetes.io/name=spring-demo-app -n experiment -o "jsonpath={.items[0].metadata.name}")
```

And then patch the pod with the resources and later restore the original values:

```sh
# Set the CPU requests to the double amount
kubectl patch pod $POD_NAME -n experiment -p '{"spec":{"containers":[{"name": "spring-app", "resources":{"requests":{"cpu":"1"}, "limits":{"cpu":"2"}}}]}}'


kubectl patch pod $POD_NAME -n experiment -p '{"spec":{"containers":[{"name": "spring-app", "resources":{"requests":{"cpu":"0.5"}, "limits":{"cpu":"1"}}}]}}'
```

With this we can show that we can resize the pod's resources on the fly without pod restarts.

![Manual Patch](img/manual.gif)

## Prepare for the grand show

Ideally in 4 separate terminal windows next to one another run each of the following:

### Feature: Startup CPU Boost Controller

```sh
./util/demo-log.sh startup-cpu-boost
```

### Baseline: CPU sized for a running container

```sh
./util/demo-log.sh constrained
```

### Baseline: CPU sized for a container starting up

```sh
./util/demo-log.sh overprovisioned
```

### Baseline: Container with unset CPU Limit

```sh
./util/demo-log.sh unlimited
```

## Create the four experiment scenarios

Apply the CPU Boost CR

```sh
kubectl apply -f demo-app/boost-double.yaml -n experiment
```

Then apply the four experiment scenarios via kustomization:

```sh
kubectl apply -k demo-app/overlays/constrained -n experiment
kubectl apply -k demo-app/overlays/startup-boost -n experiment
kubectl apply -k demo-app/overlays/unlimited -n experiment
kubectl apply -k demo-app/overlays/overprovisioned -n experiment
```

In the previously prepared views you can see how the startup CPU boost controller bumps the CPU requests of the container until it reached the ready state and then restores the resource requests. You can also compare the startup time against the other three scenarios.

![Startup CPU Boost](img/startup-cpu-boost.gif)

## Clean Up

### Remove all experiments (e.g. to restart the demo)

```sh
kubectl delete -k demo-app/overlays/constrained -n experiment
kubectl delete -k demo-app/overlays/startup-boost -n experiment
kubectl delete -k demo-app/overlays/unlimited -n experiment
kubectl delete -k demo-app/overlays/overprovisioned -n experiment
```

### Delete the demo cluster

```sh
gcloud container clusters delete demo-cluster --zone europe-west1-b --project $PROJECT_ID
gcloud compute networks delete demo-network --project $PROJECT_ID
```

## License

[Apache License 2.0](LICENSE)
