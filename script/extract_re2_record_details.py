#!/usr/bin/env python3
"""Read RE2 record titles, objectives and catalog values from the installed Mac game."""

import argparse
import json
import re
import struct
import subprocess
from pathlib import Path


MESSAGE_PATH = "natives/mac/sectionroot/message/mes_sys/mes_sys_bonus.msg.23"
RECORD_PATH = "natives/mac/sectionroot/userdata/record/recordlistuserdata.user.3"
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


def archive_bytes(app: Path, path: str) -> bytes:
    target = (
        murmur(path.lower().encode("utf-16le")),
        murmur(path.upper().encode("utf-16le")),
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
                if flags not in (2, 4098) or compressed > 10_000_000 or real > 20_000_000:
                    raise ValueError("Unexpected archive entry layout")
                file.seek(offset)
                blob = file.read(compressed)
                if len(blob) != compressed:
                    raise ValueError("Truncated archive entry")
                result = subprocess.run(
                    ["zstd", "-d", "-q", "-c"], input=blob, capture_output=True, check=True
                ).stdout
                if len(result) != real:
                    raise ValueError("Wrong decompressed archive entry size")
                matches.append(result)
    if len(matches) != 1:
        raise ValueError(f"Expected exactly one Mac RE2 entry for {path}, found {len(matches)}")
    return matches[0]


def german_messages(data: bytes) -> dict[str, tuple[bytes, str]]:
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
        name = string_at(name_offset)
        if not re.fullmatch(r"Mes_Sys_Bouns_Record\d{2}(Guide)?", name):
            continue
        text_offset = struct.unpack_from(f"<{languages}Q", data, offset + 40)[german_index]
        value = re.sub(r"\s+", " ", string_at(text_offset)).strip()
        if not value or name in names:
            raise ValueError("Invalid or duplicate record message")
        names[name] = (data[offset:offset + 16], value)
    if len(names) != 178:
        raise ValueError("Unexpected RE2 record message coverage")
    return names


def record_details(messages: dict[str, tuple[bytes, str]], catalog: bytes) -> dict[str, dict[str, object]]:
    if catalog[:4] != b"USR\0" or catalog[48:52] != b"RSZ\0":
        raise ValueError("Unexpected RE2 record catalog header")
    if struct.unpack_from("<I", catalog, 60)[0] != 93:
        raise ValueError("Unexpected RE2 record instance count")
    data_start = 48 + struct.unpack_from("<Q", catalog, 80)[0]
    if not (data_start < len(catalog)):
        raise ValueError("Invalid record catalog data offset")

    result = {}
    for name, (guid, title) in messages.items():
        match = re.fullmatch(r"Mes_Sys_Bouns_Record(\d{2})", name)
        if not match:
            continue
        where = catalog.find(guid, data_start)
        if where < 0:
            continue  # Record00 and Record90 have text but no catalog entry.
        if catalog.find(guid, where + 1) >= 0 or where < data_start + 8 or where + 76 > len(catalog):
            raise ValueError("Ambiguous record GUID in catalog")
        record_id, reserved = struct.unpack_from("<II", catalog, where - 8)
        guide = messages.get(name + "Guide")
        if not (0 <= record_id <= 90 and record_id + 1 == int(match.group(1)) and
                reserved == 0 and guide and catalog[where + 16:where + 32] == guide[0]):
            raise ValueError("Record ID or guide GUID mismatch")
        catalog_value = struct.unpack_from("<I", catalog, where + 72)[0]
        objective = guide[1].replace("{0}", str(catalog_value))
        if not objective or "{0}" in objective or str(record_id) in result:
            raise ValueError("Invalid record objective")
        result[str(record_id)] = {"title": title, "objective": objective, "catalogValue": catalog_value}
    if len(result) != 87 or set(range(91)) - {int(key) for key in result} != {86, 87, 89, 90}:
        raise ValueError("Unexpected RE2 record catalog coverage")
    if result["58"]["title"] != "Schatzjäger" or \
       result["58"]["objective"] != "Finden Sie mithilfe der Fotohinweise zwei versteckte Objekte." or \
       result["19"]["catalogValue"] != 10 or result["75"]["catalogValue"] != 14000:
        raise ValueError("Record catalog cross-check failed")
    return {str(number): result[str(number)] for number in sorted(map(int, result))}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Installed Resident Evil 2.app")
    parser.add_argument("output", type=Path, help="Output JSON inside the project")
    args = parser.parse_args()
    messages = german_messages(archive_bytes(args.app, MESSAGE_PATH))
    details = record_details(messages, archive_bytes(args.app, RECORD_PATH))
    args.output.write_text(json.dumps(details, ensure_ascii=False, indent=2) + "\n")
    print(f"Extracted {len(details)} German RE2 record titles, objectives and catalog values")
