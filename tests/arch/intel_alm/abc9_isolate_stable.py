#!/usr/bin/env python3
"""Structural hash of a mapped port's combinational fanin.

Cell names and JSON bit numbers are ignored. A flip-flop leaf is the primary
input on DATAIN when that pin is a port, otherwise the RTL net name of Q.
"""

import hashlib
import json
import sys


def digest(node):
    """Short id for a DAG node. Nested tuples are already digests, so this stays linear."""
    h = hashlib.sha256()

    def feed(obj):
        if isinstance(obj, tuple):
            h.update(b"(")
            for item in obj:
                feed(item)
            h.update(b")")
        elif isinstance(obj, bytes):
            h.update(obj)
        else:
            h.update(str(obj).encode())
        h.update(b"\0")

    feed(node)
    return h.digest()


def load_top(path):
    with open(path) as f:
        design = json.load(f)
    modules = design["modules"]
    if "top" in modules:
        return modules["top"]
    if len(modules) != 1:
        raise SystemExit(f"{path}: expected module top, found {sorted(modules)}")
    return next(iter(modules.values()))


def structural_hash(mod, port_name):
    ports = mod.get("ports", {})
    cells = mod.get("cells", {})
    if port_name not in ports:
        raise SystemExit(f"missing port {port_name}")

    drivers = {}
    for cell_name, cell in cells.items():
        directions = cell.get("port_directions", {})
        for pname, bits in cell.get("connections", {}).items():
            if directions.get(pname) != "output":
                continue
            for index, bit in enumerate(bits):
                if isinstance(bit, str):
                    continue
                drivers.setdefault(bit, []).append((cell_name, pname, index))

    # Public net names survive autoname. Generated MISTRAL_* aliases do not
    # stay aligned when an unrelated cone changes size.
    bit_name = {}
    for name, info in mod.get("netnames", {}).items():
        if info.get("hide_name") or "MISTRAL" in name or name.startswith("$"):
            continue
        for index, bit in enumerate(info.get("bits", [])):
            if isinstance(bit, str):
                continue
            prev = bit_name.get(bit)
            if prev is None or (name, index) < prev:
                bit_name[bit] = (name, index)

    def port_leaf(bit):
        if isinstance(bit, str):
            return ("const", bit)
        found = []
        for pname, port in ports.items():
            if port.get("direction") != "input":
                continue
            bits = port.get("bits", [])
            if bit in bits:
                found.append((pname, bits.index(bit)))
        if len(found) == 1:
            return ("port", found[0][0], found[0][1])
        if not found:
            named = bit_name.get(bit)
            if named:
                return ("net", named[0], named[1])
            return ("undriven",)
        return ("ports", tuple(sorted(found)))

    def ff_leaf(cell):
        bits = cell.get("connections", {}).get("DATAIN", [])
        if len(bits) == 1:
            leaf = port_leaf(bits[0])
            if leaf[0] in ("const", "port", "ports"):
                return ("ff", leaf)
        qbits = cell.get("connections", {}).get("Q", [])
        if len(qbits) == 1 and not isinstance(qbits[0], str) and qbits[0] in bit_name:
            name, index = bit_name[qbits[0]]
            return ("ff", "net", name, index)
        return ("ff", "anon")

    memo = {}

    def hash_bit(bit, stack):
        if isinstance(bit, str):
            return ("const", bit)
        if bit in memo:
            return memo[bit]
        if bit in stack:
            return ("loop",)
        owners = drivers.get(bit, [])
        if not owners:
            value = digest(port_leaf(bit))
            memo[bit] = value
            return value
        if len(owners) != 1:
            return ("multi", tuple(sorted(owners)))
        cell_name, out_port, out_index = owners[0]
        cell = cells[cell_name]
        if cell.get("type") == "MISTRAL_FF":
            memo[bit] = digest(ff_leaf(cell))
            return memo[bit]
        stack.add(bit)
        inputs = []
        directions = cell.get("port_directions", {})
        for pname in sorted(directions):
            if directions[pname] != "input":
                continue
            for ibit in cell.get("connections", {}).get(pname, []):
                inputs.append(hash_bit(ibit, stack))
        stack.remove(bit)
        params = tuple(sorted((str(k), str(v)) for k, v in cell.get("parameters", {}).items()))
        value = (cell.get("type"), params, out_port, out_index, tuple(inputs))
        memo[bit] = digest(value)
        return memo[bit]

    bits = ports[port_name].get("bits", [])
    hashed = []
    for bit in bits:
        owners = [] if isinstance(bit, str) else drivers.get(bit, [])
        if len(owners) == 1 and cells[owners[0][0]].get("type") == "MISTRAL_FF":
            datain = cells[owners[0][0]].get("connections", {}).get("DATAIN", [])
            if len(datain) != 1:
                raise SystemExit(f"{port_name}: FF DATAIN is not a single bit")
            hashed.append(hash_bit(datain[0], set()))
        else:
            hashed.append(hash_bit(bit, set()))
    return hashed


def main():
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} old.json new.json")
    old = load_top(sys.argv[1])
    new = load_top(sys.argv[2])
    old_y = structural_hash(old, "y")
    new_y = structural_hash(new, "y")
    old_id = structural_hash(old, "idbit")
    new_id = structural_hash(new, "idbit")
    if old_id == new_id:
        raise SystemExit("idbit fanin matched; BUILD_ID did not change that cone")
    if old_y != new_y:
        raise SystemExit("payload port y fanin changed with BUILD_ID")
    print("payload stable; identity cone changed")


if __name__ == "__main__":
    main()
