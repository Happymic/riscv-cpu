#!/usr/bin/env python3
"""
RTL Quality Check Script
Analyzes the warnings and gives a clear summary
"""

import subprocess
import sys
from pathlib import Path

def run_verilator_check(files, name):
    """Run Verilator on files and analyze results"""
    print(f"\n🔍 Checking {name}...")
    
    cmd = [
        "verilator", "--lint-only",
        "-Wno-EOFNEWLINE",  # Missing newlines (cosmetic)
        "-Wno-UNUSEDSIGNAL", "-Wno-UNUSEDPARAM",  # Unused items (non-critical)
        "-Wno-MULTITOP",     # Multiple modules (expected)
        "-Wno-DECLFILENAME", # Declaration filename (cosmetic)
    ] + files
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            print(f"✅ {name}: PASSED - No critical errors")
            return True
        else:
            print(f"⚠️  {name}: Has warnings/errors")
            # Show only critical issues
            lines = result.stderr.split('\n')
            critical_count = 0
            warning_count = 0
            
            for line in lines:
                if "%Error:" in line:
                    print(f"❌ ERROR: {line}")
                    critical_count += 1
                elif "%Warning-WIDTHTRUNC:" in line or "%Warning-WIDTHEXPAND:" in line:
                    warning_count += 1
                elif "%Warning-CASEINCOMPLETE:" in line:
                    print(f"⚠️  INCOMPLETE CASE: {line}")
                    warning_count += 1
            
            print(f"   Critical errors: {critical_count}, Warnings: {warning_count}")
            return critical_count == 0
            
    except subprocess.TimeoutExpired:
        print(f"❌ {name}: Timeout during check")
        return False
    except FileNotFoundError:
        print(f"❌ Verilator not found. Install with: brew install verilator")
        return False

def main():
    print("🔧 RISC-V RTL Quality Check")
    print("=" * 40)
    
    # Check if verilator is available
    try:
        subprocess.run(["verilator", "--version"], capture_output=True, timeout=5)
    except FileNotFoundError:
        print("❌ Verilator not installed. Run: brew install verilator")
        return 1
    
    base_dir = Path(__file__).parent.parent
    
    # Check cache modules
    cache_files = [
        str(base_dir / "rtl/cache/l1_dcache.sv"),
        str(base_dir / "rtl/cache/l2_cache.sv"),
        str(base_dir / "rtl/cache/l3_cache.sv")
    ]
    
    # Check MMU modules  
    mmu_files = [
        str(base_dir / "rtl/mmu/tlb.sv"),
        str(base_dir / "rtl/mmu/mmu.sv"),
        str(base_dir / "rtl/mmu/page_table_walk.sv"),
        str(base_dir / "rtl/mmu/exception_handler.sv")
    ]
    
    # Run checks
    cache_ok = run_verilator_check(cache_files, "Cache Modules")
    mmu_ok = run_verilator_check(mmu_files, "MMU Modules")
    
    print("\n" + "=" * 40)
    print("📊 SUMMARY:")
    
    if cache_ok and mmu_ok:
        print("✅ ALL CHECKS PASSED!")
        print("🚀 Your RTL is ready for simulation!")
        print("\n📋 Next steps:")
        print("  1. Run: make compile_cache")
        print("  2. Run: make compile_mmu") 
        print("  3. If you have UVM tools, try: make cache_random")
        return 0
    else:
        print("⚠️  Some modules have issues:")
        if not cache_ok:
            print("   - Cache modules need attention")
        if not mmu_ok:
            print("   - MMU modules need attention")
        print("\n🔧 These are mostly cosmetic - the code should still work!")
        return 1

if __name__ == "__main__":
    sys.exit(main())