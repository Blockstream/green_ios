#!/usr/bin/env python3
import os
import re
import sys
from typing import Set, Dict

def extract_string_ids_from_code(root_dir: str) -> Set[str]:
    """Extract all localized string IDs from Swift source files."""
    string_ids = set()
    swift_files_pattern = re.compile(r'.*\.swift$')
    localization_pattern = re.compile(r'["\'](.*?)["\']\.localized')
    format_pattern = re.compile(r'["\']([^"\']*?)["\']\.localizedFormat')
    
    for root, _, files in os.walk(root_dir):
        for file in files:
            if swift_files_pattern.match(file):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    # Find .localized usage
                    matches = localization_pattern.findall(content)
                    string_ids.update(matches)
                    # Find .localizedFormat usage
                    matches = format_pattern.findall(content)
                    string_ids.update(matches)
    
    return string_ids

def extract_string_ids_from_strings_file(strings_file: str) -> Set[str]:
    """Extract all string IDs from a .strings file."""
    string_ids = set()
    # Match "string_id" = "translation";
    pattern = re.compile(r'^"(.*?)"\s*=\s*".*?";$')
    
    with open(strings_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            match = pattern.match(line)
            if match:
                string_ids.add(match.group(1))
    
    return string_ids

def main():
    # Get source directory (assuming script is in tools/)
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    # Extract string IDs from code
    used_ids = extract_string_ids_from_code(os.path.join(root_dir, 'gaios'))
    
    # Extract string IDs from English strings file (source of truth)
    en_strings_file = os.path.join(root_dir, 'gaios', 'en.lproj', 'Localizable.strings')
    defined_ids = extract_string_ids_from_strings_file(en_strings_file)
    
    # Find deprecated IDs (in strings file but not in code)
    deprecated_ids = defined_ids - used_ids
    
    # Find missing IDs (in code but not in strings file)
    missing_ids = used_ids - defined_ids
    
    # Separate missing IDs from strings that need localization
    actual_missing_ids = {id for id in missing_ids if id.startswith('id_')}
    needs_localization = missing_ids - actual_missing_ids
    
    has_issues = False
    
    print("\n" + "="*80)
    print("LOCALIZATION CHECK RESULTS")
    print("="*80)
    
    if deprecated_ids:
        print("\n\n" + "="*50)
        print("\n📝 DEPRECATED IDs (in strings file but not used in code):")
        print("=" * 50 + "\n\n")
        for id in sorted(deprecated_ids):
            print(f"  - {id}")
    
    if actual_missing_ids:
        has_issues = True
        print("\n\n" + "="*50)
        print("\n❌ MISSING IDs (used in code but missing from Localizable.strings):")
        print("=" * 50 + "\n\n")
        for id in sorted(actual_missing_ids):
            print(f"  - {id}")
    
    if needs_localization:
        print("\n\n" + "="*50)
        print("\n⚠️  STRINGS THAT NEED LOCALIZATION (hardcoded strings using .localized):")
        print("=" * 50 + "\n\n")
        for text in sorted(needs_localization):
            print(f"  - {text}")
            
    print("\n" + "="*80)
    
    if has_issues:
        # Exit with error only if there are actual missing IDs
        sys.exit(1)
    
    print("✅ No critical localization issues found!")
    sys.exit(0)

if __name__ == '__main__':
    main()
