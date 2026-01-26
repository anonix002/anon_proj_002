import serial
import sys
import time
import os
import argparse

def read_bitstream_file(file_path):
    """
    Read bitstream from file supporting binary or hex format
    Returns: 128-bit integer value
    """
    try:
        with open(file_path, 'r') as f:
            content = f.read().strip()
        
        # Remove any whitespace and newlines
        content = ''.join(content.split())
        
        # Detect format and convert to integer
        if content.startswith('0x') or content.startswith('0X'):
            # Hex format
            print("Detected hex format with 0x prefix")
            bitstream = int(content, 16)
        elif all(c in '01' for c in content) and len(content) == 128:
            # Binary format
            print("Detected binary format")
            bitstream = int(content, 2)
        elif all(c in '0123456789ABCDEFabcdef' for c in content):
            # Hex format without 0x prefix
            print("Detected hex format without 0x prefix")
            bitstream = int(content, 16)
        else:
            raise ValueError("Invalid format. File must contain binary (0/1) or hex data")
        
        # Ensure it fits in 128 bits
        if bitstream >= (1 << 128):
            raise ValueError("Bitstream too large. Must be 128 bits or less")
            
        return bitstream
        
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='FSK Modulation Control Script')
    parser.add_argument('bitstream_file', help='Path to bitstream file (binary or hex format)')
    parser.add_argument('symbol_time_ms', type=float, help='Symbol time in milliseconds')
    parser.add_argument('-r', '--repeat', type=int, default=1, 
                       help='Number of times to send the message (default: 1)')
    parser.add_argument('-f', '--repetition-factor', type=int, default=1, 
                       help='Repetition factor for each bit (1-15, default: 1)')
    parser.add_argument('-aes', '--aes-decrypt', action='store_true', help='Use when interacting with AES key leaking architecture')
    
    args = parser.parse_args()
    
    # Validate arguments
    if not os.path.exists(args.bitstream_file):
        print(f"Error: File '{args.bitstream_file}' not found")
        sys.exit(1)
    
    if args.repeat < 1:
        print("Error: Repeat count must be at least 1")
        sys.exit(1)
        
    if args.repetition_factor < 1 or args.repetition_factor > 15:
        print("Error: Repetition factor must be between 1 and 15")
        sys.exit(1)
    
    # Calculate symbol time in clock cycles (12 MHz clock)
    symbol_time_cycles = int(args.symbol_time_ms * 12000)  # 12000 cycles per ms at 12MHz
    
    if symbol_time_cycles > 65535:
        print(f"Error: Symbol time too large. Maximum is {65535/12000:.1f} ms")
        sys.exit(1)
    
    # Read bitstream from file
    print(f"Reading bitstream from: {args.bitstream_file}")
    bitstream = read_bitstream_file(args.bitstream_file)
    bitstream_bin = f"{bitstream:0128b}"
    
    # Display configuration
    print(f"Bitstream: 0x{bitstream:032X}")
    print(f"Symbol time: {args.symbol_time_ms} ms ({symbol_time_cycles} cycles)")
    print(f"Repetition factor: {args.repetition_factor}")
    print(f"Repeat count: {args.repeat}")
    print(f"Total transmission time per message: {args.symbol_time_ms * 128 * args.repetition_factor / 1000:.3f} seconds")
    print(f"Total transmission time (all repeats): {args.symbol_time_ms * 128 * args.repetition_factor * args.repeat / 1000:.3f} seconds")
    
    # Open serial connection
    try:
        p_ser = serial.Serial(port="COM9", baudrate=57600, bytesize=serial.EIGHTBITS, 
                             parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE, 
                             timeout=10, xonxoff=0, rtscts=0, dsrdtr=0)
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)
    
    # Prepare 19-byte packet
    packet = bytearray(19)
    
    # Pack bitstream FIRST (16 bytes, big-endian)
    for i in range(16):
        byte_val = (bitstream >> (8 * (15 - i))) & 0xFF
        packet[i] = byte_val

    # Pack symbol time (2 bytes, big-endian)
    packet[16] = (symbol_time_cycles >> 8) & 0xFF
    packet[17] = symbol_time_cycles & 0xFF
    
    # Pack repetition factor LAST (1 byte)
    packet[18] = args.repetition_factor & 0xFF
    
    print(f"\nPacket: {packet.hex().upper()}")
    
    # Send packet multiple times (repeat is for Python loop only)
    total_start_time = time.time()
    successful_transmissions = 0
    
    for transmission in range(args.repeat):
        print(f"\n{'='*50}")
        print(f"Transmission {transmission + 1} of {args.repeat}")
        print(f"{'='*50}")
        
        # Send packet
        p_ser.write(packet)
        print("Data packet sent, waiting for completion...")
        
        # Wait for completion signal
        start_time = time.time()
        timeout_seconds = (args.symbol_time_ms * 128 * args.repetition_factor / 1000) + 10  # Add 10 second buffer
        
        transmission_successful = False
        
        if args.aes_decrypt:
            # AES mode: Wait for 18 bytes (16 bytes plaintext + 2 bytes status)
            while time.time() - start_time < timeout_seconds:
                if p_ser.in_waiting >= 18:
                    response = p_ser.read(18)
                    # print(response)
                    if len(response) == 18:
                        # Check if last 2 bytes are 0xAAAA
                        status_bytes = (response[16] << 8) | response[17]
                        if status_bytes == 0xAAAA:
                            # Extract plaintext (first 16 bytes)
                            plaintext_bytes = response[:16]
                            plaintext_int = int.from_bytes(plaintext_bytes, byteorder='big')
                            plaintext_bin = f"{plaintext_int:0128b}"
                            
                            print(f"✅ Transmission {transmission + 1} completed successfully!")
                            print(f"Transmission time: {time.time() - start_time:.3f} seconds")
                            print(f"Plaintext (hex): 0x{plaintext_int:032X}")
                            # print(f"Plaintext (bin): {plaintext_bin}")
                            # print(f"Plaintext (bytes): {plaintext_bytes.hex().upper()}")
                            
                            successful_transmissions += 1
                            transmission_successful = True
                            break
                        else:
                            print(f"Unexpected status: 0x{status_bytes:04X} (expected 0xAAAA)")
                time.sleep(0.5)
        else:
            # Normal mode: Wait for 2 bytes (0xAAAA)
            while time.time() - start_time < timeout_seconds:
                if p_ser.in_waiting >= 2:
                    response = p_ser.read(2)
                    if len(response) == 2:
                        response_val = (response[0] << 8) | response[1]
                        if response_val == 0xAAAA:
                            print(f"✅ Transmission {transmission + 1} completed successfully!")
                            print(f"Transmission time: {time.time() - start_time:.3f} seconds")
                            successful_transmissions += 1
                            transmission_successful = True
                            break
                        else:
                            print(f"Unexpected response: 0x{response_val:04X}")
                time.sleep(0.1)
        
        if not transmission_successful:
            print(f"❌ Transmission {transmission + 1} timed out!")

    
    total_time = time.time() - total_start_time
    
    # Display final summary
    print(f"\n{'='*60}")
    print(f"FINAL SUMMARY")
    print(f"{'='*60}")
    print(f"File: {args.bitstream_file}")
    print(f"Bitstream: 0x{bitstream:032X}")
    print(f"Bitstream (bin): {bitstream_bin}")
    print(f"Symbol time: {args.symbol_time_ms} ms per bit, {symbol_time_cycles} clock cycles")
    print(f"Repetition factor: {args.repetition_factor}x per bit")
    print(f"Effective bit time: {args.symbol_time_ms * args.repetition_factor:.3f} ms per logical bit")
    print(f"Data rate: {1000 / (args.symbol_time_ms * args.repetition_factor):.2f} bps, {1/(args.symbol_time_ms * args.repetition_factor):.3f} kbps")
    print(f"Total bits per message: 128")
    print(f"Repeat count: {args.repeat}")
    print(f"Successful transmissions: {successful_transmissions}/{args.repeat}")
    print(f"Expected duration per message: {args.symbol_time_ms * 128 * args.repetition_factor:.3f} ms")
    print(f"Total execution time: {total_time:.3f} seconds")
    
    if successful_transmissions == args.repeat:
        print("🎉 All transmissions completed successfully! 🎉")
    else:
        print(f"⚠️  {args.repeat - successful_transmissions} transmission(s) failed")
    
    p_ser.close()

if __name__ == "__main__":
    main()