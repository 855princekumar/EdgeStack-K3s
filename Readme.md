# End-to-End K3s Cluster Architecture with Rancher Management
![K3s](https://img.shields.io/badge/Kubernetes-K3s-326ce5?style=flat-square&logo=kubernetes)
![Rancher](https://img.shields.io/badge/Rancher-Management-0075a8?style=flat-square&logo=rancher)
![ARM](https://img.shields.io/badge/Architecture-ARM64-0091bd?style=flat-square&logo=arm)
![Edge](https://img.shields.io/badge/Deployment-Edge%20Computing-6e40c9?style=flat-square)
![GitOps](https://img.shields.io/badge/GitOps-Rancher%20Fleet-ff6f00?style=flat-square&logo=git)
![Linux](https://img.shields.io/badge/OS-Linux-fcc624?style=flat-square&logo=linux&logoColor=black)
![Status](https://img.shields.io/badge/Status-Actively%20Maintained-success?style=flat-square)

## 1 Big Picture (Mental Model)

Think of your setup as **three layers**:

```
┌────────────────────────────┐
│        Laptop (UI)         │
│  Browser → Rancher UI      │
└─────────────▲──────────────┘
              │ HTTPS
┌─────────────┴──────────────┐
│      Rancher Node (dcn0)   │
│  Management + Monitoring   │
└─────────────▲──────────────┘
              │ Kubernetes API
┌─────────────┴──────────────┐
│   K3s Cluster (7 Pis)      │
│  Control Plane + Workers   │
└────────────────────────────┘
```

**Nothing is random. Everything is deterministic and role-based.**

The repository is designed for **fast, deterministic cluster bring-up**, not for fully managed HA cloud replacement.

---

## 2 Cluster Evolution & Performance Context

<img width="600" height="2000" alt="Unified Poster" src="https://github.com/user-attachments/assets/8c0420cb-c273-453f-9afe-859a660af3d6" />

> This poster documents the **iterative evolution** of the EdgeStack-K3s cluster – from an early multi-node Raspberry Pi 3B+ setup to a compact, performance-optimized Raspberry Pi 4 deployment.
>
> The architecture, workloads, and orchestration layer (K3s + Rancher) remained consistent across phases, enabling **practical performance comparison** rather than synthetic benchmarking.

### Observed Outcomes (Same Workloads, Different Hardware)

| Dimension | Pi 3B+ Cluster (7–8 nodes) | Pi 4 Cluster (2 nodes) |
|---------|----------------------------|------------------------|
| Total usable RAM | ~7 GB | 4-8 GB |
| CPU class | Cortex-A53 | Cortex-A72 |
| Network | USB 2–backed Ethernet | Native Gigabit |
| Pod density | Low | High |
| Control-plane overhead | Higher | Lower |
| Power consumption | ~2.5–3× higher | Reduced |
| Physical footprint | Large | Compact |
| Cable complexity | High | Minimal |

> **Key takeaway:**  
> For K3s-based edge workloads, a **2-node Raspberry Pi 4 cluster delivers comparable application-level performance** to a much larger Raspberry Pi 3B+ cluster while significantly reducing cost, power draw, and infrastructure complexity.

---

## 3 What Each Node Actually Does

### Control Plane (dcn1)

This is the **brain** of the cluster.

It runs:

* Kubernetes API server
* Scheduler (decides where pods run)
* Controller manager (keeps desired vs actual state)
* Embedded datastore (SQLite by default in K3s)

**It does NOT run your apps by default.**  
It decides *where* apps should run.

### Control Plane Design Choice

This setup intentionally uses a **single control-plane node**.

Rationale:
- Edge / lab / in-house micro-cloud use case
- Resource-constrained hardware (Raspberry Pi 3B+)
- Preference for operational simplicity over full HA

Behavior:
- Existing workloads continue during control-plane downtime
- New scheduling and cluster mutations pause until recovery

This mirrors many real-world **edge Kubernetes deployments**, where  
control-plane availability is a tradeoff rather than a requirement.

---

### Worker Nodes (dcn2–dcn7)

These are **execution engines**.

Each worker:

* Registers itself to the master
* Advertises CPU + RAM capacity
* Pulls container images
* Runs application pods

Workers do **zero coordination** themselves.  
They strictly obey the control plane.

---

## Design Trade-offs

This project intentionally optimizes for:

- Determinism over abstraction
- Node resilience over control-plane HA
- Edge reliability over cloud-scale elasticity

Not implemented by design:
- Multi-control-plane quorum
- External etcd
- Service mesh
- Cloud-managed load balancers

These trade-offs reflect real constraints in edge and in-house micro-cloud environments.

---

### Rancher Node (dcn0)

This is **not Kubernetes infrastructure**.

It is:

* A Kubernetes *manager*
* A UI + policy layer
* A cluster lifecycle controller

Rancher:

* Talks to K3s API
* Does NOT replace Kubernetes
* Does NOT schedule workloads

Think of Rancher as:

> “Kubernetes’s remote control + observability layer”

---

## 4 What Happens When we Run the Scripts

### Script 1 - Master Bootstrap

**Sequence**

1. OS updated
2. Linux kernel cgroups enabled  
   (mandatory for containers)
3. K3s server starts
4. API server opens on port `6443`
5. Join token generated

**Result**

* Cluster exists
* Ready to accept workers
* Control plane is live

---

### Script 2 - Worker Bootstrap

**Sequence**

1. Worker enables cgroups
2. Fetches join token
3. Connects to master API
4. Registers itself

**Handshake**

```
Worker → Master:
"Here is my token, CPU, RAM, IP"

Master → Worker:
"You are node dcnX, accepted"
```

**Result**

* Node appears as `Ready`
* Scheduler can now use it

---

### Script 3 - Rancher Bootstrap

**Sequence**

1. Docker installed
2. Rancher container launched
3. Rancher UI exposed on HTTPS

**Important**  
Rancher is **completely separate** from K3s binaries.

---

## 5 How Rancher Connects to the Cluster

This is the most misunderstood part

### Import Flow

1. Rancher generates an **import manifest**
2. You apply it once on dcn1
3. That manifest:

   * Creates a Rancher agent inside the cluster
   * Opens a reverse tunnel to Rancher

```
Rancher UI
   ▲
   │ secure websocket
   ▼
Rancher Agent Pod (inside K3s)
   │
   ▼
Kubernetes API (dcn1)
```

**After this:**

* Rancher never SSHs into nodes
* Rancher never touches OS
* Everything is Kubernetes-native

---

## 6 How a Deployment Actually Runs (Example)

Let’s say you deploy **NGINX from Rancher UI**.

### Step-by-step:

1. You click “Deploy”
2. Rancher sends YAML to Kubernetes API
3. Scheduler evaluates:

   * Which node has resources
   * Node selectors, labels, taints
4. Pod assigned to a worker (say dcn4)
5. dcn4:

   * Pulls image
   * Starts container
6. Status flows back:

   * Worker → Master → Rancher → UI

You never log into dcn4.

---

## 7 Networking Flow (Why Static IPs Matter)

Your decision to use **static IPs was critical**.

### Without static IPs:

* Workers disconnect after reboot
* Rancher agents lose trust
* Cluster breaks silently

### With static IPs:

* Node identity is stable
* TLS certs remain valid
* Zero reconfiguration needed

**Your Python IP automation was the correct engineering call.**

---

## 8 Monitoring & Health (Where Your Python Script Fits)

My Python script operates at **Layer 0** (below Kubernetes).

It checks:

* ICMP
* SSH
* Node reachability
* Kubernetes node state

Kubernetes monitoring operates at **Layer 1+**:

* Pod health
* Container restarts
* Resource pressure

They **complement**, not replace each other.

### 8.1 Node-Level Memory Resilience (Edge-Pulse)

To address frequent OOM conditions on low-memory nodes, the cluster uses  
a custom node-side component ("Edge-Pulse") that provides:

- Hybrid memory management (zram + disk-backed swap)
- SD-card wear protection via USB-backed IO
- Systemd-managed lifecycle
- Runtime validation and rollback
- Node-local observability API

This operates **below Kubernetes**, complementing pod-level memory limits  
with OS-level stability guarantees.

---

## 9 Failure Scenarios (And What Happens)

### Worker Power Loss

* Scheduler marks node `NotReady`
* Pods rescheduled to other workers
* When node returns, it rejoins automatically

### Rancher Down

* Cluster continues running
* No workloads affected
* UI unavailable only

### Control Plane Down

* No new scheduling
* Existing pods continue running
* Recovery needed for changes

---

## 10 Why This Design Is Correct for Edge / IoT

- Lightweight (K3s)
- Deterministic (static IPs)
- Centralized control (Rancher)
- No SSH dependency
- Survives node loss
- Scales horizontally

This is **exactly** how production edge clusters are built - just on smaller hardware, deliberately designed and tested end-to-end.

---

