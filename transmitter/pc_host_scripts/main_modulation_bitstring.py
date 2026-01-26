import serial
import sys
import time

# Check command line arguments
if len(sys.argv) < 2 or len(sys.argv) > 3:
    print("Usage: python main_modulation.py <on/off> [frequency/bitstring]")
    print("For 'on': python main_modulation.py on <0/1/bitstring>")
    print("  0 = 888 MHz frequency (always on)")
    print("  1 = 936 MHz frequency (always on)")
    print("  bitstring = sequence of 0s and 1s (transmitted with 0.5s delay)")
    print("For 'off': python main_modulation.py off")
    sys.exit(1)
    
command = sys.argv[1].lower()

if command not in ["on", "off"]:
    print("Invalid command. Use 'on' or 'off'.")
    sys.exit(1)

p_ser = serial.Serial(port="COM9", baudrate=57600, bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
                           stopbits=serial.STOPBITS_ONE, timeout=30, xonxoff=0, rtscts=0, dsrdtr=0)

if command == "off":
    conf_byte = "0000"
    p_ser.write(bytes.fromhex(conf_byte))
    read_data = p_ser.read(2)
    print(read_data, "OFF - Wave disabled")
    
elif command == "on":
    if len(sys.argv) != 3:
        print("Error: 'on' command requires a frequency/bitstring argument")
        print("Usage: python main_modulation.py on <0/1/bitstring>")
        print("  0 = 888 MHz frequency (always on)")
        print("  1 = 936 MHz frequency (always on)")
        print("  bitstring = sequence of 0s and 1s (transmitted with 0.5s delay)")
        sys.exit(1)
    
    bit_data = sys.argv[2]
    
    # Check if it's a valid bit string (only 0s and 1s)
    if not all(c in '01' for c in bit_data):
        print("Error: Input must contain only 0s and 1s")
        print("Usage: python main_modulation.py on <0/1/bitstring>")
        sys.exit(1)
    
    if len(bit_data) == 1:
        # Single bit - always on mode (original behavior)
        freq_select = int(bit_data)
        conf_byte = f"FFF{freq_select}"
        p_ser.write(bytes.fromhex(conf_byte))
        read_data = p_ser.read(2)
        
        freq_mhz = "888 MHz" if freq_select == 0 else "936 MHz"
        print(read_data, f"ON - Frequency: {freq_mhz} (freq_select = {freq_select}) - ALWAYS ON")
        
    else:
        # Multiple bits - transmit with delay
        print(f"Transmitting bit sequence: {bit_data}")
        print("Each bit transmitted for 0.5 seconds")
        
        for i, bit in enumerate(bit_data):
            freq_select = int(bit)
            conf_byte = f"FFF{freq_select}"
            p_ser.write(bytes.fromhex(conf_byte))
            read_data = p_ser.read(2)
            
            freq_mhz = "888 MHz" if freq_select == 0 else "936 MHz"
            print(f"Bit {i+1}/{len(bit_data)}: {bit} → {freq_mhz}")
            
            # Wait 0.5 seconds before next bit
            time.sleep(0.1)
                
        conf_byte = "0000"
        p_ser.write(bytes.fromhex(conf_byte))
        read_data = p_ser.read(2)
        print(read_data, "OFF - Wave disabled")
        print("Bit sequence transmission complete")

p_ser.close()