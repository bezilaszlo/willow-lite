#!/usr/bin/env python3
import re
import subprocess
import sys

MINE, COMM = sys.argv[1], sys.argv[2]
fails = 0


def dts(path):
    return subprocess.run(["dtc", "-I", "dtb", "-O", "dts", "-q", path], capture_output=True, text=True, check=True).stdout


def parse(text):
    stack, tree, cur, pend = [], {}, None, None
    for line in text.split("\n"):
        s = line.strip()
        if pend is not None:
            pend += " " + s
            if s.endswith(";"):
                k, _, v = pend.partition("=")
                tree[cur][k.strip()] = v.strip().rstrip(";")
                pend = None
            continue
        if s.endswith("{") and "=" not in s:
            stack.append(s[:-1].strip())
            cur = "/".join(stack).replace("//", "/")
            tree.setdefault(cur, {})
        elif s == "};":
            stack.pop()
            cur = "/".join(stack).replace("//", "/") if stack else None
        elif s and cur is not None and not s.startswith("/"):
            if s.endswith(";"):
                k, _, v = s.partition("=")
                tree[cur][k.strip().rstrip(";")] = v.strip().rstrip(";")
            else:
                pend = s
    return tree


def cells(v):
    return [int(x, 16) for x in re.findall(r"0x[0-9a-fA-F]+", v or "")]


def report(level, what, msg):
    global fails
    if level == "FAIL":
        fails += 1
    print(f"{level:<5} {what:<24} {msg}")


def reserved(tree):
    out = []
    for path, props in tree.items():
        if path.startswith("/reserved-memory/") and "reg" in props:
            c = cells(props["reg"])
            for i in range(0, len(c) - 3, 4):
                out.append(((c[i] << 32) | c[i + 1], (c[i + 2] << 32) | c[i + 3], path.rsplit("/", 1)[1], "ramoops" in props.get("compatible", "")))
    return sorted(out)


def covered(addr, size, ranges):
    lo, hi = addr, addr + size
    for a, s, _, _ in sorted(ranges):
        if a <= lo < a + s:
            lo = a + s
            if lo >= hi:
                return True
    return lo >= hi


mine, comm = parse(dts(MINE)), parse(dts(COMM))
m, c = mine["/"], comm["/"]

for key in ("compatible", "model"):
    level = "PASS" if m.get(key) == c.get(key) else "INFO"
    report(level, "root " + key, f"ours={m.get(key)} community={c.get(key)}")

mid, cid = cells(m.get("qcom,msm-id")), cells(c.get("qcom,msm-id"))
report("PASS" if mid == cid else "FAIL", "msm-id", f"ours={[hex(x) for x in mid]} community={[hex(x) for x in cid]}")
mb, cb = cells(m.get("qcom,board-id")), cells(c.get("qcom,board-id"))
mpairs = [tuple(mb[i:i + 2]) for i in range(0, len(mb), 2)]
cpairs = [tuple(cb[i:i + 2]) for i in range(0, len(cb), 2)]
missing = [p for p in cpairs if p not in mpairs]
if not mpairs:
    report("FAIL", "board-id", f"ours has no qcom,board-id; community={cpairs} (known hang cause)")
elif missing:
    report("FAIL", "board-id", f"ours={mpairs} lacks community pair(s) {missing} (known hang cause)")
else:
    report("PASS", "board-id", f"ours={mpairs} includes community {cpairs}")

rm, rc = reserved(mine), reserved(comm)
gaps = [(hex(a), hex(s), n) for a, s, n, ram in rc if not ram and not covered(a, s, rm)]
if gaps:
    report("FAIL", "reserved-memory", f"community carve-outs not covered by ours (known hang cause): {gaps}")
else:
    report("PASS", "reserved-memory", "every community no-map carve-out is covered")
extra = [(hex(a), hex(s), n) for a, s, n, ram in rm if not covered(a, s, rc)]
if extra:
    report("INFO", "reserved-memory extra", f"ours only: {extra}")
for name, side in (("ramoops ours", rm), ("ramoops community", rc)):
    print(f"INFO  {name:<24} {[(hex(a), hex(s)) for a, s, n, ram in side if ram]}")

memm = [p for p in mine if p.startswith("/memory")]
memc = [p for p in comm if p.startswith("/memory")]
same = memm and memc and mine[memm[0]].get("reg") == comm[memc[0]].get("reg") and mine[memm[0]].get("device_type") == comm[memc[0]].get("device_type")
report("PASS" if same else "FAIL", "memory node", f"ours={mine[memm[0]].get('reg') if memm else None} community={comm[memc[0]].get('reg') if memc else None}")

cm, cc = mine.get("/chosen", {}), comm.get("/chosen", {})
report("INFO", "chosen bootargs", f"ours={cm.get('bootargs')} community={cc.get('bootargs')} (boot image cmdline is authoritative)")
fbm = [p for p in mine if p.startswith("/chosen/framebuffer")]
fbc = [p for p in comm if p.startswith("/chosen/framebuffer")]
report("INFO", "simple-framebuffer", f"ours={'yes' if fbm else 'no'} community={'yes' if fbc else 'no'}")

for label, pat in (("dsi host", r"/dsi@5e94000$"), ("panel", r"/panel@0$"), ("dsi phy", r"/phy@5e94400$"), ("mdss", r"display-subsystem@5e00000$")):
    pm = [p for p in mine if re.search(pat, p)]
    pc = [p for p in comm if re.search(pat, p)]
    for p in pm:
        report("INFO", label + " ours", f"{p} compatible={mine[p].get('compatible')} status={mine[p].get('status')}")
    for p in pc:
        report("INFO", label + " community", f"{p} compatible={comm[p].get('compatible')} status={comm[p].get('status')}")
    if pc and not pm:
        report("FAIL", label, "present in community DT, missing from ours")

for label, pat in (("gpu", r"/gpu@5900000$"), ("cpufreq", r"/cpufreq@f521000$"), ("touch", r"touchscreen@0$"), ("backlight", r"(led-controller|backlight)@36$")):
    pm = [p for p in mine if re.search(pat, p)]
    pc = [p for p in comm if re.search(pat, p)]
    report("PASS" if pm or not pc else "FAIL", label + " node", f"ours={bool(pm)} community={bool(pc)}")

print(f"dtb-compare: {fails} failure(s)")
sys.exit(1 if fails else 0)
