#!/usr/bin/env python3
"""Build or verify this game's Google Play Games achievements import."""
import argparse, csv, hashlib, io, json, pathlib, re, struct, zipfile, zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "marketing/play-games-import"
SPEC = json.loads((OUT / "import-settings.json").read_text(encoding="utf-8"))
CATALOG = ROOT / "game/catalog.json"

def check(condition, message):
    if not condition:
        raise ValueError(message)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def csv_bytes(rows):
    stream = io.StringIO(newline="")
    csv.writer(stream, lineterminator="\n").writerows(rows)
    return stream.getvalue().encode("utf-8")

def png_dimensions(data):
    check(data[:8] == b"\x89PNG\r\n\x1a\n", "Invalid PNG signature")
    pos = 8
    dimensions = None
    ended = False
    while pos < len(data):
        check(pos + 12 <= len(data), "Truncated PNG chunk")
        size = struct.unpack(">I", data[pos:pos+4])[0]
        kind = data[pos+4:pos+8]
        payload = data[pos+8:pos+8+size]
        check(pos + size + 12 <= len(data), "Truncated PNG payload")
        crc = struct.unpack(">I", data[pos+8+size:pos+12+size])[0]
        check(zlib.crc32(kind + payload) & 0xffffffff == crc, "PNG CRC mismatch")
        if kind == b"IHDR":
            dimensions = struct.unpack(">II", payload[:8])
        pos += size + 12
        if kind == b"IEND":
            ended = True
            break
    check(ended and pos == len(data), "Invalid PNG ending")
    return dimensions

def expected():
    check((OUT / ".gdignore").is_file(), "Missing .gdignore: Console CSVs must not be imported by Godot")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    achievements = catalog["achievements"]
    keys = [a["key"] for a in achievements]
    check(len(keys) == len(set(keys)), "Duplicate achievement keys")
    check(set(keys) == set(SPEC["points"]), "Points must match every catalog key")
    services = (ROOT / "platform/services.gd").read_text(encoding="utf-8")
    check("unlock_achievement(" in services, "Review achievement type: unlock call missing")
    check(not re.search(r"\.(increment_achievement|set_steps_at_least)\s*\(", services),
          "Review achievement type: incremental adapter call found")
    metadata, mappings, review, files = [], [], [], {}
    names = set()
    for order, achievement in enumerate(achievements, 1):
        key = achievement["key"]
        name = achievement.get("name", achievement.get("title", ""))
        original_description = achievement.get("description", "")
        description = original_description or SPEC.get("description_overrides", {}).get(key, "")
        check(bool(description), "Missing description for " + key)
        # Google disallows commas even in quoted Name/Description fields.
        description = re.sub(r"(?<=\d),(?=\d{3}(?:\D|$))", "", description)
        check("," not in name and "," not in description, "Unsupported comma in " + key)
        check(not any(c in name + description for c in "\r\n"), "Embedded newline")
        check(0 < len(name) <= 100 and len(description) <= 500, "Text length invalid")
        check(name not in names, "Duplicate achievement names")
        names.add(name)
        points = SPEC["points"][key]
        check(type(points) is int and 5 <= points <= 200 and points % 5 == 0, "Invalid points")
        icon = ROOT / "marketing/achievements" / (key + ".png")
        data = icon.read_bytes()
        check(len(data) < 1000000 and png_dimensions(data) == (512, 512), "Invalid icon " + key)
        source_icon = achievement.get("icon", "")
        resolved_icon = ROOT / (source_icon[6:] if source_icon.startswith("res://") else
                                ("marketing/" + source_icon if source_icon.startswith("achievements/") else source_icon))
        check(resolved_icon.name == icon.name, "Catalog icon/key mismatch")
        check(resolved_icon.exists(), "Catalog icon missing")
        files[icon.name] = data
        metadata.append([name, description, "False", "", "Revealed", points, order])
        mappings.append([name, icon.name])
        review.append({
            "key": key, "name": name, "description": description,
            "description_source": "catalog" if original_description else "derived from game metric and threshold",
            "catalog_description": original_description,
            "metric": achievement["metric"], "threshold": achievement.get("threshold", achievement.get("target")),
            "type": "standard", "initial_state": "Revealed", "points": points, "list_order": order,
            "icon": icon.relative_to(ROOT).as_posix(), "icon_sha256": sha(data),
            "play_games_achievement_id": ""
        })
    check(sum(SPEC["points"].values()) <= 1000, "Exceeds 1000 game points")
    check(len(achievements) <= 200, "Exceeds achievement limit")
    files = {"AchievementsMetadata.csv": csv_bytes(metadata),
             "AchievementsIconsMappings.csv": csv_bytes(mappings), **files}
    for name, data in files.items():
        check("/" not in name and "\\" not in name, "Not flat")
        check(len(data) < 1000000, "Archive member exceeds 1 MB")
    check(len(files) <= 403, "Too many ZIP members")
    return files, review

def archive_bytes(files):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in files.items():
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, data, compresslevel=9)
    return buffer.getvalue()

def verify(archive_path, files):
    check(archive_path.stat().st_size < 800000000, "ZIP exceeds size limit")
    with zipfile.ZipFile(archive_path) as archive:
        check(archive.testzip() is None, "ZIP CRC error")
        check(archive.namelist() == list(files), "Unexpected ZIP members/order")
        for name, data in files.items():
            check(archive.read(name) == data, "ZIP member differs from source: " + name)
        metadata = list(csv.reader(io.StringIO(archive.read("AchievementsMetadata.csv").decode("utf-8"))))
        mappings = list(csv.reader(io.StringIO(archive.read("AchievementsIconsMappings.csv").decode("utf-8"))))
        check(all(len(row) == 7 for row in metadata), "Metadata column count")
        check(all(len(row) == 2 for row in mappings), "Icon column count")
        check([row[0] for row in metadata] == [row[0] for row in mappings], "Icon name mapping mismatch")
        check(all(row[2:5] == ["False", "", "Revealed"] for row in metadata), "Achievement type/state mismatch")
    return {
        "game": SPEC["game"], "achievement_count": len(metadata), "archive_entries": len(files),
        "total_points": sum(int(row[5]) for row in metadata), "all_standard": True, "all_revealed": True,
        "zip": archive_path.name, "zip_bytes": archive_path.stat().st_size,
        "zip_sha256": sha(archive_path.read_bytes()), "catalog_canonical_json_sha256": sha(json.dumps(json.loads(CATALOG.read_text(encoding="utf-8")), sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")),
        "icon_dimensions": "512x512", "members_under_1000000_bytes": True,
        "flat_archive": True, "csv_headers": False, "zip_crc_and_source_bytes": "PASS",
        "console_import_tested": False, "production_ids_configured": False,
        "schema": "https://developer.android.com/games/pgs/integrate-achievements#zip-file-guidelines"
    }

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate tracked output without rewriting it")
    args = parser.parse_args()
    files, review = expected()
    archive = OUT / (SPEC["slug"] + "-achievements-google-play.zip")
    if not args.check:
        OUT.mkdir(parents=True, exist_ok=True)
        archive.write_bytes(archive_bytes(files))
        for name in ("AchievementsMetadata.csv", "AchievementsIconsMappings.csv"):
            (OUT / name).write_bytes(files[name])
        (OUT / "achievement-id-mapping-and-points.json").write_text(json.dumps(review, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    report = verify(archive, files)
    for name in ("AchievementsMetadata.csv", "AchievementsIconsMappings.csv"):
        check((OUT / name).read_text(encoding="utf-8") == files[name].decode("utf-8"), "CSV differs from expected: " + name)
    check(json.loads((OUT / "achievement-id-mapping-and-points.json").read_text(encoding="utf-8")) == review,
          "Review mapping differs from source")
    if args.check:
        check(json.loads((OUT / "validation.json").read_text(encoding="utf-8")) == report, "Validation receipt differs")
    else:
        (OUT / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))

if __name__ == "__main__":
    main()
