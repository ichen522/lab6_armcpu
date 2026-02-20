## 🚀 Introduction

This project presents the design and implementation of a **5-stage pipelined ARM-compatible processor core** with **hardware-supported quad-threading**. The processor is capable of executing a subset of the ARM Instruction Set Architecture (ISA) and is synthesized on a **NetFPGA platform**.

The core architecture follows the classic **IF–ID–EX–MEM–WB pipeline model**, enabling efficient instruction throughput while maintaining a clean and modular datapath design. Beyond a standard single-thread pipeline, this processor introduces **zero-overhead hardware multithreading**, allowing four independent threads to execute concurrently within a single core.

To bridge software and hardware, ARM-compiled C programs (including a sorting application) were analyzed at the assembly level, and the required instruction subset was implemented directly in Verilog. The processor supports arithmetic, memory, and branch operations necessary to execute compiled programs correctly.

This project demonstrates:

- ⚙️ Custom datapath and control unit design  
- 🧠 ARM instruction decoding and execution  
- 🧵 Hardware-level multithreading architecture  
- 🚀 Zero-overhead context switching  
- 🔬 Successful execution and verification of compiled C programs  

Overall, this work highlights the integration of computer architecture principles, digital hardware design, and compiler-level instruction analysis into a functional multi-threaded processor core.