#!/usr/bin/env python3
"""Read German RE2 record titles from the installed Mac game's message archive."""

import argparse
import json
import re
import struct
import subprocess
from pathlib import Path


MESSAGE_PATH = "natives/mac/sectionroot/message/mes_sys/mes_sys_bonus.msg.23"
MESSAGE_KEY = bytes.fromhex("cfcefbf8ec0a336693a91d9350395f09")


def murmur(data: bytes) -> int:
    value = 0xFFFFFFFF
    for pos in range(0, len(data) // 4 * 4, 4):
        block = int.from_bytes(data[pos:pos + 4], "little")
        block = block * 0xCC9E2D51 & 0xFFFFFFFF
        block = ((block << 15) | (block >> 17)) & 0xFFFFFFFF
        block = block * 0x1B873593 & 0xFFFFFFFF
        value ^= block
        value = ((value << 13) | (value >> 19)) & 0xFFFFFFFF
        value = (value * 5 + 0xE6546B64) & 0xFFFFFFFF
    tail = data[len(data) // 4 * 4:]
    if tail:
        block = int.from_bytes(tail, "little")
        block = block * 0xCC9E2D51 & 0xFFFFFFFF
        block = ((block << 15) | (block >> 17)) & 0xFFFFFFFF
        block = block * 0x1B873593 & 0xFFFFFFFF
        value ^= block
    value ^= len(data)
    value ^= value >> 16
    value = value * 0x85EBCA6B & 0xFFFFFFFF
    value ^= value >> 13
    value = value * 0xC2B2AE35 & 0xFFFFFFFF
    value ^= value >> 16
    return value


def message_bytes(app: Path) -> bytes:
    target = (
        murmur(MESSAGE_PATH.lower().encode("utf-16le")),
        murmur(MESSAGE_PATH.upper().encode("utf-16le")),
    )
    resources = app / "Contents/Resources"
    matches = []
    for pak in sorted(resources.glob("re_chunk_*.pak")):
        with pak.open("rb") as file:
            head = file.read(16)
            if head[:4] != b"KPKA":
                raise ValueError(f"Invalid archive header: {pak}")
            count = struct.unpack_from("<I", head, 8)[0]
            table = file.read(count * 48)
            if len(table) != count * 48:
                raise ValueError(f"Truncated archive table: {pak}")
            for index in range(count):
                low, high, offset, compressed, real, flags, _ = struct.unpack_from(
                    "<IIQQQQQ", table, index * 48
                )
                if (low, high) != target:
                    continue
                if flags & 2 == 0 or compressed > 10_000_000 or real > 20_000_000:
                    raise ValueError("Unexpected message entry layout")
                file.seek(offset)
                blob = file.read(compressed)
                if len(blob) != compressed:
                    raise ValueError("Truncated message entry")
                result = subprocess.run(
                    ["zstd", "-d", "-q", "-c"], input=blob, capture_output=True, check=True
                ).stdout
                if len(result) != real:
                    raise ValueError("Wrong decompressed message size")
                matches.append(result)
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one Mac RE2 bonus message, found {len(matches)}")
    return matches[0]


def german_titles(data: bytes) -> dict[str, str]:
    version, magic = struct.unpack_from("<I4s", data)
    if (version, magic) != (23, b"GMSG"):
        raise ValueError("Unexpected RE2 message version")
    count, _, languages = struct.unpack_from("<III", data, 16)
    pool_offset = struct.unpack_from("<Q", data, 32)[0]
    language_offset = struct.unpack_from("<Q", data, 48)[0]
    if not (72 + count * 8 <= pool_offset < len(data)):
        raise ValueError("Invalid message offsets")
    language_ids = struct.unpack_from(f"<{languages}I", data, language_offset)
    if language_ids.count(4) != 1:
        raise ValueError("German language is not unique")
    german_index = language_ids.index(4)
    encrypted = data[pool_offset:]
    plain = bytearray(len(encrypted))
    previous = 0
    for index, byte in enumerate(encrypted):
        plain[index] = byte ^ previous ^ MESSAGE_KEY[index % len(MESSAGE_KEY)]
        previous = byte

    def string_at(offset: int) -> str:
        if offset == 0:
            return ""
        if offset >= pool_offset:
            chunk = plain[offset - pool_offset:]
        elif offset < len(data):
            chunk = data[offset:]
        else:
            raise ValueError("Invalid text offset")
        end = next(
            (index for index in range(0, len(chunk) - 1, 2)
             if chunk[index] == 0 and chunk[index + 1] == 0),
            None,
        )
        if end is None:
            raise ValueError("Unterminated message text")
        return bytes(chunk[:end]).decode("utf-16le")

    offsets = struct.unpack_from(f"<{count}Q", data, 72)
    names = {}
    for offset in offsets:
        if offset + 40 + languages * 8 > pool_offset:
            raise ValueError("Invalid message row")
        name_offset = struct.unpack_from("<Q", data, offset + 24)[0]
        match = re.fullmatch(r"Mes_Sys_Bouns_Record(\d{2})", string_at(name_offset))
        if not match:
            continue
        number = int(match.group(1))
        text_offset = struct.unpack_from(f"<{languages}Q", data, offset + 40)[german_index]
        title = string_at(text_offset).strip()
        if not title or number > 90 or number in names:
            raise ValueError("Invalid or duplicate record title")
        names[number] = title
    if len(names) != 89 or set(range(91)) - names.keys() != {87, 88}:
        raise ValueError("Unexpected RE2 record title coverage")
    if names[59] != "Schatzjäger":
        raise ValueError("Record 59 does not match the game's treasure counter")
    return {str(number): names[number] for number in sorted(names)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Installed Resident Evil 2.app")
    parser.add_argument("output", type=Path, help="Output JSON inside the project")
    args = parser.parse_args()
    titles = german_titles(message_bytes(args.app))
    args.output.write_text(json.dumps(titles, ensure_ascii=False, indent=2) + "\n")
    print(f"Extracted {len(titles)} German RE2 record titles")
