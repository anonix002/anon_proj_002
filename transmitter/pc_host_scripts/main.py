import serial
import time
import sys

# Check command line arguments
if len(sys.argv) < 2 or len(sys.argv) > 3:
    print("Usage: python main.py <on/off> [frequency]")
    print("Frequencies: 12k, 50k, 120k, 12m, 55.386m, 120m, 360m")
    sys.exit(1)
    
command = sys.argv[1].lower()

if command not in ["on", "off"]:
    print("Invalid command. Use 'on' or 'off'.")
    sys.exit(1)

# Frequency mapping
frequency_map = {
    "12k"    : "00",
    "50k"    : "01",
    "120k"   : "02", 
    "12m"    : "03",
    "55.386m": "04",
    "120m"   : "05",
    "240m"   : "06",
    "360m"   : "07"
}

p_ser = serial.Serial(port="COM9", baudrate=57600, bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
                           stopbits=serial.STOPBITS_ONE, timeout=30, xonxoff=0, rtscts=0, dsrdtr=0)

if command == "off":
    conf_byte = "0000"
    p_ser.write(bytes.fromhex(conf_byte))
    read_data = p_ser.read(2)
    print(read_data, "OFF")
    
elif command == "on":
    if len(sys.argv) != 3:
        print("Error: 'on' command requires a frequency argument")
        print("Available frequencies: 12k, 50k, 120k, 12m, 55.386m, 120m, 360m")
        sys.exit(1)
    
    frequency = sys.argv[2].lower()
    
    if frequency not in frequency_map:
        print(f"Invalid frequency: {frequency}")
        print("Available frequencies: 12k, 50k, 120k, 12m, 55.386m, 120m, 360m")
        sys.exit(1)
    
    conf_byte = "FF" + frequency_map[frequency]
    p_ser.write(bytes.fromhex(conf_byte))
    read_data = p_ser.read(2)
    print(read_data, f"ON - {frequency.upper()}")

p_ser.close()