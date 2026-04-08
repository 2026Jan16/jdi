Think of DPDK less like a single library and more like a **user-space networking stack toolkit**. It replaces chunks of the kernel networking path with its own components, all wired together through shared memory and lockless structures.

Let’s build a mental model from bottom → top.

---

# 🧱 1. Hardware Layer (NIC + Platform)

* NIC (Intel, Mellanox, etc.)
* PCIe + DMA
* Queues (RX/TX rings in NIC)

👉 Hardware exposes:

* RX/TX descriptors
* Multiple queues (for parallelism)
* RSS (hash-based packet distribution)

---

# ⚙️ 2. Kernel Bypass Layer

### 🔹 UIO / VFIO-PCI

This is how DPDK **takes control of the device**

* `vfio-pci` (modern, safe, uses IOMMU)
* `uio_pci_generic` (older, less secure)

👉 What they do:

* Map device registers (BARs) to user space
* Allow DMA memory registration
* Disable kernel network stack for that NIC

---

# 🧠 3. EAL (Environment Abstraction Layer)

This is the **foundation of DPDK**.

### Responsibilities:

* Hugepage memory setup
* CPU core management (lcores)
* NUMA awareness
* PCI device discovery
* Interrupts (rarely used; mostly polling)
* Multi-process support

👉 Think:
**EAL = “mini runtime OS for DPDK apps”**

---

# 🧬 4. Memory Subsystem

### 🔹 Hugepages

* Pre-allocated physically contiguous memory
* Used for DMA-safe buffers

### 🔹 Mempool (`rte_mempool`)

* Pool of packet buffers
* Lockless, per-core caching

### 🔹 mbuf (`rte_mbuf`)

* The fundamental packet structure

```c
struct rte_mbuf {
    void *buf_addr;
    uint16_t data_len;
    uint32_t pkt_len;
    ...
};
```

👉 Key idea:
Packets are passed around as **pointers to mbufs**, not copied.

---

# 🔌 5. PMD (Poll Mode Drivers)

These are **user-space NIC drivers**

Examples:

* `ixgbe` (Intel 10G)
* `i40e`, `ice`
* `mlx5` (Mellanox)

### What PMDs do:

* Configure NIC queues
* Poll RX/TX rings
* Convert descriptors ↔ `rte_mbuf`

👉 No interrupts:

```c
rte_eth_rx_burst(...)
rte_eth_tx_burst(...)
```

---

# 🔄 6. Rings & Queues (Core Communication Primitive)

### 🔹 `rte_ring`

* Lockless FIFO queue
* Used for inter-core communication

👉 Example:

* Core 0 receives packets
* Core 1 processes them

```
RX Core → rte_ring → Worker Core
```

---

# 📦 7. Libraries (Reusable Building Blocks)

DPDK provides many libraries:

### Core ones:

* `rte_ethdev` → NIC abstraction
* `rte_ring` → queues
* `rte_mbuf` → packet buffers
* `rte_mempool` → memory pools

### Advanced:

* `rte_flow` → hardware flow rules
* `rte_hash` → fast lookup tables
* `rte_lpm` → routing (longest prefix match)
* `rte_acl` → packet filtering
* `rte_timer`, `rte_sched`, etc.

---

# 🧩 8. Applications (What you write)

Examples:

* `l2fwd` (layer 2 forwarder)
* `l3fwd` (router)
* `testpmd` (debug tool)

Your app:

* Initializes EAL
* Configures ports/queues
* Runs polling loops

---

# 🔁 End-to-End Packet Flow

Let’s trace a packet:

---

## 🟢 Step 1: NIC → RX Queue

* Packet arrives at NIC
* Placed into RX descriptor ring

---

## 🟢 Step 2: PMD Polling

```c
rte_eth_rx_burst(port, queue, mbufs, burst_size);
```

* PMD pulls packets into `rte_mbuf`
* Returns array of pointers

---

## 🟢 Step 3: Application Processing

Options:

* Direct processing (same core)
* Send to another core via `rte_ring`
* Lookup (hash/LPM/ACL)

---

## 🟢 Step 4: TX

```c
rte_eth_tx_burst(port, queue, mbufs, n);
```

* PMD converts mbuf → descriptors
* NIC sends packet

---

# 🧠 How components communicate

This is the key part of your question.

### 🔑 1. Shared Memory (Hugepages)

* All components operate on the same memory
* No copies between layers

---

### 🔑 2. Pointers (mbufs)

* Packet = pointer
* Passed across:

  * PMD → app
  * core → core
  * app → NIC

---

### 🔑 3. Lockless Queues (`rte_ring`)

* Core-to-core communication
* No kernel involvement

---

### 🔑 4. Function Calls (Libraries)

* `rte_ethdev` APIs
* `rte_hash`, `rte_lpm`, etc.

---

### 🔑 5. NIC Hardware Queues

* Multi-queue parallelism
* RSS distributes traffic

---

# 🧠 Mental Model (Very Important)

Traditional Linux:

```
NIC → Kernel → Socket → App
```

DPDK:

```
NIC ⇄ PMD ⇄ Your App (all in user space)
         ↕
     Shared Memory
         ↕
     Other Cores
```

---

# ⚠️ Key Architectural Properties

### 1. Polling, not interrupts

* Busy loop
* Predictable latency
* High CPU usage

---

### 2. Zero-copy

* Packets not copied
* Only pointers passed

---

### 3. Run-to-completion model (common)

* One core handles full packet lifecycle

---

### 4. NUMA awareness

* Memory + NIC + CPU alignment matters

---

# 🔚 Condensed View

**Components:**

* Hardware (NIC)
* VFIO/UIO (binding)
* EAL (runtime)
* Memory (hugepages, mempool, mbuf)
* PMDs (drivers)
* Libraries (hash, flow, etc.)
* Application

**Communication:**

* Shared memory (hugepages)
* mbuf pointers
* rte_ring queues
* NIC hardware queues

---

If you want, I can go one level deeper into:

* how mbuf lifecycle works (allocation → free → reuse)
* or how multi-core pipelines are actually designed in production DPDK apps (run-to-completion vs pipeline model)



| Model                 | Real reason it exists                               |
| --------------------- | --------------------------------------------------- |
| Event-driven          | Built-in scheduling + ordering + load balancing     |
| Load-balanced workers | Handle uneven workloads dynamically                 |
| Dispatcher            | Early classification + specialization               |
| Graph-based           | Optimize cache + memory behavior via stage batching |
| Async/offload         | Hide latency and/or use external compute            |

