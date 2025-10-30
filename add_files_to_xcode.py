#!/usr/bin/env python3
"""
Simple script to add Activity.swift and ActivityMigration.swift to Xcode project
by directly manipulating the project.pbxproj file
"""

import re
import uuid
import sys

def generate_uuid():
    """Generate a 24-character uppercase hex string like Xcode uses"""
    return ''.join(f'{uuid.uuid4().hex}'.upper())[:24]

def add_files_to_pbxproj(pbxproj_path, files_to_add):
    """Add Swift files to the Xcode project"""

    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Generate UUIDs for new files
    file_refs = {}
    build_refs = {}

    for filename in files_to_add:
        file_refs[filename] = generate_uuid()
        build_refs[filename] = generate_uuid()

    # Find the PBXFileReference section
    file_ref_section_match = re.search(
        r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)',
        content,
        re.DOTALL
    )

    if not file_ref_section_match:
        print("Error: Could not find PBXFileReference section")
        return False

    # Find the last file reference before the End marker
    file_ref_section = file_ref_section_match.group(1)

    # Add new file references
    new_file_refs = []
    for filename in files_to_add:
        new_ref = f'\t\t{file_refs[filename]} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};\n'
        new_file_refs.append(new_ref)

    # Insert before the End marker
    file_ref_insert_pos = file_ref_section_match.end() - len('/* End PBXFileReference section */\n')
    content = content[:file_ref_insert_pos] + ''.join(new_file_refs) + content[file_ref_insert_pos:]

    # Find the Models group in PBXGroup section
    models_group_match = re.search(
        r'([A-F0-9]{24}) /\* Models \*/ = \{[^}]+children = \(([^)]+)\);',
        content,
        re.DOTALL
    )

    if not models_group_match:
        print("Error: Could not find Models group")
        return False

    models_group_id = models_group_match.group(1)
    children_section = models_group_match.group(2)

    # Add new file references to Models group
    new_children = []
    for filename in files_to_add:
        new_child = f'\t\t\t\t{file_refs[filename]} /* {filename} */,\n'
        new_children.append(new_child)

    # Insert after the last child
    children_end_pos = models_group_match.end(2)
    content = content[:children_end_pos] + ''.join(new_children) + content[children_end_pos:]

    # Find the PBXSourcesBuildPhase section
    sources_build_phase_match = re.search(
        r'([A-F0-9]{24}) /\* Sources \*/ = \{[^}]+files = \(([^)]+)\);',
        content,
        re.DOTALL
    )

    if not sources_build_phase_match:
        print("Error: Could not find Sources build phase")
        return False

    # Add new build file entries
    new_build_files = []
    for filename in files_to_add:
        new_build = f'\t\t\t\t{build_refs[filename]} /* {filename} in Sources */,\n'
        new_build_files.append(new_build)

    files_end_pos = sources_build_phase_match.end(2)
    content = content[:files_end_pos] + ''.join(new_build_files) + content[files_end_pos:]

    # Find the PBXBuildFile section
    build_file_section_match = re.search(
        r'(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)',
        content,
        re.DOTALL
    )

    if not build_file_section_match:
        print("Error: Could not find PBXBuildFile section")
        return False

    # Add new PBXBuildFile entries
    new_pbx_build_files = []
    for filename in files_to_add:
        new_pbx_build = f'\t\t{build_refs[filename]} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[filename]} /* {filename} */; }};\n'
        new_pbx_build_files.append(new_pbx_build)

    build_file_insert_pos = build_file_section_match.end() - len('/* End PBXBuildFile section */\n')
    content = content[:build_file_insert_pos] + ''.join(new_pbx_build_files) + content[build_file_insert_pos:]

    # Write back
    with open(pbxproj_path, 'w') as f:
        f.write(content)

    print(f"Successfully added {len(files_to_add)} files to Xcode project")
    return True

if __name__ == "__main__":
    pbxproj_path = "WigiAI.xcodeproj/project.pbxproj"
    files_to_add = ["Activity.swift", "ActivityMigration.swift"]

    if add_files_to_pbxproj(pbxproj_path, files_to_add):
        print("✅ Files added successfully!")
        sys.exit(0)
    else:
        print("❌ Failed to add files")
        sys.exit(1)
