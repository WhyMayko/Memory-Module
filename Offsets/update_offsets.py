import urllib.request
import os

BASE = "https://offsets.imtheo.lol"
FILES = ["Offsets.json", "Struct.hpp", "types.json"]
OUT = os.path.dirname(os.path.abspath(__file__))

for name in FILES:
    url = f"{BASE}/{name}"
    path = os.path.join(OUT, name)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "GalaxHub-Updater/1.0"})
        data = urllib.request.urlopen(req, timeout=15).read()
        with open(path, "wb") as f:
            f.write(data)
        print(f"OK  {name} ({len(data)} bytes)")
    except Exception as e:
        print(f"FAIL {name}: {e}")
