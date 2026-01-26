import serial
import time
import sys

# Check command line arguments
if len(sys.argv) < 2 or len(sys.argv) > 3:
    print("Usage: python main.py <on/off> [value]")
    print("For 'on': python main.py on <integer_value> or python main.py on bypass")
    print("For 'off': python main.py off")
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
    print(read_data, "OFF")
    
elif command == "on":
    if len(sys.argv) != 3:
        print("Error: 'on' command requires an argument")
        print("Usage: python main.py on <integer_value> or python main.py on bypass")
        sys.exit(1)
    
    argument = sys.argv[2].lower()
    
    # Check for bypass command
    if argument == "bypass":
        conf_byte = "FFFF"
        p_ser.write(bytes.fromhex(conf_byte))
        read_data = p_ser.read(2)
        print(read_data, "ON - BYPASS (0xFFFF)")
        print("Output frequency: 936 MHz, 648 MHz, Or 600 MHz")
    else:
        # Try to parse as integer
        try:
            value = int(sys.argv[2])
            
            # Convert integer to 4-digit hex string (16-bit value)
            if value < 0 or value > 65535:
                print("Error: Value must be between 0 and 65535 (16-bit range)")
                sys.exit(1)
                
            conf_byte = f"{value:04X}"
            p_ser.write(bytes.fromhex(conf_byte))
            read_data = p_ser.read(2)
            print(read_data, f"ON - Value: {value} (0x{conf_byte}) - divide frequency by {2*(value+1)}")
            print(f"Output frequency for 936 MHz: {936 / (2 * (value + 1))} MHz")
            print(f"Output frequency for 648 MHz: {648 / (2 * (value + 1))} MHz")
            print(f"Output frequency for 600 MHz: {600 / (2 * (value + 1))} MHz")
        except ValueError:
            print("Error: Invalid argument. Use an integer value or 'bypass'")
            print("Usage: python main.py on <integer_value> or python main.py on bypass")
            sys.exit(1)

p_ser.close()