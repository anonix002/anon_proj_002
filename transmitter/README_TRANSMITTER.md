# FPGA Top-Level Variants

## Overview
This project contains five variants of the FPGA top-level design, each supporting different modes of operation:

### 1. **singing_fpga_top.v**
**Purpose:** Multi-frequency clock generator with software-selectable outputs

| Aspect | Details |
|--------|---------|
| **Host Script** | [`main.py`](pc_host_scripts/main.py) |
| **UART Data** | 2 bytes RX (command format: 0xFF + frequency select), 2 bytes TX |
| **Available Frequencies** | 12 kHz, 50 kHz, 120 kHz, 12 MHz, 55.386 MHz, 120 MHz, 240 MHz, 360 MHz |
| **Frequency Source** | Single PLL with multiple outputs + digital dividers |
| **Output Method** | OR of all enabled clock outputs |
| **Control** | Via UART command (0xFF prefix selects frequency via lower byte) |
| **States** | Simple enable/disable per frequency (no state machine) |
| **LEDs** | 3 outputs (any_oscillator_enabled, pll_locked, M_RESET_B) |
| **Use Case** | General-purpose multi-frequency RF/clock generation |

---

### 2. **singing_fpga_top_sweep.v**
**Purpose:** Simple frequency sweep / continuous wave generation

| Aspect | Details |
|--------|---------|
| **Host Script** | [`main_sweep.py`](pc_host_scripts/main_sweep.py) |
| **UART Data** | 2 bytes RX, 2 bytes TX |
| **Frequency Source** | Single PLL (936 MHz) |
| **Output** | Square wave with programmable division factor |
| **Key Module** | `square_wave_generator` |
| **States** | IDLE → WAIT_READY_ZERO → CONTINUOUS_WAVE |
| **LEDs** | 3 outputs (wave_enable, pll_locked, M_RESET_B) |
| **Use Case** | Frequency sweep operations with variable division ratio |

---

### 3. **singing_fpga_top_basic_fsk_modulation.v**
**Purpose:** Continuous wave at user-selected frequency (FSK-like binary control)

| Aspect | Details |
|--------|---------|
| **Host Script** | [`main_modulation_bitstring.py`](pc_host_scripts/main_modulation_bitstring.py) |
| **UART Data** | 2 bytes RX, 2 bytes TX |
| **Frequency Sources** | Dual PLL (912 MHz or 888 MHz) |
| **Output Control** | LSB of UART data selects frequency |
| **Key Modules** | Two PLLs, no modulator |
| **States** | IDLE → WAIT_READY_ZERO → CONTINUOUS_WAVE |
| **LEDs** | 4 outputs (wave_enable, 888MHz locked, 912MHz locked, M_RESET_B) |
| **Use Case** | Simple binary FSK output (switch between two fixed frequencies) |

---

### 4. **singing_fpga_top_key_fsk_modulation.v**
**Purpose:** FSK modulation of arbitrary bitstreams (without decryption)

| Aspect | Details |
|--------|---------|
| **Host Script** | [`main_modulation_key.py`](pc_host_scripts/main_modulation_key.py) |
| **UART Data** | 19 bytes RX (bitstream[128] + symbol_time[16] + rep_factor[4]) |
| **UART TX** | 2 bytes TX (status signal) |
| **Frequency Sources** | Dual PLL (936 MHz or 888 MHz) |
| **Key Modules** | `modulator` (FSK modulator) |
| **States** | IDLE → MODULATE |
| **Processing** | Direct bitstream modulation (no crypto) |
| **LEDs** | 4 outputs (wave_enable, 888MHz locked, 936MHz locked, M_RESET_B) |
| **Use Case** | Raw FSK modulation of user-supplied bitstreams with configurable symbol timing |

---

### 5. **singing_fpga_top_aes_fsk_modulation.v**
**Purpose:** Leaking AES-decryption oracle key using FSK modulation with trigger word support

| Aspect | Details |
|--------|---------|
| **Host Script** | [`main_modulation_key.py`](pc_host_scripts/main_modulation_key.py) |
| **UART Data** | 19 bytes RX (ciphertext[128] + symbol_time[16] + rep_factor[4]) |
| **UART TX** | 18 bytes TX (plaintext[128] + status[16]) |
| **Frequency Sources** | Dual PLL (936 MHz or 888 MHz) |
| **Key Modules** | `AES_Decrypt`, `modulator` (FSK modulator) |
| **States** | IDLE → MODULATE |
| **Processing** | AES decryption → FSK modulation |
| **Trigger Word** | `0x12341234123412341234123412341234` activates modulation |
| **AES Config** | 128-bit key, 10 rounds (AES-128) |
| **LEDs** | 4 outputs (wave_enable, 888MHz locked, 936MHz locked, M_RESET_B) |
| **Use Case** | Leaking keys using FSK transmission |

---

## Key Differences Summary

| Feature | Multi-Freq | Sweep | Basic FSK | Key FSK | AES FSK |
|---------|-----------|-------|-----------|---------|---------|
| **Primary Purpose** | Clock generator | Freq sweep | Binary FSK | Variable FSK | Key Leakage FSK |
| **Decryption** | ✗ | ✗ | ✗ | ✗ | ✓ (AES-128) |
| **FSK Modulation** | ✗ | ✗ | ✓ (binary) | ✓ (variable) | ✓ (variable) |
| **Arbitrary Bitstream** | ✗ | ✗ | ✗ | ✓ | ✓ |
| **Programmable Symbol Time** | ✗ | ✓ | ✗ | ✓ | ✓ |
| **Trigger Word Detection** | ✗ | ✗ | ✗ | ✗ | ✓ |
| **UART RX Bytes** | 2 | 2 | 2 | 19 | 19 |
| **UART TX Bytes** | 2 | 2 | 2 | 2 | 18 |
| **Frequency Options** | 8 selectable | 1 fixed | 2 fixed | 2 switchable | 2 switchable |
| **PLL Count** | 1 (multi-out) | 1 | 2 | 2 | 2 |
| **LED Outputs** | 3 | 3 | 4 | 4 | 4 |

---

## Host Script Reference

Each FPGA design variant has a corresponding host script for control via UART:

### Script-to-Design Mapping

| Host Script | FPGA Design | Purpose | Command Format |
|-------------|-------------|---------|-----------------|
| [`main.py`](pc_host_scripts/main.py) | `singing_fpga_top.v` | Multi-frequency RF generation | `python main.py <on\|off> [frequency]` |
| [`main_sweep.py`](pc_host_scripts/main_sweep.py) | `singing_fpga_top_sweep.v` | Frequency sweep/CW generation | `python main_sweep.py <on\|off> [value\|bypass]` |
| [`main_modulation_bitstring.py`](pc_host_scripts/main_modulation_bitstring.py) | `singing_fpga_top_basic_fsk_modulation.v` | Binary FSK modulation | `python main_modulation_bitstring.py <on\|off> [bitstring]` |
| [`main_modulation_key.py`](pc_host_scripts/main_modulation_key.py) | `singing_fpga_top_key_fsk_modulation.v` | FSK bitstream modulation | `python main_modulation_key.py <file> <time_ms> [options]` |
| [`main_modulation_key.py`](pc_host_scripts/main_modulation_key.py) | `singing_fpga_top_aes_fsk_modulation.v` | Key FSK modulation | `python main_modulation_key.py <file> <time_ms> --aes-decrypt` |

### Script Usage Notes



**main.py** - Multi-frequency generator
- Enable specific frequency: `python main.py on 12m`
- Disable all outputs: `python main.py off`
- Supported frequencies: 12k, 50k, 120k, 12m, 55.386m, 120m, 240m, 360m

**main_sweep.py** - Frequency sweep with variable division
- Set division factor: `python main_sweep.py on 256` (divides 936MHz by 2×(256+1))
- Bypass divider: `python main_sweep.py on bypass` (output raw 936MHz)
- Disable: `python main_sweep.py off`

**main_modulation_bitstring.py** - Binary FSK control
- Single frequency (always on): `python main_modulation_bitstring.py on 0` (888MHz) or `on 1` (936MHz)
- Bitstring transmission: `python main_modulation_bitstring.py on 01001101` (FSK modulate bitstring)
- Disable: `python main_modulation_bitstring.py off`

**main_modulation_key.py** - Arbitrary bitstream FSK
- Modulate bitstream: `python main_modulation_key.py bitstream.txt 1.0 -r 5` (1ms symbol time, repeat 5×)
- With repetition factor: `python main_modulation_key.py bitstream.txt 0.5 -f 4` (0.5ms symbols, 4× repetition)
- Key Leakage (AES): `python main_modulation_key.py bitstream.txt 1.0 --aes-decrypt`
- Supports binary (128 bits), hex (32 hex chars), or hex with 0x prefix

---

## Dependencies

### Software
- PyQt6 (required for the GUI tool at [draw2route/fpga_route_gui.py](draw2route/fpga_route_gui.py))

Install via pip:

```bash
pip install PyQt6
```

### FPGA IP & MACROS
This project uses **Xilinx IP blocks and primitives**, specifically:
- **PLL (Phase-Locked Loop)** – Generated using the Xilinx Clock Wizard
  - Multiple PLL variants are instantiated across designs (e.g., `pll_12`, `pll_936`, `pll_888`, etc.)
  - Each PLL is configured to generate specific clock frequencies required by the FPGA designs
  - These must be regenerated in Xilinx ISE/Vivado using the Clock Wizard if IP cores are updated
- **IBUFG** – Input clock buffer primitive
  - Used for buffering the external oscillator clock input
- **BUFG** – Global clock buffer primitive
  - Used for buffering PLL outputs before distribution to the design logic

### User Constraints File (UCF)
The project includes a constraints file ([`rtl_src/sakura_g_main_r1.ucf`](rtl_src/sakura_g_main_r1.ucf)) that defines pin assignments and I/O properties for the Sakura-G board. This UCF file contains detailed instructions about which pins to connect or uncomment based on the target design variant and board configuration. Review the comments within the UCF file to enable only the necessary pin constraints for your specific build.

### Custom Antenna Routing (fpga_route_gui.py)

This project includes a GUI tool ([`draw2route/fpga_route_gui.py`](draw2route/fpga_route_gui.py)) for designing custom routing antennas on the FPGA. The tool allows you to visually draw routes on an XC6SLX75 FPGA grid and automatically generates Verilog code.

**Generating Custom Antennas:**
1. Launch the tool: `python draw2route/fpga_route_gui.py`
2. Draw antenna segments on the grid
3. Export the generated Verilog module
4. Save the file to [`rtl_src/antennas/`](rtl_src/antennas/)

**Integrating Custom Antennas into Top Modules:**
1. Add an `instantiate` statement in one of the top-level modules (e.g., [`rtl_src/singing_fpga_top.v`](rtl_src/singing_fpga_top.v))
2. Example instantiation:
   ```verilog
   your_custom_antenna antenna_inst (
       antenna_in(antenna_input)
   );
   ```
3. **Important:** You must manually connect each segment input (e.g., `seg_0_in_LUT_A`, `seg_1_in_LUT_B`, etc.) to your desired signal. The generated antenna module requires explicit drive signals for each segment's LUT inputs to function correctly.
Look for the comment "SEGMENT _ BEGINNING" to see the inputs.

---

## Project Reproduction

### Creating a New ISE 14.7 Project

To build this project from scratch using Xilinx ISE 14.7:

1. **Create a New Project**
   - Launch Xilinx ISE 14.7
   - Select **File → New Project**
   - Choose a project name and location
   - Click **Next**

2. **Configure Device Settings**
   - Select the following device specifications:
     - **Device Family:** Spartan-6
     - **Device:** XC6SLX75
     - **Package:** CSG484
     - **Speed Grade:** -2
   - Click **Finish**

3. **Add Source Files**
   - Right-click on "Hierarchy" in the left panel
   - Select **Add Source**
   - Navigate to the `rtl_src/` folder
   - Select all Verilog files (*.v) and VHDL files (*.vhd)
   - Click **Open** to add them to the project
   - Include subdirectories:
     - `rtl_src/AES/` (AES encryption/decryption modules)
     - `rtl_src/UART/` (UART communication)
     - `rtl_src/PLLs/` (PLL IP cores)
     - `rtl_src/antennas/` (antenna designs)

4. **Add Constraints File**
   - Right-click on the project in the left panel
   - Select **Add Source**
   - Navigate to and select `rtl_src/sakura_g_main_r1.ucf`
   - This file is now linked to your project

5. **Select Top-Level Module**
   - Right-click on your desired top-level module in the Hierarchy (e.g., `singing_fpga_top.v`, `singing_fpga_top_sweep.v`, etc.)
   - Select **Set as Top Module**

6. **Enable Relevant Constraints**
   - Open the UCF file in the editor
   - Find the section for your chosen design variant
   - **Uncomment** only the pin constraints relevant to your variant
   - **Leave commented** any pins/signals not used by your design
   - Save the file

   > **Troubleshooting UCF Issues:** If you experience compilation errors related to the UCF file after changing top-level modules, the UCF file may remain "attached" to the previous module. To resolve this, remove the UCF file from the project and re-add it. In ISE: right-click the UCF file → **Remove**, then re-add it via **Add Source** and relink it to the correct module.

7. **Generate Programming File**
   - In the left panel under "Design," right-click on your top module
   - Select **Generate Programming File**
   - ISE will synthesize, place & route, and generate the bitstream (`.bit` file)
   - Wait for completion (check the console for success/errors)

8. **Verify Output**
   - The generated bitstream will be in your project folder
   - Use this `.bit` file to program the FPGA via JTAG

---

## Testbenches

Simulation testbenches are located in [rtl_src/tb/](rtl_src/tb/). Each testbench validates a specific top-level design:

| Testbench | Target Module | Purpose |
|-----------|--------------------|-------------|
| [`tb_top.v`](rtl_src/tb/tb_top.v) | `singing_fpga_top.v` | Tests multi-frequency RF generation with UART command sequences for all 8 frequency modes (12 kHz → 360 MHz) |
| [`singing_fpga_sweep_tb.v`](rtl_src/tb/singing_fpga_sweep_tb.v) | `singing_fpga_top_sweep.v` | Tests frequency sweep/CW generation with variable division factors and bypass mode |
| [`singing_fpga_top_basic_fsk_tb.v`](rtl_src/tb/singing_fpga_top_basic_fsk_tb.v) | `singing_fpga_top_basic_fsk_modulation.v` | Tests binary FSK with LSB-based frequency selection (0=888 MHz, 1=936 MHz) and state machine transitions |
| [`singing_fpga_top_modulation_tb.v`](rtl_src/tb/singing_fpga_top_modulation_tb.v) | `singing_fpga_top_aes_fsk_modulation.v` or `singing_fpga_top_key_fsk_modulation.v` | Tests AES FSK modulation with 19-byte packet transmission (ciphertext, symbol time, repetition factor) |
