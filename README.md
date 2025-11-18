# hierarchical-block-quantization

> Artifact for double-blind review — contains baseline PE design for comparison and Design Space Exploration (DSE) modules.

---

![Baseline PE Design](PE_baseline.png)

---

## 📂 Repository Overview

This repository provides the hardware artifacts for **"HBQ: Hierarchical Scaling Block Quantization with Hardware-Efficiency-Aware Design for Accurate LLM Inference"**. It includes baseline Processing Element (PE) designs for system energy analysis and a suite of configurable PE designs for Design Space Exploration (DSE).

---

## 🏛️ Directory Structure

## 1. Baseline Processing Elements

Baseline PEs employ fixed configurations to measure system energy and datapath structure. Three baseline architectures are implemented: Amove, MXFP4, and NVFP4.

---

### 1.1. `Baseline/Amove/`  
#### **W4A4B4 INT PE (NV scheme)**

Implements the *Amove* architecture using **4-bit weights**, **4-bit activations**, and **block size B = 4** under the NV quantization scheme.
#### Reference
> Xie, Xilong, et al. "Amove: Accelerating LLMs through Mitigating Outliers and Salient Points via Fine-Grained Grouped Vectorized Data Type." *Proceedings of the 58th IEEE/ACM International Symposium on Microarchitecture®*. 2025.

#### Key Modules
- **`MAC_Amove.sv`** – INT MAC supporting NV mode for Amove architecture.  
- **`MUL_int.sv`** – INT Multiplier and Adder Tree for block accumulation.  
- **`DEQUANT.v`** – Dequantization logic restoring intra-block weight scaling.  
- **`FP_ACCUM.v`** – FP partial sum accumulator with external partial sum buffer. Excluded subnormal expression for HW efficiency.
- **`params.vh`** – Configuration for INT NV W4A4B4 operation.

---

### 1.2. `Baseline/MAC_WXAY_MX/`
#### **WXAY FP PE (MX scheme)**

A floating-point PE supporting configurable FP formats of the form **WXAY** (X: weight bits, Y: activation bits).

Used configurations in evaluations:
- **W4A4B32** for MXFP energy breakdown 

#### Key Modules
- **`MAC_WXAY_MX.sv`** – FP MAC supporting MX mode.  
- **`MUL_WXAY.sv`** – FP Multiplier and Adder Tree for block accumulation.  
- **`DEQUANT.v`** – Dequantization logic restoring intra-block weight scaling. 
- **`FP_ACCUM.v`** – FP partial sum accumulator with external partial sum buffer. Excluded subnormal expression for HW efficiency.
- **`params.vh`** – Parameter file defining X, Y, B.

---

### 1.3. `Baseline/MAC_WXAY_NV/`
#### **WXAY FP PE (NV scheme)**

A floating-point PE supporting configurable FP formats of the form **WXAY** (X: weight bits, Y: activation bits).

Used configurations in evaluations:
- **W4A4B16** for NVFP energy breakdown 

#### Key Modules
- **`MAC_WXAY_NV.sv`** – FP MAC supporting NV mode.  
- **`MUL_WXAY.sv`** – FP Multiplier and Adder Tree for block accumulation.  
- **`DEQUANT.v`** – Dequantization logic restoring intra-block weight scaling. 
- **`FP_ACCUM.v`** – FP partial sum accumulator with external partial sum buffer. Excluded subnormal expression for HW efficiency.
- **`params.vh`** – Parameter file defining X, Y, B.

---

## 2. Design Space Exploration

The `DSE/` directory contains multiple versions of compute engines designed for precision sweeping.  
All parameters (bit widths, exponent/mantissa widths, block sizes) are defined in `params.vh`.

---

### 2.1. `DSE/MAC_EM/`  
#### **FP8 PE (W4A8) with E/M sweep — MX & NV**

Floating-point PE supporting a family of FP8 formats via configurable exponent (E) and mantissa (M) lengths.

#### Sweepable Parameters
- **Exponent bits (E):** {2, 3, 4, 5}  
- **Mantissa bits (M):** {5, 4, 3, 2}

#### Key Modules
- **`MAC_EM.sv`** – FP MAC supporting MX and NV mode, with configurable E, M modification.  
- **`MUL_EM.sv`** – FP Multiplier and Adder Tree for block accumulation.  
- **`DEQUANT.v`** – Dequantization logic restoring intra-block weight scaling. 
- **`FP_ACCUM.v`** – FP partial sum accumulator for. Excluded subnormal expression for HW efficiency.
- **`params.vh`** – Parameter file defining X, Y, B, **E, M**. (X, Y) is fixed to (4, 8).


---

### 2.2. `DSE/MAC_int/`  
#### **WXAY Integer PE — MX & NV**

Configurable integer WXAY MAC for sweeping integer precision, block size, and quantization format.

#### Sweepable Parameters
- **Weight precision (X bits)**  
- **Activation precision (Y bits)**  
- **Block size (B)**  

#### Key Modules
- **`MAC_int.sv`** – INT MAC supporting MX and NV mode.  
- **`MUL_int.sv`** – INT Multiplier and Adder Tree for block accumulation.  
- **`DEQUANT.v`** – Dequantization logic restoring intra-block weight scaling. 
- **`FP_ACCUM.v`** – FP partial sum accumulator. Excluded subnormal expression for HW efficiency.
- **`params.vh`** – Parameter file defining X, Y, B.

---

### 2.3. `DSE/MAC_WXAY/`  
#### **WXAY Floating-Point PE — MX & NV**

A flexible floating-point MAC supporting block-shared exponent MX/NV quantization with different bit width of weight and activation.

#### Sweepable Parameters
- **Weight FP width (X bits)**  
- **Activation FP width (Y bits)**  
- **Block size (B)**  

#### Key Modules
- **`MAC_WXAY.sv`** – FP MAC supporting MX and NV mode.  
- **`MUL_WXAY.sv`** – FP Multiplier and Adder Tree for block accumulation.  
- **`DEQUANT.v`** – Dequantization logic restoring intra-block weight scaling. 
- **`FP_ACCUM.v`** – FP partial sum accumulator. Excluded subnormal expression for HW efficiency.
- **`params.vh`** – Parameter file defining X, Y, B.

---