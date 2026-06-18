# MESI Cache Coherence Protocol Simulation in SystemVerilog

## Overview

This project implements a simplified MESI (Modified, Exclusive, Shared, Invalid) Cache Coherence Protocol using SystemVerilog. The design models a dual-core system with two private caches connected to a shared memory through a common bus.

The objective is to maintain data consistency across caches while minimizing unnecessary memory transactions.

---

## Features

* MESI cache coherence protocol implementation
* Two-cache multiprocessor simulation
* Shared main memory model
* Bus-based snooping mechanism
* Read hit and read miss handling
* Write hit and write miss handling
* Cache-to-cache coherence transitions
* Write-back support for modified cache lines
* FSM-based cache controller
* Comprehensive verification testbench

---

## System Architecture

<img width="2720" height="2080" alt="mesi_cache_coherency_architecture" src="https://github.com/user-attachments/assets/61362333-972c-42c6-85d5-507ec7332aa6" />


The system consists of:

* CPU 0
* Cache 0
* CPU 1
* Cache 1
* Shared Main Memory
* Shared Bus
* Snooping Logic

Caches communicate through bus transactions and monitor each other's requests to maintain coherence.

---

## MESI States


### Modified (M)

* Cache line contains updated data.
* Memory copy is stale.
* Owner must write back data before another cache accesses it.

### Exclusive (E)

* Data exists only in one cache.
* Memory copy is clean.
* Local writes can directly move to Modified state.

### Shared (S)

* Data may exist in multiple caches.
* Memory and cache contain identical data.

### Invalid (I)

* Cache line is not valid.

---

## Cache Organization

| Parameter     | Value         |
| ------------- | ------------- |
| Address Width | 8-bit         |
| Data Width    | 32-bit        |
| Cache Lines   | 16            |
| Mapping       | Direct Mapped |
| Tag Width     | 4-bit         |
| Index Width   | 4-bit         |

Each cache line contains:

* MESI state
* Tag
* Data

---

## Controller FSM

The cache controller is implemented using a finite state machine.

### States

1. IDLE
2. COMPARE
3. WRITE_BACK
4. BUS_READ
5. BUS_READX
6. BUS_UPGR
7. REFILL

### State Description

#### IDLE

Waits for CPU requests.

#### COMPARE

Checks cache hit/miss and determines the next operation.

#### WRITE_BACK

Writes modified data back to memory before replacement.

#### BUS_READ

Generates a BusRd request for read misses.

#### BUS_READX

Generates a BusRdX request for write misses.

#### BUS_UPGR

Generates a BusUpgr request when upgrading from Shared to Modified.

#### REFILL

Loads data into cache after a bus transaction completes.

---

## Snoop Controller

The snoop controller monitors:

* BusRd
* BusRdX
* BusUpgr

and performs MESI state transitions accordingly.

### Examples

#### BusRd

| Current State | New State |
| ------------- | --------- |
| E             | S         |
| M             | S + Flush |

#### BusRdX

| Current State | New State      |
| ------------- | -------------- |
| S             | I              |
| E             | I              |
| M             | I + Write Back |

#### BusUpgr

| Current State | New State |
| ------------- | --------- |
| S             | I         |

---

## Pending Request Mechanism

During write misses, the cache must remember the original CPU request while obtaining ownership of the cache line.

### Stored Information

* pending_addr
* pending_data
* pending_is_write
* pending_write_miss

After BusRdX completes, the REFILL state uses these values to complete the pending write operation.

---

## Verification

The design was verified using a self-checking SystemVerilog testbench.

### Test Cases

1. Read Miss → Exclusive State
2. Shared Read → Exclusive to Shared Transition
3. Shared Write → BusUpgr
4. Write Miss → BusRdX
5. Modified Line Read by Another Cache
6. Modified to Shared Transition
7. Modified to Invalid Transition
8. Write Back Verification
9. Cache-to-Cache Coherence Validation

---

## Sample MESI Transitions

### Read Miss

I → E

### Shared Read

E → S

### Write on Shared Line

S → M

### BusRd on Modified Line

M → S

### BusRdX on Modified Line

M → I
