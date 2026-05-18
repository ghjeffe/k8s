# Kubernetes & Istio Object Interaction Chart

This document maps how Kubernetes and Istio resources reference and interact with one another to form a complete application architecture.

## 1. Traffic Flow & Routing Hierarchy (ASCII Chart)

This chart shows the path of a network request from the outside world down to your application code.

```text
[ External Internet Client ]
             │
             ▼
========================================================================
 EDGE / INGRESS LAYER
========================================================================
  [ Kubernetes Ingress ]             OR            [ Istio Gateway ]
  (Matches Host/Path)                              (Opens Ports, terminates TLS)
             │                                              │
             │                                              ▼
             │                                   [ Istio VirtualService ]
             │                                   (Matches Path/Headers, splits traffic)
             │                                              │ (routes to "v1" subset)
             │                                              ▼
             │                                   [ Istio DestinationRule ]
             │                                   (Defines "v1", Circuit Breaking, mTLS)
             │                                              │
========================================================================
 INTERNAL NETWORKING LAYER
========================================================================
             │                                              │
             ▼                                              ▼
    [ Kubernetes Service ] <────────────────────────────────┘
    (Provides internal DNS & groups pods using Label Selectors)
             │
========================================================================
 WORKLOAD & COMPUTE LAYER
========================================================================
             ▼
        [ K8s Pod ] <────────────────── [ Istio PeerAuthentication ]
  (Runs your actual containers)         (Enforces mTLS for incoming traffic to the Pod)
             ▲
             │ (creates & manages)
    [ K8s Deployment ]
             │
             ├──────── (injects via env vars or volumes) ───────┐
             │                                                  │
             ▼                                                  ▼
      [ ConfigMap ]                                         [ Secret ]
   (App configuration)                                  (Passwords, TLS Certs)
```

---

## 2. Who References Whom? (Configuration Matrix)

When writing YAML, resources must link to each other. Here is exactly *how* they connect via YAML fields:

| Source Object | Field Used to Connect | Target Object | Description |
| :--- | :--- | :--- | :--- |
| **Ingress** | `spec.rules[].http.paths[].backend.service.name` | **Service** | Ingress forwards matched HTTP paths directly to a K8s Service. |
| **VirtualService** | `spec.gateways[]` | **Gateway** | Binds the routing rules of the VirtualService to a specific Istio Gateway. |
| **VirtualService** | `spec.http[].route[].destination.host` | **Service** | VirtualService sends matched traffic to a K8s Service's DNS name. |
| **VirtualService** | `spec.http[].route[].destination.subset` | **DestinationRule** | VirtualService routes to a specific subset named in the DestinationRule. |
| **DestinationRule**| `spec.host` | **Service** | The K8s Service that this rule applies policies and subsets to. |
| **Gateway** | `spec.servers[].tls.credentialName` | **Secret** | The Gateway uses a K8s Secret to get the TLS certificate for HTTPS termination. |
| **Deployment** | `spec.selector.matchLabels` | **Pod** | Deployment manages Pods that match these exact labels. |
| **Service** | `spec.selector` | **Pod** | Service discovers and sends traffic to Pods matching these labels. |
| **PeerAuth...** | `spec.selector.matchLabels` | **Pod** | PeerAuthentication applies mTLS enforcement to Pods matching these labels. |
| **Deployment** | `spec.template.spec.containers[].env[].valueFrom` | **ConfigMap / Secret** | Injects specific keys from a ConfigMap or Secret as environment variables. |
| **Deployment** | `spec.template.spec.volumes[].configMap` | **ConfigMap** | Mounts an entire ConfigMap as files inside the Pod's filesystem. |

---

## 3. Visualizing Istio's "Subset" Routing

One of the most complex interactions is how Istio splits traffic (e.g., Canary deployments). Here is how the YAML ties together:

1. **VirtualService**: "Send 90% of traffic to the `v1` subset, and 10% to the `v2` subset of `my-service`."
2. **DestinationRule**: "For `my-service`, the `v1` subset means pods with the label `version: v1`. The `v2` subset means pods with the label `version: v2`."
3. **Deployment 1**: Creates Pods with labels `app: my-service, version: v1`.
4. **Deployment 2**: Creates Pods with labels `app: my-service, version: v2`.
5. **Service**: Groups ALL pods with label `app: my-service` so Istio can see them.
