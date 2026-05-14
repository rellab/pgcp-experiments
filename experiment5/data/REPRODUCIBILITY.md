# Experiment 5 — sensor configuration reproducibility

`campus_sensors.json` is generated from `../processed/campus_normalized.json`
by `../scripts/gen_sensors.py` and is intended to be reproducible bit-for-bit.

## Fixed parameters (locked-in)

| Parameter           | Value                              |
|---------------------|------------------------------------|
| RNG seed            | `42`                               |
| Small radius        | `0.089`  (= 200 m / 2251.7 m)      |
| Large radius        | `0.178`  (= 400 m / 2251.7 m)      |
| Large fraction      | `0.5` (random subset upgraded)     |
| PDS min-distance    | `0.089` (= small radius)           |
| PDS max failures    | `10000` consecutive rejections     |
| Component reliability `p_k` | `0.9`                       |

## Reproduce

```bash
cd pgcp-experiments/experiment5
python3 scripts/gen_sensors.py
```

Expected output:

```
PDS saturated at 53 samples (min_dist = 0.0890)
radius assignment: 27 small (r=0.089), 26 large (r=0.178)
wrote .../data/campus_sensors.json
circles_sha256 = c8ff0cb73cac023c146b2e571843e35ea12babee3c23cbf60b5ef9e13c396f89
```

## Expected hashes

- `_meta.circles_sha256` (over the sorted-key, separator-trimmed `circles`
  array; insensitive to surrounding JSON whitespace and ordering of sibling
  keys):

      c8ff0cb73cac023c146b2e571843e35ea12babee3c23cbf60b5ef9e13c396f89

- Full-file SHA-256 (sensitive to JSON formatting, useful for byte-level
  CI checks):

      c18c0fe4f26f9e05bb90e8e3a5cbe3ec1bfec71a392377bc567733e226a13c7f

Verify with:

```bash
shasum -a 256 data/campus_sensors.json
python3 -c "import json,hashlib; d=json.load(open('data/campus_sensors.json')); \
print(hashlib.sha256(json.dumps(d['circles'],sort_keys=True,separators=(',',':')).encode()).hexdigest())"
```

## Python / library versions used when these hashes were produced

The PDS step uses only `random.Random` (CPython stdlib), `shapely.geometry.Point`
for point-in-polygon tests, and the polygon vertex list from
`processed/campus_normalized.json`. The Python `random` Mersenne Twister
is stable across CPython versions, so the hashes above should reproduce
on any CPython 3.8+ as long as the polygon JSON is unchanged.

If the polygon file is regenerated from `export.geojson` the hashes will
change. Treat `processed/campus_normalized.json` as a fixed input.
