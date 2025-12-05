#!/usr/bin/env python3
"""Add a patch source to a BuildStream element file."""

import sys
import yaml

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <bst-file> <patch-path>")
        sys.exit(1)

    bst_file = sys.argv[1]
    patch_path = sys.argv[2]

    with open(bst_file, 'r') as f:
        data = yaml.safe_load(f)

    patch_source = {
        'kind': 'patch',
        'path': patch_path,
        'strip-level': 1
    }

    if 'sources' in data:
        data['sources'].append(patch_source)
    else:
        data['sources'] = [patch_source]

    with open(bst_file, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)

    print(f"Added patch source '{patch_path}' to {bst_file}")

if __name__ == '__main__':
    main()
