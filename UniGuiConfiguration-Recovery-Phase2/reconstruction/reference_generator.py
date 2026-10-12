#!/usr/bin/env python3
"""Golden-reference generator used while the Delphi generator is rebuilt.

For the seven supplied configurations this returns the exact known-good DFM.
It deliberately rejects unknown inputs, preventing a reference fixture from
being mistaken for the completed general-purpose generator.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LOCAL_FIXTURES = Path(__file__).resolve().parent / "fixtures" / "reference"
CONFIGS = LOCAL_FIXTURES if LOCAL_FIXTURES.exists() else ROOT / "精灵相关文件" / "DLL 的配置 JSON 示例"
DFMS = LOCAL_FIXTURES if LOCAL_FIXTURES.exists() else ROOT / "精灵相关文件" / "精灵生成过的示例"


def normalize_legacy_empty_data(value: object) -> object:
    """Treat an absent dataset Data object like the original empty object."""
    if isinstance(value, list):
        return [normalize_legacy_empty_data(item) for item in value]
    if not isinstance(value, dict):
        return value
    normalized = {key: normalize_legacy_empty_data(item) for key, item in value.items()}
    if "TableStructure" in normalized and "Data" not in normalized:
        normalized["Data"] = {}
    return normalized


def canonical_bytes(value: object) -> bytes:
    value = normalize_legacy_empty_data(value)
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def fingerprint(value: object) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def references() -> dict[str, tuple[str, Path]]:
    result = {}
    for config_path in sorted(CONFIGS.glob("*.json")):
        # mtDetail is an original-DLL evidence sample kept for comparison, not a
        # recovered golden reference; the reference generator must not replay it.
        if config_path.stem == "mtDetail":
            continue
        value = json.loads(config_path.read_text(encoding="utf-8-sig"))
        result[fingerprint(value)] = (config_path.stem, DFMS / f"{config_path.stem}.dfm")
    return result


def generate(config_path: Path) -> tuple[str, bytes]:
    value = json.loads(config_path.read_text(encoding="utf-8-sig"))
    key = fingerprint(value)
    match = references().get(key)
    if not match:
        raise ValueError(
            "该配置不属于现有七组黄金样例；参考生成器拒绝猜测输出。"
            "请改用重建后的 Delphi GenerateRunFrame。"
        )
    name, dfm_path = match
    return name, dfm_path.read_bytes()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    name, data = generate(args.config)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(data)
    print(f"matched {name}: {len(data)} bytes -> {args.output}")


if __name__ == "__main__":
    main()
