#!/usr/bin/env python3
"""
Simple syntax and structure checker for RISC-V CPU verification
No simulator required - just basic file and syntax validation
"""

import os
import sys
import re
from pathlib import Path

def check_file_exists(filepath):
    """Check if file exists and is readable"""
    if os.path.exists(filepath):
        print(f"✅ Found: {filepath}")
        return True
    else:
        print(f"❌ Missing: {filepath}")
        return False

def check_systemverilog_syntax(filepath):
    """Basic SystemVerilog syntax checking"""
    if not os.path.exists(filepath):
        return False
    
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Check for basic SystemVerilog constructs
        issues = []
        
        # Check for module declaration
        if 'module ' not in content and 'interface ' not in content and 'package ' not in content:
            issues.append("No module/interface/package declaration found")
        
        # Check for unmatched begin/end
        begin_count = len(re.findall(r'\bbegin\b', content))
        end_count = len(re.findall(r'\bend\b', content))
        if begin_count != end_count:
            issues.append(f"Unmatched begin/end: {begin_count} begins, {end_count} ends")
        
        # Check for basic syntax issues
        if '`include' in content:
            includes = re.findall(r'`include\s+"([^"]+)"', content)
            for inc in includes:
                if not inc.endswith('.svh') and not inc.endswith('.sv'):
                    issues.append(f"Unusual include file: {inc}")
        
        if issues:
            print(f"⚠️  {filepath}: {', '.join(issues)}")
            return False
        else:
            print(f"✅ Syntax OK: {filepath}")
            return True
            
    except Exception as e:
        print(f"❌ Error reading {filepath}: {e}")
        return False

def main():
    print("🔍 RISC-V CPU Verification Environment Check")
    print("=" * 50)
    
    # Base directory
    base_dir = Path(__file__).parent
    uvm_dir = base_dir / "uvm"
    rtl_dir = base_dir.parent / "rtl"
    
    print(f"Checking from: {base_dir}")
    print()
    
    # Files to check
    files_to_check = [
        # RTL files
        rtl_dir / "cache" / "l1_dcache.sv",
        rtl_dir / "cache" / "l2_cache.sv", 
        rtl_dir / "cache" / "l3_cache.sv",
        rtl_dir / "mmu" / "tlb.sv",
        rtl_dir / "mmu" / "mmu.sv",
        
        # UVM files
        uvm_dir / "packages" / "cache_pkg.sv",
        uvm_dir / "packages" / "mmu_pkg.sv",
        uvm_dir / "interfaces" / "cache_if.sv",
        uvm_dir / "interfaces" / "mmu_if.sv",
        uvm_dir / "testbench" / "cache_tb.sv",
        uvm_dir / "testbench" / "mmu_tb.sv",
        uvm_dir / "Makefile",
        uvm_dir / "README.md"
    ]
    
    print("📁 File Existence Check:")
    all_files_exist = True
    for filepath in files_to_check:
        if not check_file_exists(filepath):
            all_files_exist = False
    
    print()
    print("📝 SystemVerilog Syntax Check:")
    syntax_ok = True
    for filepath in files_to_check:
        if filepath.suffix == '.sv':
            if not check_systemverilog_syntax(filepath):
                syntax_ok = False
    
    print()
    print("📊 Summary:")
    if all_files_exist:
        print("✅ All required files exist")
    else:
        print("❌ Some files are missing")
    
    if syntax_ok:
        print("✅ Basic syntax checks passed")
    else:
        print("⚠️  Some syntax issues found")
    
    print()
    print("🚀 Next Steps:")
    print("1. Install Verilator: brew install verilator")
    print("2. Or install Icarus Verilog: brew install icarus-verilog")
    print("3. Run: make compile_cache")
    print("4. Run: make compile_mmu")
    
    return 0 if (all_files_exist and syntax_ok) else 1

if __name__ == "__main__":
    sys.exit(main())