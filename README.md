# sqlite-jni

Pre-built SQLite3 static library with Elide's JNI extensions baked into the amalgamation. Produces `libsqlite3elide.a` (Unix) / `sqlite3elide.lib` (Windows) for consumption by the [WHIPLASH](https://github.com/nicholasgasior/WHIPLASH) project.

## SQLite Version

**3.51.1** (pinned via git submodule at `sqlite/`)

## Supported Platforms

| OS | Architecture | Target Triple | Artifact |
|----|-------------|---------------|----------|
| Linux | x86_64 (glibc) | `x86_64-linux-gnu` | `libsqlite3elide-linux-amd64.tgz` |
| Linux | ARM64 (glibc) | `aarch64-linux-gnu` | `libsqlite3elide-linux-arm64.tgz` |
| Linux | x86_64 (musl) | `x86_64-linux-musl` | `libsqlite3elide-linux-amd64-musl.tgz` |
| macOS | ARM64 | `arm64-apple-darwin` | `libsqlite3elide-macos-arm64.tgz` |
| macOS | x86_64 | `x86_64-apple-darwin` | `libsqlite3elide-macos-amd64.tgz` |
| Windows | x86_64 | `x86_64-pc-windows-msvc` | `sqlite3elide-windows-amd64.tgz` |

## Release Artifact Layout

Each tarball contains:

```
lib/
  libsqlite3elide.a      (or sqlite3elide.lib on Windows)
include/
  sqlite3.h
  sqlite3ext.h
  sqlite3jni.h
```

## Versioning

Tags follow the format `v<sqlite-version>-<YYYYMMDD>`, e.g. `v3.51.1-20260328`. The SQLite version tracks upstream; the date suffix is the release date. Pushing a tag triggers CI to build all platforms and create a GitHub Release with artifacts attached.

## Building Locally

Requirements: a C compiler (gcc or clang) and a JDK (for `jni.h` headers).

```bash
# Initialize the SQLite submodule
git submodule update --init

# Build and package
make install JAVA_HOME=$JAVA_HOME

# Output is in out/
ls out/lib/ out/include/
```

### Build Options

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_HOME` | (required) | Path to JDK installation |
| `RELEASE` | `yes` | `yes` for -O3, `no` for -O1 -g |
| `NATIVE` | `no` | Use `-march=native` tuning |
| `MUSL` | `no` | Build for musl libc |
| `CROSS_HOST` | (unset) | Cross-compilation triple (e.g., `aarch64-linux-gnu`) |
| `VERBOSE` | `no` | Print commands as they execute |

### Cross-compilation Examples

```bash
# Linux ARM64
make install CROSS_HOST=aarch64-linux-gnu JAVA_HOME=$JAVA_HOME

# Linux musl
make install MUSL=yes JAVA_HOME=$JAVA_HOME
```

## SQLite Configure Flags

The library is configured with the following options (identical to the WHIPLASH build):

```
--enable-all --disable-debug --enable-static --enable-shared
--column-metadata --geopoly --memsys5 --scanstatus --update-limit
--with-tempstore=yes --disable-math --disable-tcl
--amalgamation-extra-src=sqlite3jni.c --dll-basename=libsqlite3elide
```

## SQLite Compile Defines

```
SQLITE_CORE=1  SQLITE_THREADSAFE=1  SQLITE_GVM_STATIC=1
SQLITE_DEFAULT_FILE_PERMISSIONS=0666  SQLITE_DEFAULT_MEMSTATUS=0
SQLITE_DISABLE_PAGECACHE_OVERFLOW_STATS=1  SQLITE_ENABLE_API_ARMOR=1
SQLITE_ENABLE_COLUMN_METADATA=1  SQLITE_ENABLE_DBSTAT_VTAB=1
SQLITE_ENABLE_FTS3=1  SQLITE_ENABLE_FTS3_PARENTHESIS=1  SQLITE_ENABLE_FTS5=1
SQLITE_ENABLE_LOAD_EXTENSION=1  SQLITE_ENABLE_MATH_FUNCTIONS=0
SQLITE_ENABLE_RTREE=1  SQLITE_ENABLE_STAT4=1  SQLITE_HAVE_ISNAN=1
SQLITE_MAX_ATTACHED=25  SQLITE_MAX_COLUMN=32767  SQLITE_MAX_FUNCTION_ARG=127
SQLITE_MAX_LENGTH=2147483647  SQLITE_MAX_MMAP_SIZE=1099511627776
SQLITE_MAX_PAGE_COUNT=4294967294  SQLITE_MAX_SQL_LENGTH=1073741824
SQLITE_MAX_VARIABLE_NUMBER=250000
```

## License

- **Build system** (Makefile, CI workflow): MIT
- **SQLite**: Public Domain
- **JNI wrapper** (`jni/sqlite3jni.c`, `jni/sqlite3jni.h`): ISC / MIT
