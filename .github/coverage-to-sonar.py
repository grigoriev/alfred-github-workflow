#!/usr/bin/env python3
"""Convert kcov cobertura reports into the SonarQube generic coverage format.

kcov records class filenames relative to the cobertura <sources> base, so join
them back and make the result relative to the repo root, which is what
SonarCloud matches against.
"""
import glob
import os
import sys
import xml.etree.ElementTree as ET

cov_dir, out_path = sys.argv[1], sys.argv[2]
files = {}
reports = glob.glob(f"{cov_dir}/**/cobertura.xml", recursive=True) + glob.glob(
    f"{cov_dir}/**/coverage.xml", recursive=True
)
for cobertura in reports:
    root = ET.parse(cobertura).getroot()
    sources = [s.text for s in root.findall(".//sources/source") if s.text]
    base = sources[0] if sources else ""
    for cls in root.iter("class"):
        name = cls.get("filename", "")
        full = name if os.path.isabs(name) else os.path.join(base, name)
        rel = os.path.relpath(full)
        covered = files.setdefault(rel, {})
        for line in cls.iter("line"):
            number = int(line.get("number", "0"))
            hits = int(line.get("hits", "0"))
            covered[number] = covered.get(number, False) or hits > 0

coverage = ET.Element("coverage", version="1")
for name, lines in sorted(files.items()):
    file_el = ET.SubElement(coverage, "file", path=name)
    for number, is_covered in sorted(lines.items()):
        ET.SubElement(
            file_el, "lineToCover",
            lineNumber=str(number), covered="true" if is_covered else "false",
        )
ET.ElementTree(coverage).write(out_path, encoding="utf-8", xml_declaration=True)
print(f"wrote {out_path} for {len(files)} file(s)")
