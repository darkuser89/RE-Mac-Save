#!/usr/bin/env python3
"""Link German RE2 reward names to saved IDs using the installed Mac catalogs."""

import argparse
import json
import struct
from pathlib import Path

from extract_re2_record_details import archive_bytes, german_messages


ROOT = "natives/mac/sectionroot"
MESSAGE_PATH = f"{ROOT}/message/mes_sys/mes_sys_reward.msg.23"
FIGURE_PATH = f"{ROOT}/userdata/record/figureorderuserdata.user.3"
ART_PATH = f"{ROOT}/userdata/record/conceptartorderuserdata.user.3"


def catalog_values(data: bytes, header_values: tuple[int, int]) -> list[int]:
    if data[:4] != b"USR\0" or data[48:52] != b"RSZ\0":
        raise ValueError("Unexpected RE2 reward catalog header")
    if (struct.unpack_from("<I", data, 60)[0],
            struct.unpack_from("<I", data, 96)[0]) != header_values:
        raise ValueError("Unexpected RE2 reward catalog layout")
    start = 48 + struct.unpack_from("<Q", data, 80)[0]
    if not (0 < start <= len(data)) or (len(data) - start) % 4:
        raise ValueError("Invalid RE2 reward catalog data section")
    return list(struct.unpack_from(f"<{(len(data) - start) // 4}I", data, start))


def reward_details(
    messages: dict[str, tuple[bytes, str]],
    figure_data: bytes,
    art_data: bytes,
) -> dict[str, dict[str, str]]:
    figure = catalog_values(figure_data, (80, 79))
    art = catalog_values(art_data, (2, 1))
    if len(figure) != 157 or set(figure[:78]) != set(range(55, 133)) or \
       figure[78] != 78 or figure[79:] != list(range(1, 79)):
        raise ValueError("Unexpected RE2 figure-to-reward mapping")
    if len(art) != 31 or art[0] != 30 or set(art[1:]) != set(range(25, 55)):
        raise ValueError("Unexpected RE2 concept-art-to-reward mapping")

    result: dict[str, dict[str, str]] = {}
    for index, reward_id in enumerate(art[1:]):
        name = f"Mes_Sys_Reward_CArt{index:02d}"
        if name not in messages:
            raise ValueError("Missing concept art message")
        result[str(reward_id)] = {"name": messages[name][1], "kind": "Konzeptgrafik"}
    for index, reward_id in enumerate(figure[:78]):
        name = f"Mes_Sys_Reward_figure{index:02d}"
        if name in messages:
            result[str(reward_id)] = {"name": messages[name][1], "kind": "Figur"}

    if len(result) != 98 or result["55"]["name"] != "Leon (Freizeit)" or \
       result["37"]["name"] != "Raccoon City A" or \
       result[str(figure[77])]["name"] != "Robert und Emma Kendo":
        raise ValueError("Reward text and native ID cross-check failed")
    return {str(number): result[str(number)] for number in sorted(map(int, result))}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, help="Installed Resident Evil 2.app")
    parser.add_argument("output", type=Path, help="Output JSON inside the project")
    args = parser.parse_args()
    messages = german_messages(
        archive_bytes(args.app, MESSAGE_PATH), r"Mes_Sys_Reward_.*", 115
    )
    details = reward_details(
        messages, archive_bytes(args.app, FIGURE_PATH), archive_bytes(args.app, ART_PATH)
    )
    args.output.write_text(json.dumps(details, ensure_ascii=False, indent=2) + "\n")
    print(f"Extracted {len(details)} named RE2 reward IDs")
