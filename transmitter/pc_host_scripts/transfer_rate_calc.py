import sys
import argparse

def calculate_transfer_rate(symbol_time, clock_freq_mhz=12):
    """
    Calculate transfer rate in kbps given symbol time in clock cycles
    
    Args:
        symbol_time: Number of clock cycles per symbol/bit
        clock_freq_mhz: Clock frequency in MHz (default 12 MHz)
    
    Returns:
        Transfer rate in kbps
    """
    # Convert clock frequency to Hz
    clock_freq_hz = clock_freq_mhz * 1_000_000
    
    # Calculate time per symbol in seconds
    time_per_symbol = symbol_time / clock_freq_hz
    
    # Calculate symbols per second
    symbols_per_second = 1 / time_per_symbol
    
    # Convert to kbps (assuming 1 bit per symbol)
    transfer_rate_kbps = symbols_per_second / 1000
    
    return transfer_rate_kbps

def main():
    parser = argparse.ArgumentParser(description='Calculate FSK transfer rate from symbol time')
    parser.add_argument('symbol_time', type=int, help='Symbol time in clock cycles')
    parser.add_argument('-f', '--freq', type=float, default=12.0, 
                       help='Clock frequency in MHz (default: 12.0)')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Show detailed output')
    
    args = parser.parse_args()
    
    try:
        transfer_rate = calculate_transfer_rate(args.symbol_time, args.freq)
        
        if args.verbose:
            print(f"Symbol time: {args.symbol_time} clock cycles")
            print(f"Clock frequency: {args.freq} MHz")
            print(f"Transfer rate: {transfer_rate:.3f} kbps")
            print(f"Transfer rate: {transfer_rate*1000:.1f} bps")
            print(f"Time per bit: {(args.symbol_time / (args.freq * 1_000_000)) * 1000:.3f} ms")
        else:
            print(f"{transfer_rate:.3f}")
            
    except ZeroDivisionError:
        print("Error: Symbol time cannot be zero")
        sys.exit(1)

if __name__ == "__main__":
    main()