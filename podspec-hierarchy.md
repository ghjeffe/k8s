# Kubernetes PodSpec Hierarchy Mapping

In Kubernetes, a `PodSpec` is the core structure that defines how a pod runs. It contains fields like `containers`, `volumes`, `initContainers`, `nodeSelector`, `tolerations`, and `securityContext`.

However, you rarely deploy raw Pods. Instead, you use workload controllers (like Deployments, StatefulSets, or Jobs) to manage them. These controllers use a **PodTemplate** (specifically a `PodTemplateSpec`), which contains the `metadata` (labels/annotations) and the `spec` (`PodSpec`) for the pods they create.

Because of this wrapping, the exact YAML path to the `PodSpec` changes depending on the resource type.

---

## 📍 Path Mapping by Resource Type

| Resource Type | YAML Path to PodSpec |
| :--- | :--- |
| **Pod** | `spec` |
| **Deployment** | `spec.template.spec` |
| **ReplicaSet** | `spec.template.spec` |
| **StatefulSet** | `spec.template.spec` |
| **DaemonSet** | `spec.template.spec` |
| **Job** | `spec.template.spec` |
| **ReplicationController** | `spec.template.spec` |
| **CronJob** | `spec.jobTemplate.spec.template.spec` |

---

## 📖 Visual Examples

### 1. Pod
In a bare Pod, the `PodSpec` is at the top level under `spec`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:                     # <-- PodSpec begins here
  containers:
    - name: app
      image: nginx
```

### 2. Deployment (and StatefulSet, DaemonSet, Job)
Controllers wrap the Pod in a `template` block. The `template.spec` is the `PodSpec`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
spec:                     # <-- DeploymentSpec
  replicas: 3
  template:               # <-- PodTemplateSpec (metadata + spec)
    metadata:
      labels:
        app: my-app
    spec:                 # <-- PodSpec begins here
      containers:
        - name: app
          image: nginx
```

### 3. CronJob
A CronJob wraps a Job, which in turn wraps a Pod. Therefore, the path is nested two levels deep.

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: my-cronjob
spec:                             # <-- CronJobSpec
  schedule: "0 0 * * *"
  jobTemplate:                    # <-- JobTemplateSpec
    spec:                         # <-- JobSpec
      template:                   # <-- PodTemplateSpec
        spec:                     # <-- PodSpec begins here
          restartPolicy: OnFailure
          containers:
            - name: job-worker
              image: busybox
```

---

## 💡 Quick Reference: Common PodSpec Fields
Whenever documentation refers to adding something to the "PodSpec", it goes exactly at the path mapped above.

*   `containers:`
*   `initContainers:`
*   `volumes:`
*   `serviceAccountName:`
*   `nodeSelector:`
*   `affinity:`
*   `tolerations:`
*   `securityContext:`
*   `restartPolicy:`
*   `imagePullSecrets:`