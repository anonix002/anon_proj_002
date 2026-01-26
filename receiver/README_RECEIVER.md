# RF Signal Receiver - MATLAB DSP Modulation Analysis

A comprehensive MATLAB receiver implementation for demodulating RF signals (935.5 MHz cellular band) with advanced error correction coding and channel characterization.

## 🎯 Project Overview

This project implements a complete RF signal receiver that:
- **Demodulates** RF signals using STFT spectral analysis
- **Detects** binary bits via threshold-based amplitude analysis
- **Corrects** transmission errors using 5-bit repetition codes
- **Characterizes** channel quality through comprehensive BER analysis

**Key Achievement**: Achieves **88.28% message success rate** on test data despite **27.97% raw bit error rate**, demonstrating effective error correction.


## 🔧 Requirements

### Minimum
- **MATLAB R2018b or later** (string handling support)
- **Signal Processing Toolbox** (REQUIRED)
- **Windows 10/11, macOS, or Linux**
- **8 GB RAM minimum**

### Toolboxes Required
```
✓ Signal Processing Toolbox    (spectrogram, hann, pow2db, db2pow)
✓ Communications Toolbox       (optional, for advanced channel analysis)
```

### Verify Installation
```matlab
% Check MATLAB version
version

% Test Signal Processing Toolbox
which spectrogram

% Quick functionality test
t = 0:0.001:1;
y = sin(2*pi*10*t);
spectrogram(y, 128, 0, 256, 1000)
```

## 📁 Project Structure

```
RF-Signal-Receiver/
│
├── README.md                          # This file
├── Receiver_Code.m                    # Main receiver script
│
├── Audio/
│   ├── 24squares_BB_5ECC_fix.wav     # Sample RF recording (1 sec)
│   └── 44Squares_AR.wav              # Alternative sample
│
└── docs/
    ├── PARAMETERS.md                  # Detailed parameter guide
    ├── FUNCTIONS.md                   # Function reference
    └── TROUBLESHOOTING.md             # Common issues & solutions
```

---

## 📖 Receiver Code Specification

### Main File: `Receiver_Code.m`
`Receiver_Code.m` is a MATLAB RF receiver pipeline that demodulates a repeated transmission from a recorded IQ/baseband WAV using STFT/spectrogram analysis, isolates the signal band with a configurable band-pass mask (and optionally interference notching), and performs bit decisions via a power-threshold detector.

For noise mitigation, it can optionally apply a Wiener filter stage (MMSE-based noise reduction) before detection when SNR is low.

After demodulation, it de-interleaves the `n` repeated 128-bit payload copies, applies repetition-code majority-vote error correction to reconstruct a single 128-bit message, and then runs channel characterization (per-message/overall BER, burst statistics, asymmetry of 0→1 vs 1→0 errors, and a capacity/model estimate).


---

## 🔌 INPUT/OUTPUT SPECIFICATION

### **INPUTS**

#### 1. WAV Audio File (`.wav`)
The received RF signal recording containing repeated transmissions.

**File Format Requirements**
- **Type**: PCM WAV (mono or stereo; auto-converted to mono)
- **Bit Depth**: 16-bit or 32-bit
- **Sample Rate** (`fs`): 1 MHz to 50 MHz RF sampling
- **Duration**: 50 ms to 10 seconds
- **Signal Content**: RF modulation at center frequency

**Example**
```matlab
wavfile = '24squares_BB_5ECC_fix.wav'
% Duration: 1.022 seconds
% Sample rate: ~1 MHz
% Format: PCM 16-bit mono
% Content: Message transmitted 24 times with 5× redundancy (5ECC)
```

---

#### 2. Signal Processing Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `fs` | double (Hz) | *from audioread* | Sampling rate of the WAV file. Determines how many samples correspond to each time unit. **Auto-detected** from audio file metadata. Input: scalar double in samples/second (e.g., 1e6 for 1 MHz) |
| `center_freq` | double (Hz) | 935.5e6 | RF center frequency used to convert baseband frequency axis `f` (from spectrogram) into absolute RF axis: `f_abs = (f + center_freq) / 1e6` (converts to MHz). Input: scalar double in Hz (e.g., 935.5e6 for 935.5 MHz). This parameter is **critical** for correct frequency interpretation. |
| `dt_target` | double (seconds) | 0.005 | Desired time resolution per STFT column (frame duration). Determines frame length in samples: `hop = round(dt_target * fs)`. Input: scalar double in seconds (e.g., 0.005 for 5 ms frames). Larger values → better frequency resolution, worse time resolution. |
| `window` | vector | hann(M, 'periodic') | Taper function applied to each frame before FFT to reduce spectral leakage and windowing artifacts. Input: real-valued vector of length M×1 or 1×M. Example: `window = hann(M, 'periodic')` creates a periodic Hann window. The window length **must match** frame length M. Other options: `hamming()`, `blackman()`, `flattopwin()` |

---

#### 3. Detection Threshold Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `trigger` | double (dB) | -23.7754 | Bit detection threshold in dB. Decision: if `max(filtered_power) > trigger` → bit = '1', else '0'. Input: scalar double in dB. Tuning: Lower values → more '1' bits, higher values → more '0' bits. |
| `epsilon` | double (dB) | 0 | Threshold offset for fine-tuning: effective threshold = `trigger + epsilon`. Input: scalar double. Use for threshold calibration without rerunning detection. |

---

#### 4. Message Extraction Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `n` | integer | 5 | Repetition factor (number of times message is transmitted). Determines how many copies of the message are extracted. Input: positive integer. Example: n=5 extracts 5 × 128-bit messages from the bitstream. |
| `start_index` | integer | 130 | Starting index in the detected bitstream for message extraction. Skips header/synchronization bits. Input: positive integer. Typical range: 100-200 samples to skip transients. |
| `msgLen` | integer | 128 | Length of each message in bits. Input: positive integer. Standard is 128 bits per message. |

---

### **OUTPUTS**

The receiver generates multiple outputs in sequence. All are printed to the MATLAB console.

#### **Output Section 1: Bit Detection**

```
t_sec length is: 1022                          % Number of STFT frames
initial bit stream is: 001010111010...         % Raw detected bitstream
```

**Description**: Shows the number of time frames analyzed and the complete raw detected bitstream (before ECC). This is the direct output of the bit detection algorithm using the threshold on filtered power spectrum.

---

#### **Output Section 2: Message Extraction**

```
Extracting 5 messages of 128 bits each starting from index 130
Message 1: 10001101010111001010110111111111...
Message 2: 10101010111111001000110111011100...
Message 3: 01101111110000111010010111111100...
Message 4: 10001010010001001001111110111010...
Message 5: 10011010111111101111100111011101...
```

**Description**: 
- Shows `n` extracted messages (in this example, n=5)
- Each message is exactly **128 bits**
- Messages are de-interleaved from the raw bitstream using interleaved indexing:
  - **Message 1**: indices [130, 135, 140, 145, ...] (every 5th bit starting at 130)
  - **Message 2**: indices [131, 136, 141, 146, ...]
  - And so on...
- This de-interleaving **spreads burst errors** across different message copies, improving ECC robustness

---

#### **Output Section 3: Error Correction**

```
Input bits length: 640              % 5 messages × 128 bits
Repetition factor: 5                % Majority voting on groups of 5
Output ECC_bits length: 128         % Corrected single message
ECC_bits: 10001010110111001010110111111100111011111100101110...
```

**Description**:
- **Input**: 640 bits (5 copies × 128 bits)
- **Process**: Applies repetition code decoder with majority voting
  - Groups 640 bits into 128 groups of 5 bits each
  - For each group: **If ≥3 bits are '1' → output '1', else output '0'**
  - Can correct up to **2 bit errors per group** (66% reliability)
- **Output**: Single corrected 128-bit message

**ECC Capability**
```
Example group: [1, 0, 1, 1, 0]   % 3 ones, 2 zeros
Majority vote: 1                   % 3/5 > 2/5, so output 1
Error correction: Can fix if at most 2 bits are wrong
```

---

#### **Output Section 4: Comparison & Success Rate**

```
bits sent:
10101010110111101010110110111110111011111100101011111110101110101011111000010010001101000101011001111000100100001010101111001101

bits recieved:
10001010110111001010110111111100111011111100101110111110101111111011111000010010001111100100011001111100100000001010101011001111

Compared first 128 bits -> Hits: 113, Misses: 15, Success rate: 88.28%
trigger value is: -23.7754
start index is: 130
```

**Description**:
- **bits sent**: The known reference/transmitted message (128 bits)
- **bits recieved**: The error-corrected received message (128 bits) after ECC
- **Comparison**:
  - **Hits**: Number of bits matching between sent and received (113)
  - **Misses**: Number of bit errors after ECC (15)
  - **Success rate**: Percentage of correct bits = (Hits / 128) × 100 = **88.28%**
- **Trigger value**: The actual detection threshold used (trigger + epsilon)
- **Start index**: Where message extraction began in the bitstream

---

#### **Output Section 5: Channel Characterization**

Comprehensive statistical analysis of channel quality. Displayed in 8 sections:

##### **5.1 BIT ERROR RATE (BER) ANALYSIS**

```
=== 1. BIT ERROR RATE ANALYSIS ===
Total bits transmitted: 640
Total bit errors: 179
Overall BER: 0.279687 (27.97%)
BER per message - Mean: 0.279687, Std: 0.051051
Min BER: 0.203125, Max BER: 0.328125
```

**Interpretation**:
- **Overall BER = 27.97%**: Approximately 28% of the transmitted bits are received incorrectly before ECC
- **Mean BER = 0.2797**: Average error rate across 5 message copies
- **Std = 0.051**: Standard deviation shows some variation between messages (5 ± 5%)
- **Min/Max**: BER ranges from 20.3% (best message) to 32.8% (worst message)

**Quality Assessment**:
| BER | Quality | Action |
|-----|---------|--------|
| < 1% | Excellent | Could reduce redundancy |
| 1-10% | Good | 5-bit repetition sufficient |
| 10-30% | Marginal | Current 5-bit code works |
| > 30% | Poor | Need stronger ECC (7-9 bit repetition, Hamming) |

---

##### **5.2 ERROR TRANSITION PROBABILITY ANALYSIS**

```
=== 2. ERROR TRANSITION PROBABILITY ANALYSIS ===
Error Transition Matrix:
P(correct | sent 0): 0.660377
P(error   | sent 0): 0.339623 (0→1)
P(correct | sent 1): 0.762667
P(error   | sent 1): 0.237333 (1→0)

Channel Symmetry Analysis:
Error probability difference: 0.102289
Channel is ASYMMETRIC (different error rates for 0s and 1s)
```

**Description**:
- **P(correct | sent 0)**: Probability of receiving '0' when '0' was sent = **66.04%** (34% error rate on 0s)
- **P(error | sent 0)**: Probability of flipping from '0' to '1' = **33.96%**
- **P(correct | sent 1)**: Probability of receiving '1' when '1' was sent = **76.27%** (23.7% error rate on 1s)
- **P(error | sent 1)**: Probability of flipping from '1' to '0' = **23.73%**

**Channel Symmetry**:
- **Asymmetry difference** = |33.96% - 23.73%| = **10.23%**
- **Channel is ASYMMETRIC**: Errors are not equally likely for 0s and 1s
- **Implication**: Channel favors sending '1' bits (lower error rate on 1s)
- **Solution**: Consider adaptive thresholding or asymmetric codes

---

##### **5.3 BURST ERROR ANALYSIS**

```
=== 3. BURST ERROR ANALYSIS ===
Burst Error Statistics:
Total bursts: 122
Average burst length: 1.47 bits
Max burst length: 5 bits
Min burst length: 1 bits
Burst length std: 0.83
Channel characteristic: RANDOM ERRORS (low burstiness)

Error-free Gap Statistics:
Average gap length: 3.69 bits
Max gap length: 15 bits
Min gap length: 1 bits
```

**Description**:
- **Total bursts**: 122 separate error clusters detected
- **Average burst length**: 1.47 bits → mostly **isolated errors** (avg < 1.5 = random, not bursty)
- **Max burst**: 5 consecutive bits were errors once
- **Burstiness classification**:
  - < 1.5 bits average: **RANDOM errors** (uniformly distributed) ✓ **Good for ECC**
  - 1.5-3 bits: Moderate burstiness
  - > 3 bits: High burstiness (requires interleaving)

- **Error-free gaps**: Average of 3.69 correct bits between errors
  - Errors and correct bits are **interspersed**, typical of random channel

**Implication**: Random errors → Standard repetition codes work well; no need for interleaving.

---

##### **5.4 SPATIAL ERROR CORRELATION ANALYSIS**

```
=== 4. SPATIAL ERROR CORRELATION ANALYSIS ===
Bit Position Analysis:
Worst bit positions (highest error rate): [26 62 64 87] (error rate: 0.800)
Best bit positions (lowest error rate): [5 10 17 24 25] (error rate: 0.000)
Average bit error rate: 0.279688
Bit error rate std: 0.201318
POSITION-DEPENDENT errors detected (high variance across bit positions)
```

**Description**:
- **Worst positions** [26, 62, 64, 87]: These 4 bit positions have **80% error rate** (4 out of 5 messages had errors here)
- **Best positions** [5, 10, 17, 24, 25]: These positions have **0% error rate** (perfect across all 5 messages)
- **Position-dependent errors detected**: High standard deviation (0.2013) indicates significant variance
  - Std > 0.1 → **Position-dependent errors are present**
  - Std < 0.1 → Errors uniformly distributed

**Cause Analysis**:
- May indicate **frequency-dependent fading** (certain frequency bins more prone to errors)
- Could be **FFT resolution issue** (signal not aligned with bin centers)
- Suggests **phase offset** or **channel selectivity**

**Recommendation**: Investigate frequency alignment and consider frequency interleaving.

---

##### **5.5 MESSAGE CORRELATION ANALYSIS**

```
=== 5. MESSAGE CORRELATION ANALYSIS ===
Inter-message error correlation: 0.0048
Error patterns are INDEPENDENT between messages
```

**Description**:
- **Correlation = 0.0048**: Very low correlation (close to 0 = independent)
- **Interpretation**: Error patterns across the 5 message copies are **essentially random**
  - If one message has an error at bit position 10, the next message probably doesn't
  - Indicates **no persistent channel state** (memoryless)

**Correlation Classification**:
| Correlation | Meaning |
|-------------|---------|
| < 0.1 | Independent (ideal) ✓ |
| 0.1-0.3 | Weak correlation |
| > 0.3 | Positive correlation (channel memory) |

---

##### **5.6 CHANNEL CAPACITY AND RELIABILITY METRICS**

```
=== 6. CHANNEL CAPACITY AND RELIABILITY METRICS ===
Estimated channel capacity: 0.1425 bits/symbol
Channel efficiency: 14.25% (relative to error-free channel)
Message-level success rate: 0.00% (0/5 messages error-free)
```

**Description**:
- **Channel capacity**: 0.1425 bits/symbol
  - In an error-free channel, you could send 1 bit/symbol
  - With these errors, you effectively send only **14.25% of information**
  - Formula: Capacity = 1 - H(p), where H = binary entropy
  
- **Channel efficiency**: 14.25% relative to perfect channel
  - To send reliable 1 bit/symbol, you need **~7 redundant bits** (inverse of 14.25%)

- **Message-level success rate**: 0% (0 out of 5 messages have zero errors)
  - Every message has at least 1 bit error before ECC
  - **After ECC**: 88.28% success rate (much better!)

---

##### **5.7 CHANNEL MODEL IDENTIFICATION**

```
=== 7. CHANNEL MODEL IDENTIFICATION ===
Runs test - Observed runs: 263, Expected: 258.9
Errors appear INDEPENDENT (consistent with memoryless channel)
Recommended model: Binary Symmetric Channel (BSC)
```

**Description**:
- **Runs test**: Statistical test for randomness
  - **Observed runs**: 263 transitions between error/no-error
  - **Expected runs**: 258.9 (if errors were completely random)
  - **Difference**: 263 vs 258.9 ≈ 4 runs difference
  
- **Result**: Errors are **essentially independent** (memoryless)
  - No strong dependency on previous symbols
  - Consistent with **Binary Symmetric Channel (BSC) model**

- **Channel Models**:
  - **BSC** (current): Each bit has independent error probability p
  - **Gilbert-Elliott**: Errors come in bursts (not applicable here)
  - **Markov Chain**: Error probability depends on previous state (not applicable here)

**Implication**: Standard error correction codes designed for BSC (like Hamming codes, BCH codes) should work well.


---

## ⚡ Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/RF-Signal-Receiver.git
cd RF-Signal-Receiver
```

### 2. Open MATLAB
```matlab
% Navigate to project directory
cd RF-Signal-Receiver

% Run the main script
Receiver_Code
```

### 3. Update Audio File Path
Edit **line 2** of `Receiver_Code.m`:
```matlab
% Change this:
wavfile = '24squares_BB_5ECC_fix.wav';

% To your file (supports full or relative path):
wavfile = 'path/to/your/audio.wav';
```

### 4. Adjust Parameters (Optional)
For your signal characteristics:
```matlab
center_freq = 935.5e6;     % RF center frequency (Hz)
dt_target = 0.005;         % Frame duration (5 ms)
trigger = -23.7754;        % Bit detection threshold (dB)
start_index = 130;         % Message extraction start
n = 5;                      % Repetition factor (number of copies)
epsilon = 0;               % Threshold offset for tuning
```

### 5. Run Analysis
```matlab
% Run entire script
Receiver_Code
% All output printed to console
```

---

## 🔧 Core Functions Explained

### Active Functions (Always Running)

#### `extract5Messages(bits, startIdx)` - De-interleaving
Extracts n copies of the 128-bit message from the detected bitstream:
```matlab
msgs = extract5Messages(bits, 130);  % Returns 1×5 string array
```
- **Input**: Long bitstream (~1022 bits), starting index (130)
- **Output**: 5 × 128-bit messages
- **Method**: Extracts every 5th bit starting at different offsets
  - Message 1: indices [130, 135, 140, ...]
  - Message 2: indices [131, 136, 141, ...]
  - This **spreads burst errors** across copies

#### `repetition_code_decoder(bits, n)` - Error Correction
Implements majority voting ECC:
```matlab
ECC_bits = repetition_code_decoder(bits, 5);  % Input 640, output 128
```
- **Input**: 640 bits (5 copies × 128), repetition factor n=5
- **Process**: Split into 128 groups of 5 bits; majority vote each group
- **Output**: 128-bit corrected message
- **Correction capability**: Fixes up to 2 errors per 5-bit group

#### `channel_characterization_func(msgs, refBits)` - Channel Analysis
Comprehensive post-reception statistics:
```matlab
channel_characterization_func(msgs, refBits);
```
- **Input**: 5 × 128-bit messages, 128-bit reference
- **Output**: 8 analysis sections (BER, transitions, bursts, position, correlation, capacity, model, recommendations)
- **Computation**: Error positions, statistics, entropy, runs test

---

### Utility Functions (Optional/Commented)

#### `bandpass_filter(f_abs_MHz, power_db, center_freq, bandwidth)`
Isolates signal to frequency range:
```matlab
filtered = bandpass_filter(f_abs_MHz, power_dB(:,k), 935.502, 0.001);
% Keeps only [935.502 - 0.0005, 935.502 + 0.0005] MHz
```

#### `wiener_filter(f_abs_MHz, power_dB)` - Adaptive Noise Reduction
For very noisy signals (optional):
```matlab
filtered = wiener_filter(f_abs_MHz, power_dB(:,k));
% Only use if SNR < 5 dB
```

#### `plot_spectrogram_simple()` - Visualization
Display 2D time-frequency spectrogram (commented for performance):
```matlab
plot_spectrogram_simple(y, window, overlap, nfft, fs)
% Uncomment to visualize signal
```

#### `binstr2hex(rxBits)` - Binary to Hex
Convert 128-bit binary to 32-character hex:
```matlab
hex_msg = binstr2hex(ECC_bits);
% "101010101..." → "AA55..."
```

---

## 📊 Parameter Tuning Guide

### For Noisy Signals (BER > 20%)

1. **Increase filter bandwidth**
```matlab
bandwidth = 0.002;  % 2 kHz (from 1 kHz)
filtered_power = bandpass_filter(f_abs_MHz, power_dB(:,k), 935.502, bandwidth);
```

2. **Lower detection threshold**
```matlab
trigger = -25;  % More sensitive
```

3. **Enable Wiener filtering** (uncomment)
```matlab
filtered_power = wiener_filter(f_abs_MHz, power_dB(:,k));
```

4. **Increase repetition factor**
```matlab
n = 7;  % 7-bit instead of 5
```

### For Clean Signals (BER < 5%)

1. **Narrow bandpass filter**
```matlab
bandwidth = 0.0005;  % 500 Hz (tighter)
```

2. **Raise threshold**
```matlab
trigger = -22;  % Less sensitive
```

3. **Reduce redundancy** (if throughput priority)
```matlab
n = 3;  % 3-bit repetition
```

---

## 🐛 Troubleshooting

### Error: "Undefined function 'spectrogram'"
**Solution**: Install Signal Processing Toolbox
```matlab
% MATLAB Home > Add-Ons > Get Add-Ons > Search "Signal Processing Toolbox"
which spectrogram  % Verify installation
```

### Error: "File not found"
**Solution**: Check WAV file path
```matlab
isfile('24squares_BB_5ECC_fix.wav')  % Returns 1 if exists
dir('*.wav')  % List available WAV files
wavfile = fullfile(pwd, 'Audio', 'filename.wav');  % Full path
```

### Low Success Rate (< 50%)

**Cause 1: Trigger threshold**
- Visualize: `plot(f_abs_MHz, power_dB(:,100))` to see actual levels
- Adjust `trigger` parameter

**Cause 2: Sampling rate mismatch**
```matlab
[y_test, fs_test] = audioread(wavfile);
disp(fs_test)  % Should match your RF sample rate
```

**Cause 3: Low SNR**
- Enable Wiener filtering
- Widen bandpass filter
- Increase `n` (repetition factor)

### MATLAB Running Slowly

1. **Process shorter segment**
```matlab
[y, fs] = audioread(wavfile, [1, 100000]);  % First 100k samples
```

2. **Reduce FFT length**
```matlab
nfft = 2^nextpow2(M);  % Instead of 2^nextpow2(2*M)
```

3. **Comment out plotting**
```matlab
% plot_spectrogram_simple(y, window, overlap, nfft, fs)
```

---

## 📚 Theory & Background

### STFT-Based Bit Detection
1. Divide signal into 5 ms frames (STFT)
2. Compute FFT for each frame → frequency content
3. Extract power in bandpass region
4. **Decision**: if max(power) > threshold → bit = '1', else '0'

### Repetition Code ECC
- **Encode**: Send each bit 5 times
- **Decode**: Majority voting (≥3 ones → output 1)
- **Correction**: Can fix up to 2 errors per group (40% error tolerance)

### Channel Characterization
- **BER**: Direct error rate measurement
- **Capacity**: Shannon entropy (throughput limit)
- **Bursts**: Identifies error clustering
- **Symmetry**: Tests fairness to 0s vs 1s

---

## 📖 References

- **Signal Processing**: [MATLAB Toolbox Docs](https://www.mathworks.com/help/signal/)
- **STFT**: [Short-Time Fourier Transform](https://www.mathworks.com/help/signal/ref/stft.html)
- **Error Correction**: [ITU-R BT.1877-3](https://www.itu.int/rec/R-REC-BT.1877-3-202012-I/en)
- **Channel Models**: [Binary Symmetric Channel](https://en.wikipedia.org/wiki/Binary_symmetric_channel)

---

## 📝 License

MIT License - Free for educational and research use
