# SysON textual round-trip fixes (benchmark patch)

Patched build of SysON `v2026.9.6` used by the SysML-Gym expert authors. Experts build models in SysON and deliver the model as SysON's textual `.sysml` export, so the export has to keep everything the model contains and the result has to validate on the OMG SysML v2 Pilot.

## What is fixed

| Construct | SysON v2026.9.6 (and `main`, 2026-11-06) | With this patch |
|---|---|---|
| `calc def` | Dropped from the export ("not yet handled") | Exported with parameters, `return` and body |
| `calc` usage | Exported as `action` | Exported as `calc` |
| Invocation `A(x, y)` after a textual import | Exported as `= ;` | Exported as `A(x, y)` (the invoked type may follow the arguments) |
| `bind a = b;` | Dropped | Exported |
| `expose X::*` | Exported as `expose X::;` | Exported as `expose X::*` |
| `expose X::**` | Exported as `expose X` | Exported as `expose X::**` |
| State initial transition `entry; then S;` | Exported as `entry ; transition then S;` (invalid) | Exported as `entry ; then S;` |
| Apostrophes in `doc` / `comment` bodies | Removed on import (`it's` became `its`) | Kept |

Changed files:

- `backend/services/syson-sysml-metamodel-services/.../textual/SysMLElementSerializer.java`
- `backend/services/syson-sysml-metamodel-services/.../textual/utils/SysMLKeywordSwitch.java`
- `backend/application/syson-sysml-import/.../translation/EAttributeTranslator.java`

## Known issues (not fixed)

- A calculation body that ends in a bare result expression (`calc def D { in x : Real; x * 2 }`) loses its first operand. Write the result as a `return` instead: `return : Real = x * 2;`. See `known-issues/result-expression.sysml`.
- Exports reference elements by short name where one exists (`'1.1'.powerOut`) and drop interface end names. The result is valid SysML and is left as is.

## Build

Requires Docker and a JDK 21 `javac`. No Maven build: the changed sources are compiled against the libraries inside the base image and swapped into its application jar.

```bash
JAVAC=/path/to/jdk21/bin/javac benchmark-patch/build.sh
```

Produces the image `syson-benchmark:v2026.9.6-bp1`. To add a changed source file, list it in `PATCHED_SOURCES` in `build.sh`.

## Test

Round-trips every file in `fixtures/` through a throwaway SysON instance (port 8083, in-memory database), validates each export with the Pilot, and checks each export against the fixture's `.expect` file (one regular expression per line).

```bash
SYSML_OTS=/path/to/sysml-ots benchmark-patch/test.sh
```

`SYSML_OTS` points to a checkout of the sysml-ots repository, whose `sysmlenv` and `tools/validate_sysml.py` run the Pilot.

## Run

Use the image in place of `eclipsesyson/syson:v2026.9.6` in the docker compose file, for example `IMAGE_TAG=syson-benchmark:v2026.9.6-bp1 docker compose up -d`.
