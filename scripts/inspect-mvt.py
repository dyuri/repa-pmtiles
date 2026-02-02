#!/usr/bin/env python3
"""
Inspect a Mapbox Vector Tile (MVT) file
Decodes the protobuf and shows layers, features, and geometry types
"""

import sys
import gzip
import struct

def read_varint(data, offset):
    """Read a protobuf varint from data at offset"""
    result = 0
    shift = 0
    while True:
        if offset >= len(data):
            return None, offset
        byte = data[offset]
        offset += 1
        result |= (byte & 0x7F) << shift
        if (byte & 0x80) == 0:
            return result, offset
        shift += 7

def zigzag_decode(n):
    """Decode zigzag-encoded signed integer"""
    return (n >> 1) ^ (-(n & 1))

def decode_geometry(geom_data):
    """Decode geometry commands"""
    geometries = []
    i = 0
    while i < len(geom_data):
        cmd_int = geom_data[i]
        i += 1
        cmd_id = cmd_int & 0x7
        cmd_count = cmd_int >> 3

        if cmd_id == 1:  # MoveTo
            geometries.append(f"MoveTo({cmd_count} points)")
        elif cmd_id == 2:  # LineTo
            geometries.append(f"LineTo({cmd_count} points)")
        elif cmd_id == 7:  # ClosePath
            geometries.append("ClosePath")

        # Skip the coordinate pairs
        if cmd_id in [1, 2]:
            i += cmd_count * 2

    return geometries

def inspect_mvt(filename):
    """Inspect an MVT file and print its contents"""
    try:
        # Try to read as gzip first
        with gzip.open(filename, 'rb') as f:
            data = f.read()
        print("✓ Decompressed gzip data")
    except:
        # If not gzip, read as raw
        with open(filename, 'rb') as f:
            data = f.read()
        print("✓ Reading raw MVT data")

    print(f"✓ Tile size: {len(data)} bytes\n")

    offset = 0
    layer_count = 0

    while offset < len(data):
        # Read field tag
        tag, offset = read_varint(data, offset)
        if tag is None:
            break

        field_num = tag >> 3
        wire_type = tag & 0x7

        if field_num == 3:  # Layer field
            layer_count += 1
            # Read length
            length, offset = read_varint(data, offset)
            layer_data = data[offset:offset+length]
            offset += length

            # Parse layer
            print(f"{'='*60}")
            print(f"LAYER #{layer_count}")
            print(f"{'='*60}")

            layer_info = parse_layer(layer_data)
            print(f"Name: {layer_info['name']}")
            print(f"Version: {layer_info.get('version', 'unknown')}")
            print(f"Extent: {layer_info.get('extent', 'unknown')}")
            print(f"Features: {layer_info['feature_count']}")

            if layer_info.get('geometry_types'):
                print(f"\nGeometry types found:")
                for geom_type, count in layer_info['geometry_types'].items():
                    geom_names = {0: "UNKNOWN", 1: "POINT", 2: "LINESTRING", 3: "POLYGON", 4: "UNKNOWN_TYPE_4"}
                    print(f"  - {geom_names.get(geom_type, f'TYPE_{geom_type}')}: {count} features")

            if layer_info.get('keys'):
                print(f"\nAttribute keys: {', '.join(layer_info['keys'][:10])}")
                if len(layer_info['keys']) > 10:
                    print(f"  ... and {len(layer_info['keys']) - 10} more")

            print()
        else:
            # Skip other fields
            if wire_type == 0:  # Varint
                _, offset = read_varint(data, offset)
            elif wire_type == 2:  # Length-delimited
                length, offset = read_varint(data, offset)
                offset += length

    print(f"\n{'='*60}")
    print(f"Total layers: {layer_count}")
    print(f"{'='*60}")

def parse_layer(data):
    """Parse a layer and extract basic info"""
    info = {
        'name': 'unknown',
        'feature_count': 0,
        'keys': [],
        'geometry_types': {}
    }

    offset = 0
    while offset < len(data):
        tag, offset = read_varint(data, offset)
        if tag is None:
            break

        field_num = tag >> 3
        wire_type = tag & 0x7

        if field_num == 1:  # Name
            length, offset = read_varint(data, offset)
            info['name'] = data[offset:offset+length].decode('utf-8', errors='ignore')
            offset += length
        elif field_num == 2:  # Feature
            info['feature_count'] += 1
            length, offset = read_varint(data, offset)
            feature_data = data[offset:offset+length]
            offset += length
            # Parse feature to get geometry type
            geom_type = get_feature_geometry_type(feature_data)
            info['geometry_types'][geom_type] = info['geometry_types'].get(geom_type, 0) + 1
        elif field_num == 3:  # Keys
            length, offset = read_varint(data, offset)
            key = data[offset:offset+length].decode('utf-8', errors='ignore')
            info['keys'].append(key)
            offset += length
        elif field_num == 4:  # Values (skip)
            length, offset = read_varint(data, offset)
            offset += length
        elif field_num == 5:  # Extent
            extent, offset = read_varint(data, offset)
            info['extent'] = extent
        elif field_num == 15:  # Version
            version, offset = read_varint(data, offset)
            info['version'] = version
        else:
            # Skip unknown fields
            if wire_type == 0:
                _, offset = read_varint(data, offset)
            elif wire_type == 2:
                length, offset = read_varint(data, offset)
                offset += length

    return info

def get_feature_geometry_type(data):
    """Extract geometry type from a feature"""
    offset = 0
    while offset < len(data):
        tag, offset = read_varint(data, offset)
        if tag is None:
            break

        field_num = tag >> 3
        wire_type = tag & 0x7

        if field_num == 3:  # Type field
            geom_type, offset = read_varint(data, offset)
            return geom_type
        elif wire_type == 0:
            _, offset = read_varint(data, offset)
        elif wire_type == 2:
            length, offset = read_varint(data, offset)
            offset += length

    return 0  # Unknown

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: inspect-mvt.py <mvt-file>")
        sys.exit(1)

    inspect_mvt(sys.argv[1])
