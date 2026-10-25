- `kubectl get nodes` → 1 server and 2 agents, all Ready. The server runs the API. The agents are the machines that will run pods.

- `k get pods -A -o wide` →
NAMESPACE     NAME                                      READY   STATUS      RESTARTS   AGE     IP          NODE                      NOMINATED NODE   READINESS GATES
kube-system   coredns-8db54c48d-dmzhd                   1/1     Running     0          8m40s   10.42.0.3   k3d-sluice-dev-server-0   <none>           <none>
kube-system   helm-install-traefik-crd-r5fcs            0/1     Completed   0          8m36s   10.42.1.3   k3d-sluice-dev-agent-1    <none>           <none>
kube-system   helm-install-traefik-qcjv6                0/1     Completed   2          8m36s   10.42.3.2   k3d-sluice-dev-agent-0    <none>           <none>
kube-system   local-path-provisioner-5d9d9885bc-fbxk8   1/1     Running     0          8m39s   10.42.0.2   k3d-sluice-dev-server-0   <none>           <none>
kube-system   metrics-server-786d997795-gprhr           1/1     Running     0          8m38s   10.42.1.2   k3d-sluice-dev-agent-1    <none>           <none>
kube-system   svclb-traefik-2dc16f33-2tlqq              2/2     Running     0          7m41s   10.42.0.4   k3d-sluice-dev-server-0   <none>           <none>
kube-system   svclb-traefik-2dc16f33-dz5fl              2/2     Running     0          7m41s   10.42.3.3   k3d-sluice-dev-agent-0    <none>           <none>
kube-system   svclb-traefik-2dc16f33-wzpjf              2/2     Running     0          7m41s   10.42.1.4   k3d-sluice-dev-agent-1    <none>           <none>
kube-system   traefik-9bcdbbd9-24pbm                    1/1     Running     0          7m41s   10.42.1.5   k3d-sluice-dev-agent-1    <none>           <none>

coredns answers names inside the cluster. A pod that asks for my-service gets that service's IP from CoreDNS.
traefik is the ingress controller. It receives HTTP from outside the cluster and routes it to the right service.
svclb (often svclb-traefik) is k3s's load balancer. It opens the Traefik port on each node so a LoadBalancer service has somewhere to land.
local-path-provisioner creates a folder on the node when a pod asks for storage, and hands that folder over as a volume.
metrics-server collects CPU and memory use so kubectl top and autoscaling have numbers to read.

- `k describe node k3d-sluice-dev-agent-1`→
Allocatable:
  cpu:                14
  ephemeral-storage:  461200284925
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  hugepages-32Mi:     0
  hugepages-64Ki:     0
  memory:             8124000Ki
  pods:               110

- `kubectl describe quota -n team-cases` →
Resource       Used   Hard
limits.cpu     600m   2
limits.memory  384Mi  2Gi
pods           3      5

- `kubectl scale deploy/nginx --replicas=10 -n team-cases` then `kubectl describe rs -n team-cases` →
Error creating: pods "nginx-655ff8cc99-w62hc" is forbidden: exceeded quota: team-cases, requested: pods=1, used: pods=5, limited: pods=5

The quota stopped the namespace at 5 pods. The Deployment still wants 10, and the ReplicaSet keeps failing to create the rest.

- `kubectl exec -n team-policy curl -- curl http://nginx.team-cases.svc.cluster.local/` → `baseline_http=200`. No NetworkPolicy yet, so team-policy can reach the nginx Service.

- Applied `default-deny-ingress` in `team-cases`. Same curl → exit 7, `Could not connect to server`. DNS still resolved. The policy drops the connection.

- Applied `allow-from-policy`, ingress from namespaces labelled `tenant: policy` to port 80. Same curl → `after_allow_http=200`.

- Applied `default-deny-egress` in `team-policy`. Same curl → exit 6, `Could not resolve host`. Egress deny blocks DNS before it blocks HTTP.

- Applied `allow-dns` (UDP/TCP 53 to `k8s-app=kube-dns` in `kube-system`). Same curl → exit 7, `Could not connect`. The name resolves, and the packet to nginx is still blocked.

- Applied `allow-nginx` (TCP 80 to `team-cases`). Same curl → `after_egress_allow_http=200`.

- `helm template hello deploy/helm/hello` renders a Deployment and a ClusterIP Service. `replicaCount`, `image.tag`, and `resources` come from `values.yaml`.
- `helm install hello deploy/helm/hello -n team-cases` → revision 1, 1 replica.
- `helm upgrade hello deploy/helm/hello -n team-cases --set replicaCount=2` → revision 2, 2/2 ready.
- `helm rollback hello 1 -n team-cases` → revision 3, deployed chart is the revision 1 values, 1/1 ready.

Helm keeps the raw YAML as a template, and each install or upgrade is a numbered release you can roll back. The hand-written `docs/nginx.yaml` has no history. Changing it means applying the file again.

## What surprised me

`apiVersion` is case-sensitive. `apiversion` made `kubectl apply` say the field was missing.

The quota error is on the ReplicaSet, not the Deployment. After the scale to 10, the Deployment still wanted 10 and the ReplicaSet sat at 5 pods, retrying `FailedCreate`.

A default-deny egress policy breaks DNS first. The curl error changes from "could not resolve host" to "could not connect" once port 53 is open, and HTTP only works after port 80 is allowed as well.

## Self-check

A ResourceQuota counts Kubernetes resources in one namespace: CPU, memory, pods, and later GPUs. It stops one team from filling the node. A LiteLLM token quota counts model tokens for a team or a key. Kubernetes cannot see tokens, and LiteLLM cannot see CPU. You need both. A team can stay inside the pod budget and still burn the token budget, or stay inside the token budget and still schedule too many pods.

- `k3d cluster delete sluice-dev` then `k3d cluster list` → header only, no clusters.
