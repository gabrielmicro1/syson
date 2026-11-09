# SysON textual round-trip fixes (benchmark patch)

Patched build of SysON `v2026.9.6` used by the SysML-Gym expert authors. Experts build models in SysON and deliver the model as SysON's textual `.sysml` export, so the export has to keep everything the model contains and the result has to validate on the OMG SysML v2 Pilot.

## What is fixed

| Construct | SysON v2026.9.6 (and `main`, 2026-11-06) | With this patch |
|---|---|---|
| `calc def` | Dropped from the export ("not yet handled") | Exported with parameters, `return` and body |
| `calc` usage | Exported as `action` | Exported as `calc` |
| Invocation `A(x, y)` after a textual import | Exported as `= ;` | Exported as `A(x, y)` (the invoked type may follow the arguments) |
| Standard library call `SequenceFunctions::size(x)` | Exported as `size(x)`, which does not resolve | Keeps its qualified name |
| Nested expressions `(a + b) / c` | **Parentheses dropped**: exported as `a + b / c`, which validates but means something else | Parenthesized by operator precedence |
| Conditional expression `if c ? a else b` | Dropped ("not handled yet") | Exported |
| Index expression `x#(i)` | Dropped ("not handled yet") | Exported |
| `bind a = b;` | Dropped | Exported |
| `loop action a { ... }` | Exported as `action { action a { ... } ; }` (invalid) | Exported as `loop action a { ... }` |
| `action a assign x := v;` | Exported as `a assign :=;` | Exported |
| `action s send x via p;` | Exported without the `;` | Exported |
| `send x to y` | **Imported as `send x via y`** (receiver read as the port) | Imported and exported as `send x to y` |
| `then decide;` (succession to an anonymous node) | Exported as `then;` and `decide;` (invalid) | Exported as `then decide;` |
| Guard or effect on the accepted payload (`accept m : M via p if m.ok`) | Payload names not resolved on import; exported as `if .` | Resolved and exported |
| `expose X::*` | Exported as `expose X::;` | Exported as `expose X::*` |
| `expose X::**` | Exported as `expose X` | Exported as `expose X::**` |
| State initial transition `entry; then S;` | Exported as `entry ; transition then S;` (invalid) | Exported as `entry ; then S;` |
| Apostrophes in `doc` / `comment` bodies | Removed on import (`it's` became `its`) | Kept |

Changed files:

- `backend/services/syson-sysml-metamodel-services/.../textual/SysMLElementSerializer.java`
- `backend/services/syson-sysml-metamodel-services/.../textual/utils/SysMLKeywordSwitch.java`
- `backend/services/syson-sysml-metamodel-services/.../textual/utils/FileNameDeresolver.java`
- `backend/services/syson-sysml-metamodel-services/.../helper/DeresolvingNamespaceProvider.java`
- `backend/application/syson-sysml-import/.../parser/AstTreeParser.java`
- `backend/application/syson-sysml-import/.../translation/EAttributeTranslator.java`

**Verification beyond the fixtures.** Two full reference models (about 1,000 and 2,600 lines: parts, ports, interfaces, flows, three state machines with payload guards and send effects, loops, decisions, assignments, calcs and 35 requirements) were round-tripped. Both import without warnings and export with 0 errors and 0 warnings on the Pilot, and, after normalizing notation (see below) and dropping `//` comments, every keyword count matches the source. The models belong to a private benchmark and are not in this repository; they used the two workarounds below.

## Known issues (not fixed)

- `new X(...)` constructor expressions do not parse on import (SysIDE parser). Declare the item and send it instead: `item n : Notice { attribute :>> soc = x; }` then `send n via p;`.
- An arrow invocation with an inline body (`xs->reduce { in a; in b; max(a, b) }`) loses its body, and the importer cannot resolve the body's parameters. Write the operation out instead. See `known-issues/arrow-body-expression.sysml`.
- A calculation body that ends in a bare result expression (`calc def D { in x : Real; x * 2 }`) loses its first operand. Write the result as a `return` instead: `return : Real = x * 2;`. See `known-issues/result-expression.sysml`.
- Notation that differs from hand-written text but means the same: references by short name where one exists (`'1.1'.powerOut`), interface end names dropped, `assert satisfy`, long-form successions and flows (`first start then a;`, `flow from … to …`), enumeration literals without `enum`.

## Build

Requires Docker and a JDK 21 `javac`. No Maven build: the changed sources are compiled against the libraries inside the base image and swapped into its application jar.

```bash
JAVAC=/path/to/jdk21/bin/javac benchmark-patch/build.sh
```

Produces the image `syson-benchmark:v2026.9.6-bp2`. To add a changed source file, list it in `PATCHED_SOURCES` in `build.sh`.

## Test

Round-trips every file in `fixtures/` through a throwaway SysON instance (port 8083, in-memory database), validates each export with the Pilot, and checks each export against the fixture's `.expect` file (one regular expression per line).

```bash
SYSML_OTS=/path/to/sysml-ots benchmark-patch/test.sh
```

`SYSML_OTS` points to a checkout of the sysml-ots repository, whose `sysmlenv` and `tools/validate_sysml.py` run the Pilot.

## Run

Use the image in place of `eclipsesyson/syson:v2026.9.6` in the docker compose file, for example `IMAGE_TAG=syson-benchmark:v2026.9.6-bp2 docker compose up -d`.
