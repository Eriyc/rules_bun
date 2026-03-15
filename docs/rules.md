<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API surface for Bun Bazel rules.

## Hermeticity And Determinism

- Hermetic rule surfaces: `bun_build`, `bun_bundle`, `bun_compile`, `bun_test`
- Runfiles-only executable surface: `bun_binary`
- Reproducible but non-hermetic repository surface: `bun_install`
- Local workflow helpers: `bun_script`, `bun_dev`, `js_run_devserver`

Strict defaults:

- `bun_build`, `bun_bundle`, `bun_compile`, and `bun_test` require `install_mode = "disable"`
- Runtime launchers stage hermetic `bun`, `bunx`, and `node` commands on `PATH` and do not inherit the host `PATH` unless `inherit_host_path = True`

<a id="bun_binary"></a>

## bun_binary

<pre>
load("@rules_bun//bun:defs.bzl", "bun_binary")

bun_binary(<a href="#bun_binary-name">name</a>, <a href="#bun_binary-deps">deps</a>, <a href="#bun_binary-data">data</a>, <a href="#bun_binary-conditions">conditions</a>, <a href="#bun_binary-entry_point">entry_point</a>, <a href="#bun_binary-env_files">env_files</a>, <a href="#bun_binary-install_mode">install_mode</a>, <a href="#bun_binary-no_env_file">no_env_file</a>,
           <a href="#bun_binary-node_modules">node_modules</a>, <a href="#bun_binary-preload">preload</a>, <a href="#bun_binary-run_flags">run_flags</a>, <a href="#bun_binary-smol">smol</a>, <a href="#bun_binary-working_dir">working_dir</a>)
</pre>

Runs a JS/TS entry point with Bun as an executable target.

Use this rule for non-test scripts and CLIs that should run via `bazel run`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_binary-deps"></a>deps |  Library dependencies required by the program.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_binary-data"></a>data |  Additional runtime files required by the program.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_binary-conditions"></a>conditions |  Custom package resolve conditions passed to Bun.   | List of strings | optional |  `[]`  |
| <a id="bun_binary-entry_point"></a>entry_point |  Path to the main JS/TS file to execute.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="bun_binary-env_files"></a>env_files |  Additional environment files loaded with `--env-file`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_binary-install_mode"></a>install_mode |  Whether Bun may auto-install missing packages at runtime. Non-`disable` values are runtime opt-ins and are not hermetic.   | String | optional |  `"disable"`  |
| <a id="bun_binary-inherit_host_path"></a>inherit_host_path |  If true, appends the host PATH after the staged Bun runtime tool bin and `node_modules/.bin` entries at runtime.   | Boolean | optional |  `False`  |
| <a id="bun_binary-no_env_file"></a>no_env_file |  If true, disables Bun's automatic `.env` loading.   | Boolean | optional |  `False`  |
| <a id="bun_binary-node_modules"></a>node_modules |  Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, in runfiles.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="bun_binary-preload"></a>preload |  Modules to preload with `--preload` before running the entry point.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_binary-run_flags"></a>run_flags |  Additional raw flags forwarded to `bun run` before the entry point.   | List of strings | optional |  `[]`  |
| <a id="bun_binary-smol"></a>smol |  If true, enables Bun's lower-memory runtime mode.   | Boolean | optional |  `False`  |
| <a id="bun_binary-working_dir"></a>working_dir |  Working directory at runtime: `workspace` root or nearest `entry_point` ancestor containing `.env`/`package.json`.   | String | optional |  `"workspace"`  |


<a id="bun_build"></a>

## bun_build

<pre>
load("@rules_bun//bun:defs.bzl", "bun_build")

bun_build(<a href="#bun_build-name">name</a>, <a href="#bun_build-deps">deps</a>, <a href="#bun_build-data">data</a>, <a href="#bun_build-asset_naming">asset_naming</a>, <a href="#bun_build-banner">banner</a>, <a href="#bun_build-build_flags">build_flags</a>, <a href="#bun_build-chunk_naming">chunk_naming</a>, <a href="#bun_build-conditions">conditions</a>,
          <a href="#bun_build-css_chunking">css_chunking</a>, <a href="#bun_build-define">define</a>, <a href="#bun_build-drop">drop</a>, <a href="#bun_build-emit_dce_annotations">emit_dce_annotations</a>, <a href="#bun_build-entry_naming">entry_naming</a>, <a href="#bun_build-entry_points">entry_points</a>, <a href="#bun_build-env">env</a>, <a href="#bun_build-external">external</a>,
          <a href="#bun_build-feature">feature</a>, <a href="#bun_build-footer">footer</a>, <a href="#bun_build-format">format</a>, <a href="#bun_build-install_mode">install_mode</a>, <a href="#bun_build-jsx_factory">jsx_factory</a>, <a href="#bun_build-jsx_fragment">jsx_fragment</a>, <a href="#bun_build-jsx_import_source">jsx_import_source</a>,
          <a href="#bun_build-jsx_runtime">jsx_runtime</a>, <a href="#bun_build-jsx_side_effects">jsx_side_effects</a>, <a href="#bun_build-keep_names">keep_names</a>, <a href="#bun_build-loader">loader</a>, <a href="#bun_build-metafile">metafile</a>, <a href="#bun_build-metafile_md">metafile_md</a>, <a href="#bun_build-minify">minify</a>,
          <a href="#bun_build-minify_identifiers">minify_identifiers</a>, <a href="#bun_build-minify_syntax">minify_syntax</a>, <a href="#bun_build-minify_whitespace">minify_whitespace</a>, <a href="#bun_build-no_bundle">no_bundle</a>, <a href="#bun_build-node_modules">node_modules</a>, <a href="#bun_build-packages">packages</a>,
          <a href="#bun_build-production">production</a>, <a href="#bun_build-public_path">public_path</a>, <a href="#bun_build-react_fast_refresh">react_fast_refresh</a>, <a href="#bun_build-root">root</a>, <a href="#bun_build-sourcemap">sourcemap</a>, <a href="#bun_build-splitting">splitting</a>, <a href="#bun_build-target">target</a>)
</pre>

Builds one or more entry points with `bun build`.

The rule emits a directory artifact so Bun can materialize multi-file output
graphs such as HTML, CSS, assets, and split chunks. Optional metafile outputs
may be requested with `metafile` and `metafile_md`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_build-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_build-deps"></a>deps |  Source/library dependencies that provide transitive inputs.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_build-data"></a>data |  Additional non-source files needed during building.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_build-asset_naming"></a>asset_naming |  Optional asset naming template.   | String | optional |  `""`  |
| <a id="bun_build-banner"></a>banner |  Optional bundle banner text.   | String | optional |  `""`  |
| <a id="bun_build-build_flags"></a>build_flags |  Additional raw flags forwarded to `bun build`.   | List of strings | optional |  `[]`  |
| <a id="bun_build-chunk_naming"></a>chunk_naming |  Optional chunk naming template.   | String | optional |  `""`  |
| <a id="bun_build-conditions"></a>conditions |  Custom resolve conditions passed to Bun.   | List of strings | optional |  `[]`  |
| <a id="bun_build-css_chunking"></a>css_chunking |  If true, Bun chunks CSS across multiple entry points.   | Boolean | optional |  `False`  |
| <a id="bun_build-define"></a>define |  Repeated `--define` values such as `process.env.NODE_ENV:"production"`.   | List of strings | optional |  `[]`  |
| <a id="bun_build-drop"></a>drop |  Repeated `--drop` values, for example `console`.   | List of strings | optional |  `[]`  |
| <a id="bun_build-emit_dce_annotations"></a>emit_dce_annotations |  If true, re-emits DCE annotations in the bundle.   | Boolean | optional |  `False`  |
| <a id="bun_build-entry_naming"></a>entry_naming |  Optional entry naming template.   | String | optional |  `""`  |
| <a id="bun_build-entry_points"></a>entry_points |  Entry files to build, including JS/TS or HTML entry points.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="bun_build-env"></a>env |  Inline environment variable behavior passed to `--env`.   | String | optional |  `""`  |
| <a id="bun_build-external"></a>external |  Modules treated as externals (not bundled).   | List of strings | optional |  `[]`  |
| <a id="bun_build-feature"></a>feature |  Repeated `--feature` values for dead-code elimination.   | List of strings | optional |  `[]`  |
| <a id="bun_build-footer"></a>footer |  Optional bundle footer text.   | String | optional |  `""`  |
| <a id="bun_build-format"></a>format |  Output module format.   | String | optional |  `"esm"`  |
| <a id="bun_build-install_mode"></a>install_mode |  Whether Bun may auto-install missing packages while executing the build. Hermetic builds require `\"disable\"`, and other values are rejected.   | String | optional |  `"disable"`  |
| <a id="bun_build-jsx_factory"></a>jsx_factory |  Optional JSX factory override.   | String | optional |  `""`  |
| <a id="bun_build-jsx_fragment"></a>jsx_fragment |  Optional JSX fragment override.   | String | optional |  `""`  |
| <a id="bun_build-jsx_import_source"></a>jsx_import_source |  Optional JSX import source override.   | String | optional |  `""`  |
| <a id="bun_build-jsx_runtime"></a>jsx_runtime |  Optional JSX runtime override.   | String | optional |  `""`  |
| <a id="bun_build-jsx_side_effects"></a>jsx_side_effects |  If true, treats JSX as having side effects.   | Boolean | optional |  `False`  |
| <a id="bun_build-keep_names"></a>keep_names |  If true, preserves function and class names when minifying.   | Boolean | optional |  `False`  |
| <a id="bun_build-loader"></a>loader |  Repeated `--loader` values such as `.svg:file`.   | List of strings | optional |  `[]`  |
| <a id="bun_build-metafile"></a>metafile |  If true, emits Bun's JSON metafile alongside the output directory.   | Boolean | optional |  `False`  |
| <a id="bun_build-metafile_md"></a>metafile_md |  If true, emits Bun's markdown metafile alongside the output directory.   | Boolean | optional |  `False`  |
| <a id="bun_build-minify"></a>minify |  If true, enables all Bun minification passes.   | Boolean | optional |  `False`  |
| <a id="bun_build-minify_identifiers"></a>minify_identifiers |  If true, minifies identifiers only.   | Boolean | optional |  `False`  |
| <a id="bun_build-minify_syntax"></a>minify_syntax |  If true, minifies syntax only.   | Boolean | optional |  `False`  |
| <a id="bun_build-minify_whitespace"></a>minify_whitespace |  If true, minifies whitespace only.   | Boolean | optional |  `False`  |
| <a id="bun_build-no_bundle"></a>no_bundle |  If true, transpiles without bundling.   | Boolean | optional |  `False`  |
| <a id="bun_build-node_modules"></a>node_modules |  Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, for package resolution.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="bun_build-packages"></a>packages |  Whether packages stay bundled or are treated as external.   | String | optional |  `"bundle"`  |
| <a id="bun_build-production"></a>production |  If true, sets `NODE_ENV=production` and enables Bun production mode.   | Boolean | optional |  `False`  |
| <a id="bun_build-public_path"></a>public_path |  Optional public path prefix for emitted imports.   | String | optional |  `""`  |
| <a id="bun_build-react_fast_refresh"></a>react_fast_refresh |  If true, enables Bun's React fast refresh transform.   | Boolean | optional |  `False`  |
| <a id="bun_build-root"></a>root |  Optional root directory for multiple entry points. When omitted, `bun_build` derives one from the entry point parent directories to keep emitted files inside the declared output tree.   | String | optional |  `""`  |
| <a id="bun_build-sourcemap"></a>sourcemap |  Sourcemap emission mode.   | String | optional |  `"none"`  |
| <a id="bun_build-splitting"></a>splitting |  If true, enables code splitting.   | Boolean | optional |  `False`  |
| <a id="bun_build-target"></a>target |  Bun build target environment.   | String | optional |  `"browser"`  |


<a id="bun_bundle"></a>

## bun_bundle

<pre>
load("@rules_bun//bun:defs.bzl", "bun_bundle")

bun_bundle(<a href="#bun_bundle-name">name</a>, <a href="#bun_bundle-deps">deps</a>, <a href="#bun_bundle-data">data</a>, <a href="#bun_bundle-build_flags">build_flags</a>, <a href="#bun_bundle-entry_points">entry_points</a>, <a href="#bun_bundle-external">external</a>, <a href="#bun_bundle-format">format</a>, <a href="#bun_bundle-install_mode">install_mode</a>, <a href="#bun_bundle-minify">minify</a>,
           <a href="#bun_bundle-node_modules">node_modules</a>, <a href="#bun_bundle-sourcemap">sourcemap</a>, <a href="#bun_bundle-target">target</a>)
</pre>

Bundles one or more JS/TS entry points using Bun build.

Each entry point produces one output JavaScript artifact.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_bundle-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_bundle-deps"></a>deps |  Source/library dependencies that provide transitive inputs.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_bundle-data"></a>data |  Additional non-source files needed during bundling.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_bundle-build_flags"></a>build_flags |  Additional raw flags forwarded to `bun build`.   | List of strings | optional |  `[]`  |
| <a id="bun_bundle-entry_points"></a>entry_points |  Entry files to bundle.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="bun_bundle-external"></a>external |  Package names to treat as externals (not bundled).   | List of strings | optional |  `[]`  |
| <a id="bun_bundle-format"></a>format |  Output module format.   | String | optional |  `"esm"`  |
| <a id="bun_bundle-install_mode"></a>install_mode |  Whether Bun may auto-install missing packages during bundling. Hermetic bundles require `\"disable\"`, and other values are rejected.   | String | optional |  `"disable"`  |
| <a id="bun_bundle-minify"></a>minify |  If true, minifies bundle output.   | Boolean | optional |  `False`  |
| <a id="bun_bundle-node_modules"></a>node_modules |  Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, for package resolution.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="bun_bundle-sourcemap"></a>sourcemap |  If true, emits source maps.   | Boolean | optional |  `False`  |
| <a id="bun_bundle-target"></a>target |  Bun build target environment.   | String | optional |  `"browser"`  |


<a id="bun_compile"></a>

## bun_compile

<pre>
load("@rules_bun//bun:defs.bzl", "bun_compile")

bun_compile(<a href="#bun_compile-name">name</a>, <a href="#bun_compile-deps">deps</a>, <a href="#bun_compile-data">data</a>, <a href="#bun_compile-asset_naming">asset_naming</a>, <a href="#bun_compile-banner">banner</a>, <a href="#bun_compile-build_flags">build_flags</a>, <a href="#bun_compile-bytecode">bytecode</a>, <a href="#bun_compile-chunk_naming">chunk_naming</a>,
            <a href="#bun_compile-compile_autoload_bunfig">compile_autoload_bunfig</a>, <a href="#bun_compile-compile_autoload_dotenv">compile_autoload_dotenv</a>, <a href="#bun_compile-compile_autoload_package_json">compile_autoload_package_json</a>,
            <a href="#bun_compile-compile_autoload_tsconfig">compile_autoload_tsconfig</a>, <a href="#bun_compile-compile_exec_argv">compile_exec_argv</a>, <a href="#bun_compile-compile_executable">compile_executable</a>, <a href="#bun_compile-conditions">conditions</a>,
            <a href="#bun_compile-css_chunking">css_chunking</a>, <a href="#bun_compile-define">define</a>, <a href="#bun_compile-drop">drop</a>, <a href="#bun_compile-emit_dce_annotations">emit_dce_annotations</a>, <a href="#bun_compile-entry_naming">entry_naming</a>, <a href="#bun_compile-entry_point">entry_point</a>, <a href="#bun_compile-env">env</a>,
            <a href="#bun_compile-external">external</a>, <a href="#bun_compile-feature">feature</a>, <a href="#bun_compile-footer">footer</a>, <a href="#bun_compile-format">format</a>, <a href="#bun_compile-install_mode">install_mode</a>, <a href="#bun_compile-jsx_factory">jsx_factory</a>, <a href="#bun_compile-jsx_fragment">jsx_fragment</a>,
            <a href="#bun_compile-jsx_import_source">jsx_import_source</a>, <a href="#bun_compile-jsx_runtime">jsx_runtime</a>, <a href="#bun_compile-jsx_side_effects">jsx_side_effects</a>, <a href="#bun_compile-keep_names">keep_names</a>, <a href="#bun_compile-loader">loader</a>, <a href="#bun_compile-minify">minify</a>,
            <a href="#bun_compile-minify_identifiers">minify_identifiers</a>, <a href="#bun_compile-minify_syntax">minify_syntax</a>, <a href="#bun_compile-minify_whitespace">minify_whitespace</a>, <a href="#bun_compile-no_bundle">no_bundle</a>, <a href="#bun_compile-node_modules">node_modules</a>, <a href="#bun_compile-packages">packages</a>,
            <a href="#bun_compile-production">production</a>, <a href="#bun_compile-public_path">public_path</a>, <a href="#bun_compile-react_fast_refresh">react_fast_refresh</a>, <a href="#bun_compile-root">root</a>, <a href="#bun_compile-sourcemap">sourcemap</a>, <a href="#bun_compile-splitting">splitting</a>, <a href="#bun_compile-target">target</a>,
            <a href="#bun_compile-windows_copyright">windows_copyright</a>, <a href="#bun_compile-windows_description">windows_description</a>, <a href="#bun_compile-windows_hide_console">windows_hide_console</a>, <a href="#bun_compile-windows_icon">windows_icon</a>,
            <a href="#bun_compile-windows_publisher">windows_publisher</a>, <a href="#bun_compile-windows_title">windows_title</a>, <a href="#bun_compile-windows_version">windows_version</a>)
</pre>

Compiles a Bun program into a standalone executable with `bun build --compile`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_compile-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_compile-deps"></a>deps |  Source/library dependencies that provide transitive inputs.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_compile-data"></a>data |  Additional non-source files needed during building.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_compile-asset_naming"></a>asset_naming |  Optional asset naming template.   | String | optional |  `""`  |
| <a id="bun_compile-banner"></a>banner |  Optional bundle banner text.   | String | optional |  `""`  |
| <a id="bun_compile-build_flags"></a>build_flags |  Additional raw flags forwarded to `bun build`.   | List of strings | optional |  `[]`  |
| <a id="bun_compile-bytecode"></a>bytecode |  If true, enables Bun bytecode caching in the compiled executable.   | Boolean | optional |  `False`  |
| <a id="bun_compile-chunk_naming"></a>chunk_naming |  Optional chunk naming template.   | String | optional |  `""`  |
| <a id="bun_compile-compile_autoload_bunfig"></a>compile_autoload_bunfig |  Whether the compiled executable auto-loads `bunfig.toml` at runtime.   | Boolean | optional |  `True`  |
| <a id="bun_compile-compile_autoload_dotenv"></a>compile_autoload_dotenv |  Whether the compiled executable auto-loads `.env` files at runtime.   | Boolean | optional |  `True`  |
| <a id="bun_compile-compile_autoload_package_json"></a>compile_autoload_package_json |  Whether the compiled executable auto-loads `package.json` at runtime.   | Boolean | optional |  `False`  |
| <a id="bun_compile-compile_autoload_tsconfig"></a>compile_autoload_tsconfig |  Whether the compiled executable auto-loads `tsconfig.json` at runtime.   | Boolean | optional |  `False`  |
| <a id="bun_compile-compile_exec_argv"></a>compile_exec_argv |  Repeated `--compile-exec-argv` values prepended to the executable's `execArgv`.   | List of strings | optional |  `[]`  |
| <a id="bun_compile-compile_executable"></a>compile_executable |  Optional Bun executable used for cross-compilation via `--compile-executable-path`.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="bun_compile-conditions"></a>conditions |  Custom resolve conditions passed to Bun.   | List of strings | optional |  `[]`  |
| <a id="bun_compile-css_chunking"></a>css_chunking |  If true, Bun chunks CSS across multiple entry points.   | Boolean | optional |  `False`  |
| <a id="bun_compile-define"></a>define |  Repeated `--define` values such as `process.env.NODE_ENV:"production"`.   | List of strings | optional |  `[]`  |
| <a id="bun_compile-drop"></a>drop |  Repeated `--drop` values, for example `console`.   | List of strings | optional |  `[]`  |
| <a id="bun_compile-emit_dce_annotations"></a>emit_dce_annotations |  If true, re-emits DCE annotations in the bundle.   | Boolean | optional |  `False`  |
| <a id="bun_compile-entry_naming"></a>entry_naming |  Optional entry naming template.   | String | optional |  `""`  |
| <a id="bun_compile-entry_point"></a>entry_point |  Entry file to compile into an executable.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="bun_compile-env"></a>env |  Inline environment variable behavior passed to `--env`.   | String | optional |  `""`  |
| <a id="bun_compile-external"></a>external |  Modules treated as externals (not bundled).   | List of strings | optional |  `[]`  |
| <a id="bun_compile-feature"></a>feature |  Repeated `--feature` values for dead-code elimination.   | List of strings | optional |  `[]`  |
| <a id="bun_compile-footer"></a>footer |  Optional bundle footer text.   | String | optional |  `""`  |
| <a id="bun_compile-format"></a>format |  Output module format.   | String | optional |  `"esm"`  |
| <a id="bun_compile-install_mode"></a>install_mode |  Whether Bun may auto-install missing packages while executing the build. Hermetic compile actions require `\"disable\"`, and other values are rejected.   | String | optional |  `"disable"`  |
| <a id="bun_compile-jsx_factory"></a>jsx_factory |  Optional JSX factory override.   | String | optional |  `""`  |
| <a id="bun_compile-jsx_fragment"></a>jsx_fragment |  Optional JSX fragment override.   | String | optional |  `""`  |
| <a id="bun_compile-jsx_import_source"></a>jsx_import_source |  Optional JSX import source override.   | String | optional |  `""`  |
| <a id="bun_compile-jsx_runtime"></a>jsx_runtime |  Optional JSX runtime override.   | String | optional |  `""`  |
| <a id="bun_compile-jsx_side_effects"></a>jsx_side_effects |  If true, treats JSX as having side effects.   | Boolean | optional |  `False`  |
| <a id="bun_compile-keep_names"></a>keep_names |  If true, preserves function and class names when minifying.   | Boolean | optional |  `False`  |
| <a id="bun_compile-loader"></a>loader |  Repeated `--loader` values such as `.svg:file`.   | List of strings | optional |  `[]`  |
| <a id="bun_compile-minify"></a>minify |  If true, enables all Bun minification passes.   | Boolean | optional |  `False`  |
| <a id="bun_compile-minify_identifiers"></a>minify_identifiers |  If true, minifies identifiers only.   | Boolean | optional |  `False`  |
| <a id="bun_compile-minify_syntax"></a>minify_syntax |  If true, minifies syntax only.   | Boolean | optional |  `False`  |
| <a id="bun_compile-minify_whitespace"></a>minify_whitespace |  If true, minifies whitespace only.   | Boolean | optional |  `False`  |
| <a id="bun_compile-no_bundle"></a>no_bundle |  If true, transpiles without bundling.   | Boolean | optional |  `False`  |
| <a id="bun_compile-node_modules"></a>node_modules |  Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, for package resolution.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="bun_compile-packages"></a>packages |  Whether packages stay bundled or are treated as external.   | String | optional |  `"bundle"`  |
| <a id="bun_compile-production"></a>production |  If true, sets `NODE_ENV=production` and enables Bun production mode.   | Boolean | optional |  `False`  |
| <a id="bun_compile-public_path"></a>public_path |  Optional public path prefix for emitted imports.   | String | optional |  `""`  |
| <a id="bun_compile-react_fast_refresh"></a>react_fast_refresh |  If true, enables Bun's React fast refresh transform.   | Boolean | optional |  `False`  |
| <a id="bun_compile-root"></a>root |  Optional root directory for multiple entry points.   | String | optional |  `""`  |
| <a id="bun_compile-sourcemap"></a>sourcemap |  Sourcemap emission mode.   | String | optional |  `"none"`  |
| <a id="bun_compile-splitting"></a>splitting |  If true, enables code splitting.   | Boolean | optional |  `False`  |
| <a id="bun_compile-target"></a>target |  Bun build target environment for the compiled executable.   | String | optional |  `"bun"`  |
| <a id="bun_compile-windows_copyright"></a>windows_copyright |  Optional Windows copyright metadata.   | String | optional |  `""`  |
| <a id="bun_compile-windows_description"></a>windows_description |  Optional Windows description metadata.   | String | optional |  `""`  |
| <a id="bun_compile-windows_hide_console"></a>windows_hide_console |  When targeting Windows, hides the console window for GUI-style executables.   | Boolean | optional |  `False`  |
| <a id="bun_compile-windows_icon"></a>windows_icon |  Optional Windows icon path passed directly to Bun.   | String | optional |  `""`  |
| <a id="bun_compile-windows_publisher"></a>windows_publisher |  Optional Windows publisher metadata.   | String | optional |  `""`  |
| <a id="bun_compile-windows_title"></a>windows_title |  Optional Windows executable title.   | String | optional |  `""`  |
| <a id="bun_compile-windows_version"></a>windows_version |  Optional Windows version metadata.   | String | optional |  `""`  |


<a id="bun_dev"></a>

## bun_dev

<pre>
load("@rules_bun//bun:defs.bzl", "bun_dev")

bun_dev(<a href="#bun_dev-name">name</a>, <a href="#bun_dev-data">data</a>, <a href="#bun_dev-conditions">conditions</a>, <a href="#bun_dev-entry_point">entry_point</a>, <a href="#bun_dev-env_files">env_files</a>, <a href="#bun_dev-install_mode">install_mode</a>, <a href="#bun_dev-no_clear_screen">no_clear_screen</a>, <a href="#bun_dev-no_env_file">no_env_file</a>,
        <a href="#bun_dev-node_modules">node_modules</a>, <a href="#bun_dev-preload">preload</a>, <a href="#bun_dev-restart_on">restart_on</a>, <a href="#bun_dev-run_flags">run_flags</a>, <a href="#bun_dev-smol">smol</a>, <a href="#bun_dev-watch_mode">watch_mode</a>, <a href="#bun_dev-working_dir">working_dir</a>)
</pre>

Runs a JS/TS entry point in Bun development watch mode.

This rule is intended for local dev loops (`bazel run`) and supports Bun
watch/HMR plus optional full restarts on selected file changes.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_dev-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_dev-data"></a>data |  Additional runtime files required by the dev process.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_dev-conditions"></a>conditions |  Custom package resolve conditions passed to Bun.   | List of strings | optional |  `[]`  |
| <a id="bun_dev-entry_point"></a>entry_point |  Path to the main JS/TS file to execute in dev mode.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="bun_dev-env_files"></a>env_files |  Additional environment files loaded with `--env-file`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_dev-install_mode"></a>install_mode |  Whether Bun may auto-install missing packages in dev mode. This is a local workflow helper, not a hermetic execution surface.   | String | optional |  `"disable"`  |
| <a id="bun_dev-inherit_host_path"></a>inherit_host_path |  If true, appends the host PATH after the staged Bun runtime tool bin and `node_modules/.bin` entries at runtime.   | Boolean | optional |  `False`  |
| <a id="bun_dev-no_clear_screen"></a>no_clear_screen |  If true, disables terminal clearing on Bun reloads.   | Boolean | optional |  `False`  |
| <a id="bun_dev-no_env_file"></a>no_env_file |  If true, disables Bun's automatic `.env` loading.   | Boolean | optional |  `False`  |
| <a id="bun_dev-node_modules"></a>node_modules |  Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, in runfiles.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="bun_dev-preload"></a>preload |  Modules to preload with `--preload` before running the entry point.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_dev-restart_on"></a>restart_on |  Files that trigger a full Bun process restart when they change.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_dev-run_flags"></a>run_flags |  Additional raw flags forwarded to `bun run` before the entry point.   | List of strings | optional |  `[]`  |
| <a id="bun_dev-smol"></a>smol |  If true, enables Bun's lower-memory runtime mode.   | Boolean | optional |  `False`  |
| <a id="bun_dev-watch_mode"></a>watch_mode |  Bun live-reload mode: `watch` (default) or `hot`.   | String | optional |  `"watch"`  |
| <a id="bun_dev-working_dir"></a>working_dir |  Working directory at runtime: `workspace` root or nearest `entry_point` ancestor containing `.env`/`package.json`.   | String | optional |  `"workspace"`  |


<a id="bun_script"></a>

## bun_script

<pre>
load("@rules_bun//bun:defs.bzl", "bun_script")

bun_script(<a href="#bun_script-name">name</a>, <a href="#bun_script-data">data</a>, <a href="#bun_script-conditions">conditions</a>, <a href="#bun_script-env_files">env_files</a>, <a href="#bun_script-execution_mode">execution_mode</a>, <a href="#bun_script-filters">filters</a>, <a href="#bun_script-install_mode">install_mode</a>, <a href="#bun_script-no_env_file">no_env_file</a>,
           <a href="#bun_script-no_exit_on_error">no_exit_on_error</a>, <a href="#bun_script-node_modules">node_modules</a>, <a href="#bun_script-package_json">package_json</a>, <a href="#bun_script-preload">preload</a>, <a href="#bun_script-run_flags">run_flags</a>, <a href="#bun_script-script">script</a>, <a href="#bun_script-shell">shell</a>, <a href="#bun_script-silent">silent</a>,
           <a href="#bun_script-smol">smol</a>, <a href="#bun_script-working_dir">working_dir</a>, <a href="#bun_script-workspaces">workspaces</a>)
</pre>

Runs a named `package.json` script with Bun as an executable target.

Use this rule to expose existing package scripts such as `dev`, `build`, or
`check` via `bazel run` without adding wrapper shell scripts. This is a good fit
for Vite-style workflows, where scripts like `vite dev` or `vite build` are
declared in `package.json` and expect to run from the package directory with
the staged Bun runtime tool bin and `node_modules/.bin` available on `PATH`.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_script-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_script-data"></a>data |  Additional runtime files required by the script.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_script-conditions"></a>conditions |  Custom package resolve conditions passed to Bun.   | List of strings | optional |  `[]`  |
| <a id="bun_script-env_files"></a>env_files |  Additional environment files loaded with `--env-file`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_script-execution_mode"></a>execution_mode |  How Bun should execute matching workspace scripts.   | String | optional |  `"single"`  |
| <a id="bun_script-filters"></a>filters |  Workspace package filters passed via repeated `--filter` flags.   | List of strings | optional |  `[]`  |
| <a id="bun_script-install_mode"></a>install_mode |  Whether Bun may auto-install missing packages while running the script. This is a local workflow helper, not a hermetic execution surface.   | String | optional |  `"disable"`  |
| <a id="bun_script-inherit_host_path"></a>inherit_host_path |  If true, appends the host PATH after the staged Bun runtime tool bin and `node_modules/.bin` entries at runtime.   | Boolean | optional |  `False`  |
| <a id="bun_script-no_env_file"></a>no_env_file |  If true, disables Bun's automatic `.env` loading.   | Boolean | optional |  `False`  |
| <a id="bun_script-no_exit_on_error"></a>no_exit_on_error |  If true, Bun keeps running other workspace scripts when one fails.   | Boolean | optional |  `False`  |
| <a id="bun_script-node_modules"></a>node_modules |  Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, in runfiles. The staged Bun runtime tool bin and executables from `node_modules/.bin` are added to `PATH`, which is useful for scripts such as `vite`.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="bun_script-package_json"></a>package_json |  Label of the `package.json` file containing the named script.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="bun_script-preload"></a>preload |  Modules to preload with `--preload` before running the script.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_script-run_flags"></a>run_flags |  Additional raw flags forwarded to `bun run` before the script name.   | List of strings | optional |  `[]`  |
| <a id="bun_script-script"></a>script |  Name of the `package.json` script to execute via `bun run <script>`.   | String | required |  |
| <a id="bun_script-shell"></a>shell |  Optional shell implementation for package scripts.   | String | optional |  `""`  |
| <a id="bun_script-silent"></a>silent |  If true, suppresses Bun's command echo for package scripts.   | Boolean | optional |  `False`  |
| <a id="bun_script-smol"></a>smol |  If true, enables Bun's lower-memory runtime mode.   | Boolean | optional |  `False`  |
| <a id="bun_script-working_dir"></a>working_dir |  Working directory at runtime: Bazel runfiles `workspace` root or the directory containing `package.json`. The default `package` mode matches tools such as Vite that resolve config and assets relative to the package directory.   | String | optional |  `"package"`  |
| <a id="bun_script-workspaces"></a>workspaces |  If true, runs the script in all workspace packages.   | Boolean | optional |  `False`  |


<a id="bun_test"></a>

## bun_test

<pre>
load("@rules_bun//bun:defs.bzl", "bun_test")

bun_test(<a href="#bun_test-name">name</a>, <a href="#bun_test-deps">deps</a>, <a href="#bun_test-srcs">srcs</a>, <a href="#bun_test-data">data</a>, <a href="#bun_test-bail">bail</a>, <a href="#bun_test-concurrent">concurrent</a>, <a href="#bun_test-coverage">coverage</a>, <a href="#bun_test-coverage_reporters">coverage_reporters</a>, <a href="#bun_test-env_files">env_files</a>,
         <a href="#bun_test-install_mode">install_mode</a>, <a href="#bun_test-max_concurrency">max_concurrency</a>, <a href="#bun_test-no_env_file">no_env_file</a>, <a href="#bun_test-node_modules">node_modules</a>, <a href="#bun_test-only">only</a>, <a href="#bun_test-pass_with_no_tests">pass_with_no_tests</a>, <a href="#bun_test-preload">preload</a>,
         <a href="#bun_test-randomize">randomize</a>, <a href="#bun_test-reporter">reporter</a>, <a href="#bun_test-rerun_each">rerun_each</a>, <a href="#bun_test-retry">retry</a>, <a href="#bun_test-seed">seed</a>, <a href="#bun_test-smol">smol</a>, <a href="#bun_test-test_flags">test_flags</a>, <a href="#bun_test-timeout_ms">timeout_ms</a>, <a href="#bun_test-todo">todo</a>,
         <a href="#bun_test-update_snapshots">update_snapshots</a>)
</pre>

Runs Bun tests as a Bazel test target.

Supports Bazel test filtering (`--test_filter`) and coverage integration.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="bun_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="bun_test-deps"></a>deps |  Library dependencies required by test sources.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_test-srcs"></a>srcs |  Test source files passed to `bun test`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="bun_test-data"></a>data |  Additional runtime files needed by tests.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_test-bail"></a>bail |  Optional failure count after which Bun exits the test run.   | Integer | optional |  `0`  |
| <a id="bun_test-concurrent"></a>concurrent |  If true, treats all tests as concurrent tests.   | Boolean | optional |  `False`  |
| <a id="bun_test-coverage"></a>coverage |  If true, always enables Bun coverage output.   | Boolean | optional |  `False`  |
| <a id="bun_test-coverage_reporters"></a>coverage_reporters |  Repeated Bun coverage reporters such as `text` or `lcov`.   | List of strings | optional |  `[]`  |
| <a id="bun_test-env_files"></a>env_files |  Additional environment files loaded with `--env-file`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_test-install_mode"></a>install_mode |  Whether Bun may auto-install missing packages while testing. Hermetic tests require `\"disable\"`, and other values are rejected.   | String | optional |  `"disable"`  |
| <a id="bun_test-inherit_host_path"></a>inherit_host_path |  If true, appends the host PATH after the staged Bun runtime tool bin and `node_modules/.bin` entries at runtime.   | Boolean | optional |  `False`  |
| <a id="bun_test-max_concurrency"></a>max_concurrency |  Optional maximum number of concurrent tests.   | Integer | optional |  `0`  |
| <a id="bun_test-no_env_file"></a>no_env_file |  If true, disables Bun's automatic `.env` loading.   | Boolean | optional |  `False`  |
| <a id="bun_test-node_modules"></a>node_modules |  Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, in runfiles.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="bun_test-only"></a>only |  If true, runs only tests marked with `test.only()` or `describe.only()`.   | Boolean | optional |  `False`  |
| <a id="bun_test-pass_with_no_tests"></a>pass_with_no_tests |  If true, exits successfully when no tests are found.   | Boolean | optional |  `False`  |
| <a id="bun_test-preload"></a>preload |  Modules to preload with `--preload` before running tests.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="bun_test-randomize"></a>randomize |  If true, runs tests in random order.   | Boolean | optional |  `False`  |
| <a id="bun_test-reporter"></a>reporter |  Test reporter format.   | String | optional |  `"console"`  |
| <a id="bun_test-rerun_each"></a>rerun_each |  Optional number of times to rerun each test file.   | Integer | optional |  `0`  |
| <a id="bun_test-retry"></a>retry |  Optional default retry count for all tests.   | Integer | optional |  `0`  |
| <a id="bun_test-seed"></a>seed |  Optional randomization seed.   | Integer | optional |  `0`  |
| <a id="bun_test-smol"></a>smol |  If true, enables Bun's lower-memory runtime mode.   | Boolean | optional |  `False`  |
| <a id="bun_test-test_flags"></a>test_flags |  Additional raw flags forwarded to `bun test` before the test source list.   | List of strings | optional |  `[]`  |
| <a id="bun_test-timeout_ms"></a>timeout_ms |  Optional per-test timeout in milliseconds.   | Integer | optional |  `0`  |
| <a id="bun_test-todo"></a>todo |  If true, includes tests marked with `test.todo()`.   | Boolean | optional |  `False`  |
| <a id="bun_test-update_snapshots"></a>update_snapshots |  If true, updates Bun snapshot files.   | Boolean | optional |  `False`  |


<a id="js_library"></a>

## js_library

<pre>
load("@rules_bun//bun:defs.bzl", "js_library")

js_library(<a href="#js_library-name">name</a>, <a href="#js_library-deps">deps</a>, <a href="#js_library-srcs">srcs</a>, <a href="#js_library-data">data</a>, <a href="#js_library-types">types</a>)
</pre>

Aggregates JavaScript sources and transitive Bun source dependencies.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="js_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="js_library-deps"></a>deps |  Other Bun source libraries to include transitively.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="js_library-srcs"></a>srcs |  JavaScript source files in this library.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="js_library-data"></a>data |  Optional runtime files propagated to dependents.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="js_library-types"></a>types |  Optional declaration files associated with this library.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="js_run_devserver"></a>

## js_run_devserver

<pre>
load("@rules_bun//bun:defs.bzl", "js_run_devserver")

js_run_devserver(<a href="#js_run_devserver-name">name</a>, <a href="#js_run_devserver-deps">deps</a>, <a href="#js_run_devserver-data">data</a>, <a href="#js_run_devserver-node_modules">node_modules</a>, <a href="#js_run_devserver-package_dir_hint">package_dir_hint</a>, <a href="#js_run_devserver-package_json">package_json</a>, <a href="#js_run_devserver-tool">tool</a>, <a href="#js_run_devserver-working_dir">working_dir</a>)
</pre>

Runs an executable target from a staged JS workspace.

This is a Bun-backed compatibility adapter for `rules_js`-style devserver
targets. It stages the same runtime workspace as the Bun rules, then executes
the provided tool with any default arguments.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="js_run_devserver-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="js_run_devserver-deps"></a>deps |  Library dependencies required by the dev server.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="js_run_devserver-data"></a>data |  Additional runtime files required by the dev server.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="js_run_devserver-node_modules"></a>node_modules |  Optional label providing package files from a node_modules tree, typically produced by bun_install or npm_translate_lock, in runfiles.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="js_run_devserver-package_dir_hint"></a>package_dir_hint |  Optional package-relative directory hint when package_json is not supplied.   | String | optional |  `"."`  |
| <a id="js_run_devserver-package_json"></a>package_json |  Optional package.json used to resolve the package working directory.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="js_run_devserver-tool"></a>tool |  Executable target to launch as the dev server.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="js_run_devserver-inherit_host_path"></a>inherit_host_path |  If true, appends the host PATH after the staged Bun runtime tool bin and `node_modules/.bin` entries at runtime.   | Boolean | optional |  `False`  |
| <a id="js_run_devserver-working_dir"></a>working_dir |  Working directory at runtime: Bazel runfiles workspace root or the resolved package directory.   | String | optional |  `"workspace"`  |


<a id="ts_library"></a>

## ts_library

<pre>
load("@rules_bun//bun:defs.bzl", "ts_library")

ts_library(<a href="#ts_library-name">name</a>, <a href="#ts_library-deps">deps</a>, <a href="#ts_library-srcs">srcs</a>, <a href="#ts_library-data">data</a>, <a href="#ts_library-types">types</a>)
</pre>

Aggregates TypeScript sources and transitive Bun source dependencies.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="ts_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="ts_library-deps"></a>deps |  Other Bun source libraries to include transitively.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="ts_library-srcs"></a>srcs |  TypeScript source files in this library.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="ts_library-data"></a>data |  Optional runtime files propagated to dependents.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="ts_library-types"></a>types |  Optional declaration files associated with this library.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="js_binary"></a>

## js_binary

<pre>
load("@rules_bun//bun:defs.bzl", "js_binary")

js_binary(<a href="#js_binary-name">name</a>, <a href="#js_binary-kwargs">**kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="js_binary-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="js_binary-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |


<a id="js_test"></a>

## js_test

<pre>
load("@rules_bun//bun:defs.bzl", "js_test")

js_test(<a href="#js_test-name">name</a>, <a href="#js_test-entry_point">entry_point</a>, <a href="#js_test-srcs">srcs</a>, <a href="#js_test-kwargs">**kwargs</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="js_test-name"></a>name |  <p align="center"> - </p>   |  none |
| <a id="js_test-entry_point"></a>entry_point |  <p align="center"> - </p>   |  `None` |
| <a id="js_test-srcs"></a>srcs |  <p align="center"> - </p>   |  `None` |
| <a id="js_test-kwargs"></a>kwargs |  <p align="center"> - </p>   |  none |
