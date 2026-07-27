# Toolbox64 bug: `Graphics2D.h` — `'write_page' was not declared in this scope` (QB64‑PE 4.5.0)

**Reporter:** Rick (grymmjack) · **Component:** `Graphics/Graphics2D.h` (pulled in by `Graphics/ANSIPrint.bi`)

## Environment
- **QB64‑PE:** `V4.5.0-UNKNOWN` (built from source, Linux x86‑64, g++)
- **Toolbox64:** `main` @ `d7e5c1175ab1ce85c9089077b2596c73945ba68a`
- Reproduces via the C++ (g++) stage; QB64 parsing itself succeeds.

## Minimal repro
```basic
'$INCLUDE:'Toolbox64/Graphics/ANSIPrint.bi'
SCREEN _NEWIMAGE(640, 480, 32)
ANSI_Print "Hello"
```
`ANSIPrint.bi` → `Graphics2D.bi` → `DECLARE LIBRARY "Graphics2D"` → `Graphics2D.h`.

Compile:
```
qb64pe -w -x repro.bas -o repro.run
```

## Symptom
QB64 parse passes; g++ then fails with dozens of:
```
Graphics2D.h:107:18: error: 'write_page' was not declared in this scope
Graphics2D.h:116:26: error: 'write_page' was not declared in this scope
Graphics2D.h:163:38: error: 'write_page' was not declared in this scope
Graphics2D.h:191:5:  error: 'write_page' was not declared in this scope
...
ERROR: C++ compilation failed.
```

## Analysis
`Graphics2D.h` *does* provide a fallback declaration, but it's gated:
```cpp
#ifndef INC_COMMON_CPP
    struct img_struct { ... };
    ...
    // NOTE: These are QB64-PE internal structures and can change at any time!
    extern img_struct *write_page;   // line 86
    extern img_struct *img;
    extern img_struct *read_page;
    ...
#endif
```
The errors mean the `#ifndef INC_COMMON_CPP` path is being **skipped** (i.e. `INC_COMMON_CPP` is defined), so the header relies on QB64‑PE's own `common` translation unit to declare `write_page` — and under **4.5.0** that symbol isn't visible at this scope. (I couldn't find `write_page` in `internal/c/libqb/include/*.h` on 4.5.0; it appears to live in `libqb.cpp`.)

**Telling comparison:** the older `GraphicOps.h` uses the *identical* `#ifndef INC_COMMON_CPP … extern img_struct *write_page; …` pattern and **compiles fine in the same QB64‑PE 4.5.0 build** (I'm using it as a vendored ANSI renderer now). So the regression looks specific to the `Graphics2D.h` inclusion path — either `INC_COMMON_CPP` ends up defined for `Graphics2D.h` but not `GraphicOps.h`, or the two headers are emitted at different points relative to QB64‑PE's `common` declarations.

## Likely culprit / questions
1. Did QB64‑PE 4.5.0 move/rename/namespace the `write_page` global (and `img` / `read_page`) such that `#ifndef INC_COMMON_CPP` no longer guards it correctly?
2. Should `Graphics2D.h`'s fallback externs be declared **unconditionally** (as `GraphicOps.h` effectively achieves), rather than under `#ifndef INC_COMMON_CPP`?

## Workaround in use
Vendored the older `ANSIPrint` + `GraphicOps` + `Common`/`Types`/`Debug` headers (pre‑Graphics2D) — those compile on both 4.4.0 and 4.5.0.
