%Modulation4
%wiener filter
wavfile = '24squares_BB_5ECC_fix.wav';
%wavfile = '44Squares_AR.wav';

% Read WAV file
[y, fs] = audioread(wavfile);
t = seconds(0:1/fs:(size(y,1)-1)/fs);

% If stereo, convert to mono
if size(y, 2) > 1
    y = mean(y, 2);
end


% Parameters
dt_target = 0.005;                                % 5 ms [1]
hop = round(dt_target * fs);                      % samples per step [1]
center_freq = 935.5e6;             % center frequency in Hz
M = hop;                                          % 5 ms frames [1]
overlap = M - hop;                                % = 0 [1]
window = hann(M, 'periodic');                     % window length equals M [1]
%nfft = max(M, 2^nextpow2(M));                     % FFT length [1]
nfft = 2^nextpow2(2*M); % instead of max(M, 2^nextpow2(M))


y = transpose(y);
t = transpose(t);
%% Frequency domain
% Compute spectrogram STFT
[S, f, t_sec] = spectrogram(y, window, overlap, nfft , fs);     % S: freq x time, f: Hz, t: s [1]
%plot_spectrogram_simple(y, window, overlap, nfft , fs)
disp("t_sec length is:"+length(t_sec))

% Compute power (linear) and convert to dB
P = abs(S).^2;                           % power per bin [1]
power_dB = pow2db(P + eps);              % convert to dB, EPS avoids -Inf [3]

% Absolute frequency axis in MHz
f_abs_MHz = (f + center_freq) / 1e6;     % center-offset to absolute MHz [1]

% figure('Name','Power vs Frequency over Time','Color','w');
% hLine = plot(f_abs_MHz, power_dB(:,1));  % first time slice [1]
% xlabel('Frequency (MHz)'); ylabel('Power (dB)');
% title('Power vs Frequency over Time');
% grid on;
% 
% % Axis limits: span ±0.15 MHz around center; dynamic range 60 dB from peak
% xlim([center_freq/1e6 - 1.5, center_freq/1e6 + 1.5]);                        % MHz limits [1]
% ylim([max(power_dB(:)) - 60, max(power_dB(:))+10]);                                % 60 dB span [3]
% 
% % Animate over time slices (t_sec is in seconds)
% for k = 1:length(t_sec)
%     %check 935.9977 mhz
%     %check 935.996650 mhz
%     %power_dB_notched = notch_spectrum_bins(f_abs_MHz, power_dB(:,k), 935.995, 1);
%     %filtered_power = wiener_filter(f_abs_MHz, power_dB(:,k));
%     filtered_power = bandpass_filter(f_abs_MHz, power_dB(:,k),935.502,0.001);
%     set(hLine, 'YData', filtered_power);
%     %set(hLine, 'YData', power_dB(:, k));                                        % update spectrum line [1]
%     title(sprintf('Power Spectrum at t = %.5f seconds', t_sec(k)));              % update title with seconds [1]
%     drawnow;                                                                     % refresh UI [1]
%     pause(0.1);                                                                  % pacing [1]
% end

%% Start bitstream
successRate=0;
epsilon=0;
start_index=130;
trigger=-23.7754;
bits = "";
for k = 1:length(t_sec)
    %power_dB_notched = notch_spectrum_bins(f_abs_MHz, power_dB(:,k), 935.995, 1);
    %filtered_power = wiener_filter(f_abs_MHz, power_dB_notched);
    filtered_power = bandpass_filter(f_abs_MHz, power_dB(:,k),935.502,0.001);
    if (max(filtered_power) > trigger+epsilon)
        bits = append(bits,"1");       
    else
        bits = append(bits,"0");
    end
end

%% ECC part
disp("initial bit stream is: " + bits)
s1=130;
n=5;
msgs = extract5Messages(bits, 130);
bits = bits{1}(start_index:(start_index-1+128*5));

ECC_bits = repetition_code_decoder(bits, n);

% Display result
fprintf('Input bits length: %d\n', strlength(bits));
fprintf('Repetition factor: %d\n', n);
fprintf('Output ECC_bits length: %d\n', strlength(ECC_bits));
fprintf('ECC_bits: %s\n', ECC_bits);






%% final success rate
% Inputs: reference and received bit strings (possibly different lengths)
refBits = "10101010110111101010110110111110111011111100101011111110101110101011111000010010001101000101011001111000100100001010101111001101";     % example
rxBits = ECC_bits;
%disp(bits)
bool = trigger_check(bits);
%disp("bool is:"+bool)
%rxBits = binstr2hex(bits); 
% disp("time per bit ~= " + mean(diff(t_sec)) + " seconds")
% disp("length of original bit sent is:"+strlength(refBits));
% disp("length of recieved bit is:"+strlength(rxBits));
% 
disp("bits sent:"+newline+ refBits);
disp("bits recieved:"+newline+(rxBits));
% 


% Ensure string type and determine common length
refBits = string(refBits);                                      % string handling [1]
rxBits  = string(rxBits);
L = min(strlength(refBits), strlength(rxBits));                 % common length [1]

% Truncate to common length
A = char(extractBetween(refBits, 1, L));                        % char arrays for indexing [1]
B = char(extractBetween(rxBits,  1, L));

% Compare per character
hitsMask = (A == B);                                            % position-wise equality [1]
numHits = sum(hitsMask);                                        % correct bits [1]
numMiss = L - numHits;                                          % incorrect bits
successRate = 100 * numHits / L;

% Report
fprintf('Compared first %d bits -> Hits: %d, Misses: %d, Success rate: %.2f%%\n epsilon is: %d', ...
       L, numHits, numMiss, successRate, epsilon);
disp(newline+"trigger value is: "+(trigger+epsilon))
disp(newline+"start index is: "+start_index)

% Call the function with your msgs array and reference bits
channel_characterization_func(msgs, refBits);

function hexStr = binstr2hex(rxBits)
%BINSTR2HEX Convert a string/char of bits to a hexadecimal string.
%   hexStr = BINSTR2HEX(rxBits)
%   - rxBits: string or char, e.g., "1011..." or '1011...'
%   - hexStr: string, uppercase hex without spaces (e.g., "0FA3")

    % Normalize to char for indexing
    b = char(string(rxBits));

    % Validate content (optional but helpful)
    if ~all(b == '0' | b == '1')
        error('Input must contain only ''0'' and ''1'' characters.');
    end

    % Pad left with zeros to a multiple of 4 bits
    pad = mod(4 - mod(numel(b), 4), 4);
    if pad > 0
        b = [repmat('0', 1, pad) b];
    end

    % Group into 4-bit nibbles (rows)
    nibbles = reshape(b, 4, []).';

    % Convert each nibble to hex
    decVals = bin2dec(nibbles);         % decimal per nibble [web:183]
    hexRows = upper(dec2hex(decVals));  % hex chars

    % Join rows into a single string
    hexStr = string(reshape(hexRows.', 1, []));
end


function tf = trigger_check(bits)
% Return true if '10101010' occurs anywhere inside bits (not necessarily at start).
    pat = "10101010";
    if isstring(bits)
        tf = contains(bits, pat);                 % string scalar case [web:161]
    else
        % Treat as char vector
        tf = ~isempty(strfind(bits, char(pat)));  % char fallback [web:161]
        % In newer MATLAB versions, you can also use: tf = contains(string(bits), pat); [web:161]
    end
end


function filtered_power_dB = histogram_filter(f_abs_MHz, power_linear)
    [counts, bin_edges] = histcounts(power_linear, 150); % Create histogram with 100 bins
    most_frequent_bin_index = find(counts == max(counts), 1, 'first'); % index of highest count
    most_frequent_value = (bin_edges(most_frequent_bin_index) + bin_edges(most_frequent_bin_index + 1)) / 2; % bin center
    filtered_power_dB = most_frequent_value;
end

function filtered_dB = wiener_filter(f_abs_MHz, power_dB)
    power_linear = 10.^(power_dB./10);
    noise_power = histogram_filter(f_abs_MHz, power_linear);
    signal_power = power_linear - noise_power;
    signal_power = max(signal_power, 0); %drop values below 0.
    H_wiener = signal_power ./ (signal_power + noise_power);
    filtered_linear = H_wiener .* power_linear;
    filtered_dB = 10 .* log10(filtered_linear + 1e-12);
end


function filtered_signal = bandpass_filter(f_abs_MHz, power_db,center_freq,bandwidth)
        lower_bound = center_freq - bandwidth / 2;
        upper_bound = center_freq + bandwidth / 2;
        mask = (f_abs_MHz >= lower_bound) & (f_abs_MHz <= upper_bound);
        filtered_signal = -inf(size(power_db)); % fill with -Inf like full_like
        filtered_signal(mask) = power_db(mask);

end

function power_dB_out = notch_spectrum_bins(f_abs_MHz, power_dB, center_MHz, bw_kHz)
% Zero out bins around center_MHz in the spectrum given by (f_abs_MHz, power_dB).
% f_abs_MHz: frequency vector in MHz (N x 1)
% power_dB : power spectrum in dB (N x T or N x 1)
% center_MHz: notch center in MHz (scalar)
% bw_kHz    : notch bandwidth in kHz (scalar, e.g., 3)
%
% Returns power_dB_out with bins in [center_MHz - bw/2, center_MHz + bw/2] set to zero power.

    % Ensure column frequency vector
    f = f_abs_MHz(:);                         % N x 1

    % Build boolean mask of bins to zero
    bw_MHz = bw_kHz / 1e3;                    % convert kHz -> MHz
    mask = abs(f - center_MHz) <= bw_MHz/2;   % N x 1

    % Convert dB -> linear power, zero selected bins, then back to dB
    P = db2pow(power_dB);                     % element-wise for vectors/matrices [2]
    if isvector(power_dB)
        P(mask) = 0;                          % zero power at those frequencies
    else
        P(mask, :) = 0;                       % zero across all time columns
    end
    power_dB_out = pow2db(P + eps);           % avoid -Inf at strict zeros for plotting [3]
end


function [original_index, hop, M] = find_original_time_index(spec_index, fs, dt_target, original_length)

    % Defaults
    if nargin < 3 || isempty(dt_target), dt_target = 0.005; end
    if nargin < 4, original_length = []; end

    % Window length and hop (overlap = 0 in this setup)
    M   = round(dt_target * fs);
    hop = M;  % with overlap = 0

    % Map spectrogram column to original index at segment midpoint
    % idx_start = 1 + (spec_index-1)*hop
    % idx_center ≈ idx_start + floor((M-1)/2) ≈ round((spec_index-1)*hop + M/2 + 1)
    original_index = round((double(spec_index) - 1) * hop + M/2 + 1);

    % Optional bounds checking
    if ~isempty(original_length)
        original_index = max(1, min(original_index, original_length));
    end
end

function [prefix, prefixLen, pct128] = longest_prefix_bits(refBits, rxBits)
% longest_prefix_bits Find longest common prefix between refBits and rxBits.
% Returns the prefix string, its length, and percent of 128 bits.
% If the prefix is all '0's (any length), treat it as empty (length 0).

% Accept string or char inputs
ref = convertStringsToChars(refBits);
rx  = convertStringsToChars(rxBits);

% Work with row character vectors
ref = ref(:).';
rx  = rx(:).';

% Compare up to the shorter length
n = min(numel(ref), numel(rx));
eqmask = (ref(1:n) == rx(1:n));          % character-wise equality from start

% First mismatch position -> prefix length
firstMismatch = find(~eqmask, 1, 'first');
if isempty(firstMismatch)
    prefixLen = n;                        % all n match
else
    prefixLen = firstMismatch - 1;
end

% Extract prefix string
prefix = ref(1:prefixLen);

% Exclude if prefix is all '0's (treat as empty)
if ~isempty(prefix) && all(prefix == '0')
    prefix    = '';
    prefixLen = 0;
end

% Percent of 128
pct128 = 100 * (prefixLen / 128);
end

function plot_time_db(y, fs)
% plot_time_db Plot amplitude in dB versus time.
%   plot_time_db(y, fs) converts |y| to dB and plots against time (s).

    % Collapse to mono if multiple channels
    if size(y,2) > 1
        y = mean(y, 2);
    end
    y = y(:);

    % Time axis (seconds)
    t = (0:numel(y)-1).' / fs;

    % Amplitude to dB (20*log10), add eps to avoid -Inf at zeros
    amp_dB = mag2db(abs(y) + eps);

    % Plot
    figure('Color','w');
    plot(t, amp_dB, 'b-'); grid on;
    xlabel('Time (s)');
    ylabel('Amplitude (dB)');
    title('Amplitude vs Time (dB)');
end


function plot_spectrogram_simple(y, window, overlap, nfft, fs)
% Centered spectrogram around 936 MHz (absolute y-axis in MHz).

% Mono
if size(y,2) > 1, y = mean(y,2); end
y = y(:);

% RF center (Hz)
center_freq = 935.996e6;

% STFT with centered frequency range: f_off spans [-fs/2, +fs/2]
[S, f_off, t_sec] = spectrogram(y, window, overlap, nfft, fs, "centered");  % two-sided centered [21]
% Power -> dB
P_dB = pow2db(abs(S).^2 + eps);  % dB of power per bin [22]

% Convert to absolute RF frequency (MHz)
f_abs_MHz = (center_freq + f_off)/1e6;

% Plot
figure('Color','w');
imagesc(t_sec, f_abs_MHz, P_dB);  % time vs absolute frequency (MHz) [23]
axis xy;                           % low freq at bottom [24]
colormap(turbo); colorbar;
xlabel('Time (s)'); ylabel('Frequency (MHz)');
title('Spectrogram centered at 935.55 MHz');

% Show the natural span of the centered STFT (±fs/2 around 936 MHz)
ylim(([center_freq - fs/2, center_freq + fs/2]/1e6));
end

function ECC_bits = majority_vote_ecc(bits, s1, f1, s2, f2, s3, f3, s4, f4, s5, f5, print_stats)
    % Extract the 5 bit sequences from the input string
    bit_sequences = cell(5,1);
    bit_sequences{1} = bits{1}(s1:f1);
    bit_sequences{2} = bits{1}(s2:f2);
    bit_sequences{3} = bits{1}(s3:f3);
    bit_sequences{4} = bits{1}(s4:f4);
    bit_sequences{5} = bits{1}(s5:f5);
    
    % Get the length of each sequence (should all be 128)
    seq_length = length(bit_sequences{1});
    
    % Initialize the ECC result string
    ECC_bits = "";
    
    % Print header if requested
    if print_stats
        fprintf('Bit Position | Ones Count | Zeros Count | ECC Bit\n');
        fprintf('-------------|------------|-------------|--------\n');
    end
    
    % For each bit position (1 to 128)
    for i = 1:seq_length
        % Count ones and zeros at position i across all 5 sequences
        ones_count = 0;
        zeros_count = 0;
        
        for j = 1:5
            if bit_sequences{j}(i) == '1'
                ones_count = ones_count + 1;
            else
                zeros_count = zeros_count + 1;
            end
        end
        
        % Apply majority voting: if more 1s than 0s, choose 1
        if ones_count > zeros_count
            ECC_bits = ECC_bits + "1";
            ecc_bit = '1';
        else
            ECC_bits = ECC_bits + "0";
            ecc_bit = '0';
        end
        
        % Print the counts for this bit position if requested
        if print_stats
            fprintf('%12d | %10d | %11d | %7s\n', i, ones_count, zeros_count, ecc_bit);
        end
    end
    
    % Print summary if requested
    if print_stats
        fprintf('\nECC correction complete. Final ECC_bits length: %d\n', strlength(ECC_bits));
    end
end

function ECC_bits = repetition_code_decoder(bits, n)
    % Convert string to char if needed
    if isstring(bits)
        bits = char(bits);
    end
    
    % Check if bits length is divisible by n
    total_length = length(bits);
    if mod(total_length, n) ~= 0
        error('Length of bits (%d) must be divisible by n (%d)', total_length, n);
    end
    
    % Calculate expected output length
    output_length = total_length / n;
    
    % Initialize output string
    ECC_bits = "";
    
    % Process each group of n bits
    for i = 1:output_length
        % Extract n consecutive bits
        start_idx = (i-1) * n + 1;
        end_idx = i * n;
        bit_group = bits(start_idx:end_idx);
        
        % Count ones and zeros in this group
        ones_count = sum(bit_group == '1');
        zeros_count = sum(bit_group == '0');
        
        % Majority vote: if more 1s than 0s, choose 1
        if ones_count > zeros_count
            ECC_bits = ECC_bits + "1";
        else
            ECC_bits = ECC_bits + "0";
        end
    end
    
    % Verify output length is 128
    if strlength(ECC_bits) ~= 128
        warning('Output length is %d, expected 128', strlength(ECC_bits));
    end
end
function msgs = extract5Messages(bits, startIdx)
% extract5Messages  Extract five 128-bit interleaved messages from a bitstream.
%   msgs = extract5Messages(bits, startIdx) takes a text bitstream 'bits'
%   and extracts 5 messages of 128 bits each starting from startIdx.
%   Message 1: startIdx, startIdx+5, startIdx+10, ... (every 5th bit)
%   Message 2: startIdx+1, startIdx+6, startIdx+11, ... (every 5th bit)
%   Message 3: startIdx+2, startIdx+7, startIdx+12, ... (every 5th bit)
%   Message 4: startIdx+3, startIdx+8, startIdx+13, ... (every 5th bit)
%   Message 5: startIdx+4, startIdx+9, startIdx+14, ... (every 5th bit)

    % Normalize input to a row char vector for indexing
    if isstring(bits)
        bitstr = bits(1);          % string scalar -> extract element
        bitstr = char(bitstr);     % convert to char vector
    elseif iscell(bits)
        bitstr = bits{1};          % cellstr -> char vector
    else
        bitstr = bits;             % already char vector
    end
    bitstr = char(bitstr);
    bitstr = bitstr(:).';          % ensure row

    % Parameters
    numMsgs = 5;                   % number of messages
    msgLen  = 128;                 % bits per message

    % Initialize output
    msgs = strings(1, numMsgs);
    
    fprintf('Extracting 5 messages of 128 bits each starting from index %d\n', startIdx);
    
    % Extract each interleaved message
    for k = 1:numMsgs
        % Calculate indices for message k (0-based offset k-1)
        indices = startIdx + (k-1) + (0:msgLen-1) * numMsgs;
        
        % Extract bits at these indices
        msgBits = bitstr(indices);
        msgs(k) = string(msgBits);
        
        fprintf('Message %d: %s\n', k, msgBits);
    end
end


function channel_characterization_func(msgs, refBits)
% channel_characterization  Comprehensive channel analysis of 5 messages
%   channel_characterization(msgs, refBits) analyzes communication channel
%   characteristics by comparing 5 received messages with reference bits
%   and computing various error statistics and channel parameters
%
%   Input:
%   msgs    - 1x5 string array containing 5 received messages of 128 bits each
%   refBits - reference bit string (128 bits)
%
%   Performs comprehensive channel characterization including:
%   - Bit Error Rate (BER) analysis
%   - Error transition probabilities  
%   - Burst error analysis
%   - Spatial error correlation
%   - Channel reliability metrics

    fprintf('=== COMPREHENSIVE CHANNEL CHARACTERIZATION ===\n\n');
    
    % Convert reference to char for indexing
    refBits = char(string(refBits));
    if length(refBits) ~= 128
        error('Reference bits must be exactly 128 bits long');
    end
    
    % Initialize analysis arrays
    numMsgs = length(msgs);
    errors = zeros(numMsgs, 128);  % Error positions
    ber_per_msg = zeros(numMsgs, 1);
    
    % Convert messages to char and analyze each message
    for k = 1:numMsgs
        rxBits = char(msgs(k));
        if length(rxBits) ~= 128
            warning('Message %d length is %d, expected 128', k, length(rxBits));
            minLen = min(length(rxBits), 128);
            rxBits = [rxBits, repmat('0', 1, 128-length(rxBits))];  % pad if short
            rxBits = rxBits(1:128);  % truncate if long
        end
        
        % Find error positions
        errors(k, :) = (refBits ~= rxBits);
        ber_per_msg(k) = sum(errors(k, :)) / 128;
        
        fprintf('Message %d: %d errors, BER = %.4f\n', k, sum(errors(k, :)), ber_per_msg(k));
    end
    
    %% 1. BIT ERROR RATE ANALYSIS
    fprintf('\n=== 1. BIT ERROR RATE ANALYSIS ===\n');
    total_bits = numMsgs * 128;
    total_errors = sum(errors(:));
    overall_ber = total_errors / total_bits;
    
    fprintf('Total bits transmitted: %d\n', total_bits);
    fprintf('Total bit errors: %d\n', total_errors);
    fprintf('Overall BER: %.6f (%.4f%%)\n', overall_ber, overall_ber*100);
    fprintf('BER per message - Mean: %.6f, Std: %.6f\n', mean(ber_per_msg), std(ber_per_msg));
    fprintf('Min BER: %.6f, Max BER: %.6f\n', min(ber_per_msg), max(ber_per_msg));
    
    %% 2. ERROR TRANSITION PROBABILITY ANALYSIS
    fprintf('\n=== 2. ERROR TRANSITION PROBABILITY ANALYSIS ===\n');
    
    % Count transitions across all messages
    transitions = zeros(2, 2); % [ref_bit][error_occurred]
    
    for k = 1:numMsgs
        rxBits = char(msgs(k));
        for i = 1:min(length(rxBits), 128)
            ref_bit = str2double(refBits(i)) + 1;  % 1 for '0', 2 for '1'
            error_occurred = errors(k, i) + 1;     % 1 for correct, 2 for error
            transitions(ref_bit, error_occurred) = transitions(ref_bit, error_occurred) + 1;
        end
    end
    
    % Calculate probabilities
    p_0_to_0 = transitions(1, 1) / sum(transitions(1, :));  % P(received 0 | sent 0)
    p_0_to_1 = transitions(1, 2) / sum(transitions(1, :));  % P(error | sent 0)  
    p_1_to_1 = transitions(2, 1) / sum(transitions(2, :));  % P(received 1 | sent 1)
    p_1_to_0 = transitions(2, 2) / sum(transitions(2, :));  % P(error | sent 1)
    
    fprintf('Error Transition Matrix:\n');
    fprintf('P(correct | sent 0): %.6f\n', p_0_to_0);
    fprintf('P(error   | sent 0): %.6f (0→1)\n', p_0_to_1);
    fprintf('P(correct | sent 1): %.6f\n', p_1_to_1);  
    fprintf('P(error   | sent 1): %.6f (1→0)\n', p_1_to_0);
    
    fprintf('\nChannel Symmetry Analysis:\n');
    symmetry_diff = abs(p_0_to_1 - p_1_to_0);
    fprintf('Error probability difference: %.6f\n', symmetry_diff);
    if symmetry_diff < 0.01
        fprintf('Channel appears SYMMETRIC (similar error rates for 0s and 1s)\n');
    else
        fprintf('Channel is ASYMMETRIC (different error rates for 0s and 1s)\n');
    end
    
    %% 3. BURST ERROR ANALYSIS
    fprintf('\n=== 3. BURST ERROR ANALYSIS ===\n');
    
    burst_lengths = [];
    gap_lengths = [];
    
    for k = 1:numMsgs
        error_seq = errors(k, :);
        
        % Find burst lengths (consecutive errors)
        in_burst = false;
        current_burst = 0;
        current_gap = 0;
        
        for i = 1:128
            if error_seq(i) == 1  % Error
                if ~in_burst
                    if current_gap > 0
                        gap_lengths = [gap_lengths, current_gap];
                    end
                    in_burst = true;
                    current_burst = 1;
                    current_gap = 0;
                else
                    current_burst = current_burst + 1;
                end
            else  % No error
                if in_burst
                    burst_lengths = [burst_lengths, current_burst];
                    in_burst = false;
                    current_burst = 0;
                    current_gap = 1;
                else
                    current_gap = current_gap + 1;
                end
            end
        end
        
        % Handle end conditions
        if in_burst && current_burst > 0
            burst_lengths = [burst_lengths, current_burst];
        end
        if ~in_burst && current_gap > 0
            gap_lengths = [gap_lengths, current_gap];
        end
    end
    
    if ~isempty(burst_lengths)
        fprintf('Burst Error Statistics:\n');
        fprintf('Total bursts: %d\n', length(burst_lengths));
        fprintf('Average burst length: %.2f bits\n', mean(burst_lengths));
        fprintf('Max burst length: %d bits\n', max(burst_lengths));
        fprintf('Min burst length: %d bits\n', min(burst_lengths));
        fprintf('Burst length std: %.2f\n', std(burst_lengths));
        
        % Classify channel burstiness
        avg_burst = mean(burst_lengths);
        if avg_burst < 1.5
            fprintf('Channel characteristic: RANDOM ERRORS (low burstiness)\n');
        elseif avg_burst < 3
            fprintf('Channel characteristic: MODERATE BURSTS\n');
        else
            fprintf('Channel characteristic: HIGH BURSTINESS\n');
        end
    else
        fprintf('No burst errors detected - all errors are isolated\n');
    end
    
    if ~isempty(gap_lengths)
        fprintf('\nError-free Gap Statistics:\n');
        fprintf('Average gap length: %.2f bits\n', mean(gap_lengths));
        fprintf('Max gap length: %d bits\n', max(gap_lengths));
        fprintf('Min gap length: %d bits\n', min(gap_lengths));
    end
    
    %% 4. SPATIAL ERROR CORRELATION ANALYSIS
    fprintf('\n=== 4. SPATIAL ERROR CORRELATION ANALYSIS ===\n');
    
    % Bit position error rates
    bit_error_rates = sum(errors, 1) / numMsgs;
    worst_positions = find(bit_error_rates == max(bit_error_rates));
    best_positions = find(bit_error_rates == min(bit_error_rates));
    
    fprintf('Bit Position Analysis:\n');
    fprintf('Worst bit positions (highest error rate): %s (error rate: %.3f)\n', ...
            mat2str(worst_positions), max(bit_error_rates));
    fprintf('Best bit positions (lowest error rate): %s (error rate: %.3f)\n', ...
            mat2str(best_positions(1:min(5, length(best_positions)))), min(bit_error_rates));
    fprintf('Average bit error rate: %.6f\n', mean(bit_error_rates));
    fprintf('Bit error rate std: %.6f\n', std(bit_error_rates));
    
    % Check for position-dependent errors
    if std(bit_error_rates) > 0.1
        fprintf('POSITION-DEPENDENT errors detected (high variance across bit positions)\n');
    else
        fprintf('POSITION-INDEPENDENT errors (uniform across bit positions)\n');
    end
    
    %% 5. MESSAGE CORRELATION ANALYSIS
    fprintf('\n=== 5. MESSAGE CORRELATION ANALYSIS ===\n');
    
    % Cross-correlation between error patterns of different messages
    correlations = zeros(numMsgs, numMsgs);
    for i = 1:numMsgs
        for j = 1:numMsgs
            correlations(i,j) = corr(errors(i,:)', errors(j,:)');
        end
    end
    
    % Average off-diagonal correlation (between different messages)
    off_diag = correlations(~eye(numMsgs));
    avg_correlation = mean(off_diag(~isnan(off_diag)));
    
    fprintf('Inter-message error correlation: %.4f\n', avg_correlation);
    if abs(avg_correlation) < 0.1
        fprintf('Error patterns are INDEPENDENT between messages\n');
    elseif avg_correlation > 0.3
        fprintf('Error patterns show POSITIVE correlation (similar error locations)\n');
    else
        fprintf('Error patterns show WEAK correlation\n');
    end
    
    %% 6. CHANNEL CAPACITY AND RELIABILITY METRICS  
    fprintf('\n=== 6. CHANNEL CAPACITY AND RELIABILITY METRICS ===\n');
    
    % Shannon capacity estimation (assuming BSC model)
    H_p = -p_0_to_1 * log2(p_0_to_1 + eps) - (1-p_0_to_1) * log2(1-p_0_to_1 + eps);
    capacity_0 = 1 - H_p;
    H_p = -p_1_to_0 * log2(p_1_to_0 + eps) - (1-p_1_to_0) * log2(1-p_1_to_0 + eps);  
    capacity_1 = 1 - H_p;
    avg_capacity = (capacity_0 + capacity_1) / 2;
    
    fprintf('Estimated channel capacity: %.4f bits/symbol\n', avg_capacity);
    fprintf('Channel efficiency: %.2f%% (relative to error-free channel)\n', avg_capacity * 100);
    
    % Reliability metrics
    successful_msgs = sum(ber_per_msg == 0);
    msg_success_rate = successful_msgs / numMsgs;
    
    fprintf('Message-level success rate: %.2f%% (%d/%d messages error-free)\n', ...
            msg_success_rate * 100, successful_msgs, numMsgs);
    
    %% 7. STATISTICAL TESTS AND CHANNEL MODEL IDENTIFICATION
    fprintf('\n=== 7. CHANNEL MODEL IDENTIFICATION ===\n');
    
    % Test for independence (runs test approximation)
    all_errors = errors(:);
    runs = 1;
    for i = 2:length(all_errors)
        if all_errors(i) ~= all_errors(i-1)
            runs = runs + 1;
        end
    end
    
    expected_runs = 2 * total_errors * (total_bits - total_errors) / total_bits + 1;
    fprintf('Runs test - Observed runs: %d, Expected: %.1f\n', runs, expected_runs);
    
    if abs(runs - expected_runs) < sqrt(expected_runs)
        fprintf('Errors appear INDEPENDENT (consistent with memoryless channel)\n');
        fprintf('Recommended model: Binary Symmetric Channel (BSC)\n');
    else
        fprintf('Errors show DEPENDENCY (memory in channel)\n');
        fprintf('Recommended model: Gilbert-Elliott or Markov Chain\n');
    end
    
    %% 8. PERFORMANCE RECOMMENDATIONS
    fprintf('\n=== 8. PERFORMANCE OPTIMIZATION RECOMMENDATIONS ===\n');
    
    if overall_ber > 0.1
        fprintf('• HIGH error rate - Consider stronger error correction coding\n');
    elseif overall_ber > 0.01  
        fprintf('• MODERATE error rate - Current 5-repetition code may be sufficient\n');
    else
        fprintf('• LOW error rate - Could reduce redundancy for higher throughput\n');
    end
    
    if ~isempty(burst_lengths) && mean(burst_lengths) > 2
        fprintf('• Burst errors detected - Consider interleaving techniques\n');
    end
    
    if std(ber_per_msg) > 0.05
        fprintf('• High variance in message quality - Check for time-varying channel\n');
    end
    
    fprintf('\n=== CHANNEL CHARACTERIZATION COMPLETE ===\n');
end
