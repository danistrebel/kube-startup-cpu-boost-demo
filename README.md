# Demo Kube Startup CPU Boost

## Demo on GKE

```sh
gcloud services enable container.googleapis.com --project $PROJECT_ID
gcloud compute networks create demo-network --subnet-mode=auto --project $PROJECT_ID
gcloud container clusters create demo-cluster \
  --enable-kubernetes-alpha --no-enable-autorepair --no-enable-autoupgrade \
  --zone europe-west1-b --network demo-network \
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

## Install Kube Startup CPU Boost Resources

```sh
kubectl apply -f https://github.com/google/kube-startup-cpu-boost/releases/download/v0.5.0/manifests.yaml
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

## Prepare for the grand show

ideally in 4 separate terminal windows next to one another run each of the following:

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
kubectl apply -f boost-double.yaml -n experiment
```

Then apply the four experiment scenarios via kustomization:

```sh
kubectl apply -k demo-app/overlays/constrained -n experiment
kubectl apply -k demo-app/overlays/startup-boost -n experiment
kubectl apply -k demo-app/overlays/unlimited -n experiment
kubectl apply -k demo-app/overlays/overprovisioned -n experiment
```

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
