# RF Signal Transmission & Reception Project

A complete end-to-end RF communication system featuring **FPGA-based FSK modulation** transmission and **MATLAB-based signal processing** receiver with advanced error correction and channel characterization.

## 📋 Project Overview

This project demonstrates a complete RF communication pipeline:

1. **Transmitter (FPGA)**: Generates FSK-modulated signals at cellular frequencies (888-936 MHz) using Xilinx FPGA
2. **Signal Acquisition**: Captures RF transmissions using **SDRSharp** software-defined radio interface
3. **Receiver (MATLAB)**: Demodulates signals, applies error correction (5× repetition codes), and characterizes channel quality

**Key Achievement**: Achieves **88.28% message success rate** despite **27.97% raw bit error rate** through effective error correction and channel analysis.

---

## 🗂️ Project Structure

```
FarField-Singing-FPGAs/
│
├── README.md                              # This file (project overview)
│
├── transmitter/                           # FPGA-based signal generation
│   ├── README_TRANSMITTER.md              # Transmitter detailed documentation
│   ├── bitstreams/                        # Pre-built FPGA bitstreams
│   │   ├── singing_fpga_top_aes_fsk_modulation.bit
│   │   ├── singing_fpga_top_basic_modulation_dipole_888_936.bit
│   │   └── singing_fpga_top_key_modulation_dipole_888_936.bit
│   │
│   ├── rtl_src/                           # Verilog/VHDL source code
│   │   ├── singing_fpga_top*.v            # Top-level variants
│   │   ├── modulator.v                    # FSK modulator core
│   │   ├── square_wave_generator.v
│   │   ├── sakura_g_main_r1.ucf           # FPGA pin constraints
│   │   │
│   │   ├── AES/                           # AES-128 encryption (optional)
│   │   │   ├── AES_Encrypt.v
│   │   │   ├── AES_Decrypt.v
│   │   │   ├── keyExpansion.v
│   │   │   └── [other AES modules]
│   │   │
│   │   ├── antennas/                      # Antenna pattern designs
│   │   │   ├── dipole_quad_full.v
│   │   │   ├── dipole_quad_half.v
│   │   │   ├── monopole_array.v
│   │   │   └── [fractal patterns]
│   │   │
│   │   ├── PLLs/                          # Phase-Locked Loops for different frequencies
│   │   │   ├── pll_888.vhd                # 888 MHz PLL
│   │   │   ├── pll_936.vhd                # 936 MHz PLL
│   │   │   └── [other frequency variants]
│   │   │
│   │   ├── UART/                          # Serial communication interface
│   │   │   ├── uartTop.vhd
│   │   │   ├── uartRx.vhd
│   │   │   ├── uartTx.vhd
│   │   │   └── [UART support modules]
│   │   │
│   │   └── tb/                            # Testbenches
│   │       ├── singing_fpga_top_basic_fsk_tb.v
│   │       ├── singing_fpga_top_modulation_tb.v
│   │       └── tb_top.v
│   │
│   ├── pc_host_scripts/                   # Python host control scripts
│   │   ├── main.py                        # Multi-frequency generator control
│   │   ├── main_sweep.py                  # Frequency sweep control
│   │   ├── main_modulation_bitstring.py   # Basic FSK bitstring modulation
│   │   ├── main_modulation_key.py         # Key/AES FSK modulation
│   │   ├── transfer_rate_calc.py
│   │   └── [key/trigger files]
│   │
│   └── draw2route/                        # FPGA routing utilities
│       ├── fpga_route_gui.py
│       └── xc6slx75-csg484-2.xdlrc
│
└── receiver/                              # MATLAB-based signal analysis
    ├── README_RECEIVER.md                 # Receiver detailed documentation
    ├── Reciever_Code.m                    # Main receiver processing script
    └── [WAV recording samples]
```

---

## 🚀 Quick Start Guide

### Prerequisites

- **FPGA Hardware**: Xilinx Spartan-6 (XC6SLX75) development board
- **RF Frontend**: SDR with 888-936 MHz support (e.g., Airspy R2, HackRF, USRP)
- **PC Host**: Windows/Linux with Python 3.7+ and MATLAB R2018b or later
- **Signal Processing Toolbox**: Required for MATLAB receiver

### Phase 1: FPGA Transmitter Setup

**Objective**: Configure and program the FPGA to transmit FSK-modulated RF signals

#### Step 1.1: Choose Transmitter Variant

Select one of five available transmitter variants based on your needs:

| Variant                                     | Purpose                                  | Use Case                   |
| ------------------------------------------- | ---------------------------------------- | -------------------------- |
| `singing_fpga_top.v`                      | Multi-frequency clock generator          | Static frequency selection |
| `singing_fpga_top_sweep.v`                | Frequency sweep                          | Chirp/sweep demonstrations |
| `singing_fpga_top_basic_fsk_modulation.v` | Binary FSK (888/936 MHz)                 | Simple on/off keying       |
| `singing_fpga_top_key_fsk_modulation.v`   | Arbitrary bitstream FSK                  | Modulate custom messages   |
| `singing_fpga_top_aes_fsk_modulation.v`   | Leakage of AES key via Decryption Oracle | Secure key transmission    |

**→ See [README_TRANSMITTER.md](transmitter/README_TRANSMITTER.md) for detailed specifications**

#### Step 1.2: Build and Program FPGA

```bash
# Navigate to transmitter directory
cd transmitter/

# Option A: Use pre-built bitstream
# Program directly: singing_fpga_top_basic_modulation_dipole_888_936.bit

# Option B: Build from source (Xilinx ISE/Vivado required)
# 1. Open project in Xilinx ISE
# 2. Set device to XC6SLX75-3CSG484
# 3. Select top-level module (e.g., singing_fpga_top_basic_fsk_modulation)
# 4. Synthesize and place & route
# 5. Generate bitstream
# 6. Program FPGA via JTAG
```

#### Step 1.3: Control Transmission via Python

```bash
cd transmitter/pc_host_scripts/

# Example: Basic FSK modulation
python main_modulation_bitstring.py

# Example: Key/AES transmission
python main_modulation_key.py

# Example: Frequency sweep
python main_sweep.py
```

**Configuration Parameters**:

- **Bitstring**: 128-bit payload (binary message)
- **Symbol Time**: Duration per bit (controls bitrate)
- **Repetition Factor**: Number of times to repeat transmission (e.g., 5 for 5× redundancy)
- **Frequencies**: 888 MHz or 936 MHz (FSK carriers)

---

### Phase 2: Signal Acquisition via SDRSharp

**Objective**: Capture the FPGA-transmitted RF signal into a WAV file

#### Step 2.1: Install & Configure SDRSharp

1. Download **SDRSharp** (http://airspy.com/download/) or compatible SDR software
2. Configure for your RF frontend:
   - **Sample Rate**: 1-50 MHz (recommended: 8+ MHz for good frequency resolution)
   - **Frequency**: 888-936 MHz (e.g., 935.5 MHz for center)
   - **Gain**: Adjust to maximize SNR without clipping
   - **Bandwidth**: Match to expected signal bandwidth (~1 MHz for typical FSK)

#### Step 2.2: Record Signal to WAV

1. Connect RF antenna to SDR receiver
2. Tune to transmitter frequency (e.g., 935.5 MHz center)
3. Select **"File → Record"** to save baseband IQ samples to WAV
4. Start FPGA transmitter (Phase 1.3)
5. Record for **1-2 seconds** (captures multiple repetitions with 5× redundancy)
6. Stop recording

**Output**: WAV file (mono/stereo, PCM 16/32-bit) containing baseband RF signal

- Example: `24squares_BB_5ECC_fix.wav` (1.022 seconds @ ~1 MHz sample rate)

---

### Phase 3: MATLAB Signal Analysis & Decoding

**Objective**: Demodulate, decode, and analyze received signal quality

#### Step 3.1: Prepare MATLAB Environment

```matlab
% Verify Signal Processing Toolbox is installed
ver   % Check installed toolboxes

% Add receiver directory to path
addpath('receiver/');
```

#### Step 3.2: Configure Receiver Parameters

Edit [Reciever_Code.m](receiver/Reciever_Code.m) and adjust these key parameters:

```matlab
% Audio file captured in Phase 2
wavfile = '24squares_BB_5ECC_fix.wav';

% RF center frequency (Hz) - adjust to match your SDR tuning
center_freq = 935.5e6;            % 935.5 MHz

% Detection threshold (dB) - adjust based on signal level
trigger = -23.7754;               % Power threshold for bit detection
epsilon = 0;                      % Tolerance margin

% De-interleaving parameters
start_index = 130;                % Start bit offset
n = 5;                            % Repetition factor (5-bit codes)
```

#### Step 3.3: Run Receiver Processing

```matlab
% Execute main receiver script
run('receiver/Reciever_Code.m');
```

**Processing Pipeline**:

1. **STFT Analysis**: Compute spectrogram of received signal
2. **Bandpass Filtering**: Extract signal around center frequency (±0.5 kHz)
3. **Bit Detection**: Threshold power to extract binary bitstream
4. **De-interleaving**: Extract 5 copies of 128-bit message
5. **Error Correction**: Majority-vote on 5-bit repetition codes
6. **Channel Characterization**: Compute BER, burst stats, asymmetry metrics
7. **Success Rate**: Compare decoded bits against reference

#### Step 3.4: Interpret Results

```matlab
% Console output includes:
bits sent:      [128-bit reference]
bits received:  [128-bit decoded]
Hits: XXX, Misses: X, Success rate: XX.XX%
```

**Key Metrics**:

- **BER (Bit Error Rate)**: Raw error percentage before correction
- **Message Success Rate**: Percentage of messages with zero errors after correction
- **Burst Length**: Average length of consecutive errors (indicates channel burstiness)
- **Channel Symmetry**: Asymmetry between 0→1 and 1→0 error rates

---

## 📊 Complete Workflow Example

```
┌─────────────────────────────────────────────────────────────────┐
│ TRANSMITTER (FPGA) - Phase 1                                    │
│ ─────────────────────────────────────────────────────────────   │
│ 1. Program bitstream to FPGA (XC6SLX75)                         │
│ 2. Run host PC Python script                                    │
│ 3. Send message via UART (key/bitstring/ON/OFF)                 │
│ 4. FPGA generates modulated signal/constant transmission/etc    │
│ 5. Signal radiates from antenna                                 │
└─────────────────────────────────────────────────────────────────┘
                            ↓
                    (RF propagation)
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ SIGNAL ACQUISITION (SDRSharp) - Phase 2                         │
│ ─────────────────────────────────────────────────────────────   │
│ 1. Configure SDRSharp                                           │
│ 2. Select File → Record                                         │
│ 3. Enable FPGA transmission (Phase 1)                           │
│ 4. Record for 1-2 seconds                                       │
│ 5. Save as WAV file                                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
                      signal.wav
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ RECEIVER (MATLAB) - Phase 3                                     │
│ ─────────────────────────────────────────────────────────────   │
│ 1. Load WAV file & compute STFT spectrogram                     │
│ 2. Apply bandpass filter (center ±0.5 kHz)                      │
│ 3. Threshold power spectrum → extract bitstream                 │
│ 4. De-interleave 5 copies of message                            │
│ 5. Apply majority-vote error correction (5-repetition)          │
│ 6. Compare with reference bits → compute success rate           │
│ 7. Run channel characterization:                                │
│    - BER analysis (overall, per-message)                        │
│    - Error transition probabilities                             │
│    - Channel model identification                               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
                    Console Output:
                - Success rate: 88.28%
                - Channel characterization report
```

---

## 📖 Documentation Structure

### Transmitter Details

→ **[README_TRANSMITTER.md](transmitter/README_TRANSMITTER.md)**

- Detailed specifications of 5 FPGA variants
- Bitstream selection guide
- Python script documentation
- UART protocol specifications
- Antenna design options

### Receiver Details

→ **[README_RECEIVER.md](receiver/README_RECEIVER.md)**

- MATLAB receiver implementation
- STFT/spectrogram analysis methods
- Error correction algorithms
- Channel characterization metrics
- Parameter tuning guide
- Troubleshooting

---

## 🔧 System Requirements

### Hardware

- **FPGA Board**: Sakura-G with Xilinx Spartan-6 XC6SLX75
- **RF Frontend**: SDR (HackRF, USRP, Airspy, etc.)
- **Antenna**: RTL with transmitting antenna and modulation
- **Host PC**: 8 GB RAM minimum

### Software

- **FPGA Design**: Xilinx ISE/Vivado (for building from source)
- **RF Capture**: SDRSharp, GQRX, or equivalent SDR software
- **Analysis**: MATLAB R2018b+ with Signal Processing Toolbox
- **Host Control**: Python 3.7+ with pyserial

### RF Specifications

- **Frequency Range**: 888-936 MHz (cellular band)
- **Modulation**: FSK/ASK (binary keying)
- **Signal Duration**: 50 ms to 10 seconds

---

## 🎯 Key Features

✅ **Complete System Integration**: From FPGA generation to MATLAB analysis
✅ **Multiple Transmission Modes**: Multi-frequency, sweep, basic/key FSK, AES encryption
✅ **Advanced Error Correction**: 5× repetition code with majority voting
✅ **Flexible Configuration**: Adjustable frequencies, symbol rates, repetition factors

---

## 🐛 Troubleshooting

### FPGA Programming Issues

- Ensure JTAG programmer is connected
- Check device configuration in Xilinx ISE
- Verify pin constraints file (`sakura_g_main_r1.ucf`)

### SDR Recording Issues

- Verify RF hardware is connected and detected
- Check frequency tuning (should see signal peak)
- Ensure sufficient gain (avoid clipping)
- Use 8+ MHz sample rate for good frequency resolution

### MATLAB Receiver Issues

- Verify Signal Processing Toolbox is installed: `ver`
- Check WAV file format (PCM, mono/stereo supported)
- Adjust `trigger` parameter based on signal level
- Verify `center_freq` matches SDR tuning frequency

→ **See [README_RECEIVER.md](receiver/README_RECEIVER.md) for detailed troubleshooting**

---

## 📚 References

- **FPGA**: [Xilinx Spartan-6 FPGA User Guide](https://www.xilinx.com/support/documentation/user_guides/ug385.pdf) | [Sakura-G main website](http://satoh.cs.uec.ac.jp/SAKURA/hardware/SAKURA-G.html)
- **Modulation**: [FSK Modulation - Wikipedia](https://en.wikipedia.org/wiki/Frequency-shift_keying) | [FSK Fundamentals](https://www.analog.com/en/design-notes/understanding-fsk-modulation.html)
- **Error Correction**: [Repetition Code Theory](https://en.wikipedia.org/wiki/Repetition_code) | [Majority Voting Decoding](https://ocw.mit.edu/courses/electrical-engineering-and-computer-science/6-02-introduction-to-eecs-ii-digital-communication-systems-fall-2012/)
- **Signal Processing**: [MATLAB STFT Documentation](https://www.mathworks.com/help/signal/ref/stft.html) | [Spectrogram Analysis](https://www.mathworks.com/help/signal/ref/spectrogram.html) | [Airspy R2](https://airspy.com/airspy-r2/)
- **Channel Characterization**: [Bit Error Rate (BER) Theory](https://en.wikipedia.org/wiki/Bit_error_rate) | [Burst Error Analysis](https://www.mathworks.com/help/comm/ug/channel-noise-models.html) | [Gilbert-Elliott Channel Model](https://en.wikipedia.org/wiki/Gilbert%E2%80%93Elliott_model)

---

## 📧 Support

For questions or issues, refer to:

- [README_TRANSMITTER.md](transmitter/README_TRANSMITTER.md) - FPGA/transmitter details
- [README_RECEIVER.md](receiver/README_RECEIVER.md) - MATLAB/receiver details
- Code comments in `rtl_src/` and `pc_host_scripts/`

---

**Last Updated**: January 2026
