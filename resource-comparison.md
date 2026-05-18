# Kubernetes & Istio Resource Comparison

This table summarizes the core purpose, scope, and analogies for key Kubernetes and Istio resources.

| Resource | Ecosystem | Primary Purpose | Key Responsibilities | Analogy |
| :--- | :--- | :--- | :--- | :--- |
| **Pod** | Kubernetes | Compute | Runs your containers; shares network & storage among them. | The food truck where the workers (containers) actually do the cooking. |
| **Deployment** | Kubernetes | Orchestration | Manages Pod lifecycles, ensures desired replica count, and handles rolling updates. | The factory manager who ensures the right number of trucks are deployed and replaces broken ones. |
| **ConfigMap** | Kubernetes | Configuration | Stores non-confidential key-value pairs (env vars, config files) separate from the image. | The settings menu of a phone that customizes generic hardware for a specific user. |
| **Service** | Kubernetes | Internal Networking | Provides a stable internal IP/DNS name and basic round-robin load balancing for a group of Pods. | The 1-800 number that hides the chaos of individual call center agents changing shifts. |
| **Ingress** | Kubernetes | Edge Networking | Native K8s way to route external HTTP/HTTPS traffic to internal Services based on host/path. | The company switchboard listening for outside calls and connecting them to internal extensions. |
| **Gateway** | Istio | Edge Networking | Configures edge proxy ports, protocols, and TLS termination for traffic entering/leaving the mesh. | The security checkpoint at the front door that checks IDs (TLS) and unlocks specific doors (Ports). |
| **VirtualService** | Istio | Advanced Routing | Defines intelligent routing rules (path, header, traffic split, retries) for a specific hostname. | The mail-sorting robot that reads envelopes and sends them to specific floors or subsets of workers. |
| **DestinationRule** | Istio | Post-Routing Policy | Defines subsets (v1, v2), connection pooling, outlier detection, and client-side TLS settings. | The floor manager who groups employees (Subsets), limits their workload (Circuit Breaking), and sends sick workers home. |
| **PeerAuthentication** | Istio | Security | Defines whether a workload accepts or strictly requires Mutual TLS (mTLS) for incoming connections. | The guard at the door enforcing whether visitors must show an encrypted ID badge (`STRICT`) or not. |

---

## 🔗 How They Connect

### 1. Standard Kubernetes Flow
`External Request` ➡️ `Ingress` (Host/Path Routing) ➡️ `Service` (Stable IP/Basic LB) ➡️ `Deployment` (Manages Pods) ➡️ `Pod` (Runs App + ConfigMap)

### 2. Istio Mesh Flow
`External Request` ➡️ `Gateway` (Ports/TLS) ➡️ `VirtualService` (Advanced Routing/Splitting) ➡️ `DestinationRule` (Subsets/Circuit Breaking) ➡️ `Service` ➡️ `Pod` (Secured by `PeerAuthentication`)