# NES-Inspired System-on-Chip (SoC)

A custom System-on-Chip designed to replicate classic NES functionality, built around a MicroBlaze soft processor. This repository contains the complete hardware definition (Vivado) and software application (Vitis) of the project.

## Repository Structure

* `/hw` - Hardware design files.
  * `build_hw.tcl` - The master Vivado reconstruction script.
  * `bd_recreate.tcl` - Block design blueprint (called automatically by the build script).
  * `/constraints` - Master XDC constraint file for the Nexys A7.
  * `/assets` - `.coe` files containing ROM data (Fonts, Mario Demo, Palettes, outdated except for font).
  * `/src` - Custom IP configurations (e.g., Memory Interface Generator `.prj` files).
* `/sw` - Software application files.
  * `/src` - C/C++ source files and headers for the Vitis application.
  * `/bootloader` - Pre-compiled `.elf` required for Vivado memory initialization.
* `/ip_repo` - Custom User IPs (Sprite Renderer, APU Engine, Memory Arbiter, Gatekeeper, etc.).

---

## Component Interaction & Architecture

The system relies on several custom IP blocks communicating alongside standard Xilinx infrastructure. All custom peripherals communicate with the MicroBlaze processor via a custom-built **AXI-Lite slave module** connected to the main AXI Interconnect. Below is a breakdown of how data flows through the system.

### 1. The Processing Core & Boot Modes
On startup, the MicroBlaze soft processor checks whether the system is in Development or Release mode:
* **Release Mode:** The CPU reads assets directly from the onboard SD card. It moves 16-bit unsigned PWM audio assets into the DDR2 memory and loads the graphics—stored as an encoded 8-bit sprite atlas of 16x16 sprites—into the dedicated Sprite Memory.
* **Development Mode:** To eliminate the bottleneck of constantly rewriting the SD card during development, a custom **UDP IP module** was created. The MicroBlaze receives data directly from a host PC Python script via Ethernet. The script uses a Go-Back-N (GBN) ARQ protocol for reliability. This datapath achieves ~12 Mbps (bottlenecked primarily by the AXI-Stream handshake) and drastically speeds up the iteration cycle.

### 2. Memory Arbitration
Because the graphics engine requires massive memory bandwidth, the Sprite Renderer occupies both ports of the dual-port Sprite Memory. To solve this, a custom **Memory Arbiter** component mediates access between the CPU and the rendering hardware. During startup, the arbiter grants the CPU access to load the sprite atlases and palettes. Once the loading phase is complete, it hands off full control to the Sprite Renderer.

### 3. Sprite & Graphics Rendering
The custom Sprite Renderer and VGA module utilize a highly pipelined architecture to keep up with the VGA beam. 
* **Pipelined Fetching:** The background, font, and objects from the Object Attribute Memory (OAM) are fetched concurrently. A hardware mixer/multiplexer evaluates these streams on the fly to determine which pixel has priority.
* **Double Buffering:** The display operates on a double line buffer system—hardware writes to one line buffer while the VGA beam actively displays the other. 
* **Color LUT:** To optimize memory utilization, graphics are encoded on 8 bits and decoded locally using a Hardware Palette LUT.
* **Hardware Collision:** The graphics engine calculates a pixel-perfect hardware collision detection flag for the object stored at the priority index (allowing the programmer to easily track collisions for the main character).

### 4. Audio / APU Engine
To minimize CPU overhead, the Audio Processing Unit (APU) leverages Direct Memory Access (DMA). The APU receives 4-byte packed words directly from the DDR2 memory via the DMA controller. It unpacks these words locally in hardware to play the 16-bit unsigned PWM audio tunes.

### 5. Input Handling (Key Mapper)
The custom Key Mapper module utilizes the PS/2 protocol (interfaced via the USB port on the Nexys A7) to read standard keyboard inputs. It supports up to 8 simultaneous button presses. The hardware continuously writes the current state of the buttons to a flag register, which the MicroBlaze CPU simply polls to detect input. *(Note: Complete integration of this input system into the game logic is currently in progress).*

### 6. Clock Domain Crossing (CDC) & Synchronization
Because the system architecture spans multiple independent clock frequencies (e.g., the main CPU clock versus the VGA pixel clock), Clock Domain Crossing (CDC) strategies had to be implemented. To prevent metastability and ensure data integrity between asynchronous modules:
* **Asynchronous FIFOs** were instantiated for modules passing larger, multi-bit data streams.
* **Double Flip-Flop Synchronizers** were utilized for passing single-bit flags or smaller control signals across clock domains.
