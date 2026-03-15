import { spawn } from "node:child_process";
import {
  copyFileSync,
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  readlinkSync,
  realpathSync,
  rmSync,
  statSync,
  symlinkSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, dirname, join, posix, relative, resolve } from "node:path";

const IS_WINDOWS = process.platform === "win32";

function fail(message) {
  throw new Error(message);
}

function normalizeRel(value) {
  if (!value || value === ".") {
    return ".";
  }
  const normalized = posix.normalize(String(value).replace(/\\/g, "/")).replace(/^\.\/+/, "");
  if (!normalized || normalized === ".") {
    return ".";
  }
  if (normalized.startsWith("../")) {
    fail(`rules_bun: invalid relative path ${value}`);
  }
  return normalized;
}

function resolveNodeModulesRootRunfilesPath(value, repoRoot) {
  const normalized = posix.normalize(String(value || ".").replace(/\\/g, "/")).replace(/^\.\/+/, "");
  if (!normalized || normalized === ".") {
    return repoRoot || ".";
  }
  if (repoRoot) {
    if (normalized === repoRoot || normalized.startsWith(`${repoRoot}/`)) {
      return normalized;
    }
    const externalRepoPrefix = `../${repoRoot}`;
    if (normalized === externalRepoPrefix) {
      return repoRoot;
    }
    if (normalized.startsWith(`${externalRepoPrefix}/`)) {
      return normalized.slice(3);
    }
  }
  const repoRelative = normalizeRel(normalized);
  return repoRoot ? (repoRelative === "." ? repoRoot : `${repoRoot}/${repoRelative}`) : repoRelative;
}

function dirnameRel(value) {
  const normalized = normalizeRel(value);
  if (normalized === ".") {
    return ".";
  }
  return normalizeRel(posix.dirname(normalized));
}

function firstPathComponent(value) {
  const normalized = normalizeRel(value);
  if (normalized === ".") {
    return "";
  }
  return normalized.split("/")[0];
}

function stripRelPrefix(child, parent) {
  const normalizedChild = normalizeRel(child);
  const normalizedParent = normalizeRel(parent);
  if (normalizedParent === ".") {
    return normalizedChild;
  }
  if (normalizedChild === normalizedParent) {
    return ".";
  }
  if (normalizedChild.startsWith(`${normalizedParent}/`)) {
    return normalizeRel(normalizedChild.slice(normalizedParent.length + 1));
  }
  return normalizedChild;
}

function splitManifestLine(line) {
  const delimiterIndex = line.indexOf(" ");
  if (delimiterIndex < 0) {
    return null;
  }
  return [line.slice(0, delimiterIndex), line.slice(delimiterIndex + 1)];
}

function detectRunfiles() {
  const launcherPath = process.env.RULES_BUN_LAUNCHER_PATH || "";
  let runfilesDir = process.env.RULES_BUN_RUNFILES_DIR || process.env.RUNFILES_DIR || "";
  let manifestFile =
    process.env.RULES_BUN_RUNFILES_MANIFEST || process.env.RUNFILES_MANIFEST_FILE || "";

  if (!runfilesDir && launcherPath) {
    const adjacentDir = `${launcherPath}.runfiles`;
    if (existsSync(adjacentDir)) {
      runfilesDir = adjacentDir;
    }
  }
  if (!manifestFile && launcherPath) {
    const candidates = [`${launcherPath}.runfiles_manifest`, `${launcherPath}.exe.runfiles_manifest`];
    for (const candidate of candidates) {
      if (existsSync(candidate)) {
        manifestFile = candidate;
        break;
      }
    }
  }
  if (!runfilesDir && !manifestFile) {
    fail("rules_bun: unable to locate runfiles");
  }

  let manifestMap = null;
  let manifestDirs = null;
  let manifestChildren = null;
  if (manifestFile) {
    manifestMap = new Map();
    manifestDirs = new Set();
    manifestChildren = new Map();
    const lines = readFileSync(manifestFile, "utf8").split(/\r?\n/);
    for (const line of lines) {
      if (!line) {
        continue;
      }
      const entry = splitManifestLine(line);
      if (!entry) {
        continue;
      }
      const [runfilesPath, actualPath] = entry;
      manifestMap.set(runfilesPath, actualPath);
      const parts = runfilesPath.split("/");
      let parent = ".";
      for (let index = 0; index < parts.length; index += 1) {
        const part = parts[index];
        let children = manifestChildren.get(parent);
        if (!children) {
          children = new Set();
          manifestChildren.set(parent, children);
        }
        children.add(part);
        const current = parent === "." ? part : `${parent}/${part}`;
        if (index < parts.length - 1) {
          manifestDirs.add(current);
        }
        parent = current;
      }
    }
  }

  function rlocation(runfilesPath) {
    const normalized = String(runfilesPath).replace(/\\/g, "/");
    if (runfilesDir) {
      return resolve(runfilesDir, normalized);
    }
    const resolved = manifestMap.get(normalized);
    if (!resolved) {
      fail(`rules_bun: missing runfile ${normalized}`);
    }
    return resolved;
  }

  function exists(runfilesPath) {
    const normalized = String(runfilesPath).replace(/\\/g, "/");
    if (runfilesDir) {
      return existsSync(resolve(runfilesDir, normalized));
    }
    return manifestMap.has(normalized) || manifestDirs.has(normalized);
  }

  function isDir(runfilesPath) {
    const normalized = String(runfilesPath).replace(/\\/g, "/");
    if (runfilesDir) {
      const target = resolve(runfilesDir, normalized);
      if (!existsSync(target)) {
        return false;
      }
      return statSync(target).isDirectory();
    }
    return manifestDirs.has(normalized);
  }

  function listChildren(runfilesPath) {
    const normalized = runfilesPath ? String(runfilesPath).replace(/\\/g, "/") : ".";
    if (runfilesDir) {
      const target = normalized === "." ? runfilesDir : resolve(runfilesDir, normalized);
      if (!existsSync(target) || !statSync(target).isDirectory()) {
        return [];
      }
      return readdirSync(target).sort();
    }
    return Array.from(manifestChildren.get(normalized) || []).sort();
  }

  function directoryIdentity(runfilesPath) {
    if (!runfilesDir) {
      return String(runfilesPath).replace(/\\/g, "/");
    }
    return realpathSync(rlocation(runfilesPath));
  }

  return {
    manifestMap,
    manifestFile,
    runfilesDir,
    exists,
    isDir,
    listChildren,
    directoryIdentity,
    rlocation,
  };
}

function workspaceRunfilesPath(relPath) {
  const normalized = normalizeRel(relPath);
  if (normalized === ".") {
    return "_main";
  }
  return `_main/${normalized}`;
}

function stripWorkspacePrefix(runfilesPath) {
  if (!runfilesPath) {
    return "";
  }
  if (runfilesPath === "_main") {
    return ".";
  }
  if (runfilesPath.startsWith("_main/")) {
    return normalizeRel(runfilesPath.slice("_main/".length));
  }
  return "";
}

function createWorkspaceSource(runfiles) {
  if (runfiles.runfilesDir && runfiles.isDir("_main")) {
    const workspaceRoot = runfiles.rlocation("_main");
    return {
      type: "dir",
      workspaceRoot,
      exists(relPath) {
        return existsSync(resolve(workspaceRoot, normalizeRel(relPath)));
      },
      isFile(relPath) {
        const target = resolve(workspaceRoot, normalizeRel(relPath));
        return existsSync(target) && statSync(target).isFile();
      },
      isDir(relPath) {
        const target = resolve(workspaceRoot, normalizeRel(relPath));
        return existsSync(target) && statSync(target).isDirectory();
      },
      listChildren(relPath) {
        const normalized = normalizeRel(relPath);
        const target = normalized === "." ? workspaceRoot : resolve(workspaceRoot, normalized);
        if (!existsSync(target) || !statSync(target).isDirectory()) {
          return [];
        }
        return readdirSync(target).sort();
      },
      actualFile(relPath) {
        const normalized = normalizeRel(relPath);
        return normalized === "." ? workspaceRoot : resolve(workspaceRoot, normalized);
      },
    };
  }

  const fileMap = new Map();
  const dirSet = new Set(["."]);
  const children = new Map();

  for (const [runfilesPath, actualPath] of runfiles.manifestMap.entries()) {
    if (!runfilesPath.startsWith("_main/")) {
      continue;
    }
    const relPath = normalizeRel(runfilesPath.slice("_main/".length));
    fileMap.set(relPath, actualPath);
    const parts = relPath.split("/");
    let parent = ".";
    for (let index = 0; index < parts.length; index += 1) {
      const part = parts[index];
      let childrenForParent = children.get(parent);
      if (!childrenForParent) {
        childrenForParent = new Set();
        children.set(parent, childrenForParent);
      }
      childrenForParent.add(part);
      const current = parent === "." ? part : `${parent}/${part}`;
      if (index < parts.length - 1) {
        dirSet.add(current);
      }
      parent = current;
    }
  }

  return {
    type: "manifest",
    exists(relPath) {
      const normalized = normalizeRel(relPath);
      return fileMap.has(normalized) || dirSet.has(normalized);
    },
    isFile(relPath) {
      return fileMap.has(normalizeRel(relPath));
    },
    isDir(relPath) {
      return dirSet.has(normalizeRel(relPath));
    },
    listChildren(relPath) {
      return Array.from(children.get(normalizeRel(relPath)) || []).sort();
    },
    actualFile(relPath) {
      return fileMap.get(normalizeRel(relPath)) || "";
    },
    fileMap,
  };
}

function findPackageRelDirForPath(source, relPath) {
  let current = normalizeRel(relPath);
  if (source.isFile(current)) {
    current = dirnameRel(current);
  }

  while (true) {
    if (source.isFile(current === "." ? "package.json" : `${current}/package.json`)) {
      return current;
    }
    if (current === ".") {
      break;
    }
    current = dirnameRel(current);
  }

  return dirnameRel(relPath);
}

function findWorkingRelDirForPath(source, relPath) {
  let current = normalizeRel(relPath);
  if (source.isFile(current)) {
    current = dirnameRel(current);
  }

  while (true) {
    const envPath = current === "." ? ".env" : `${current}/.env`;
    const manifestPath = current === "." ? "package.json" : `${current}/package.json`;
    if (source.isFile(envPath) || source.isFile(manifestPath)) {
      return current;
    }
    if (current === ".") {
      break;
    }
    current = dirnameRel(current);
  }

  return dirnameRel(relPath);
}

function resolvePackageRelDir(spec, source) {
  if (spec.package_dir_hint && spec.package_dir_hint !== ".") {
    return normalizeRel(spec.package_dir_hint);
  }
  const packageJsonRel = stripWorkspacePrefix(spec.package_json_short_path || "");
  if (packageJsonRel) {
    return findPackageRelDirForPath(source, packageJsonRel);
  }
  const primaryRel = stripWorkspacePrefix(spec.primary_source_short_path || "");
  if (primaryRel) {
    return findPackageRelDirForPath(source, primaryRel);
  }
  return ".";
}

function resolveExecutionRelDir(spec, packageRelDir, source) {
  switch (spec.working_dir_mode) {
    case "workspace":
      return ".";
    case "package":
      return packageRelDir;
    case "entry_point": {
      const primaryRel = stripWorkspacePrefix(spec.primary_source_short_path || "");
      if (primaryRel) {
        return findWorkingRelDirForPath(source, primaryRel);
      }
      return packageRelDir;
    }
    default:
      return packageRelDir;
  }
}

function resolveInstallRootRelDir(spec, packageRelDir, runfiles) {
  const installMetadataPath =
    spec.install_metadata_short_path && runfiles.exists(spec.install_metadata_short_path)
      ? runfiles.rlocation(spec.install_metadata_short_path)
      : "";
  if (installMetadataPath && existsSync(installMetadataPath)) {
    try {
      const metadata = JSON.parse(readFileSync(installMetadataPath, "utf8"));
      const normalizedPackageRelDir = packageRelDir === "." ? "." : packageRelDir.replace(/^\.\/+/, "");
      const matches = [];
      for (const workspacePackageDir of metadata.workspace_package_dirs || []) {
        const normalizedWorkspaceDir = normalizeRel(workspacePackageDir);
        if (normalizedWorkspaceDir === ".") {
          continue;
        }
        if (normalizedPackageRelDir === normalizedWorkspaceDir) {
          matches.push([normalizedWorkspaceDir.length, "."]);
          continue;
        }
        const suffix = `/${normalizedWorkspaceDir}`;
        if (normalizedPackageRelDir.endsWith(suffix)) {
          const prefix = normalizedPackageRelDir.slice(0, -suffix.length).replace(/^\/+|\/+$/g, "");
          matches.push([normalizedWorkspaceDir.length, prefix || "."]);
        }
      }
      if (matches.length > 0) {
        matches.sort((left, right) => right[0] - left[0]);
        return normalizeRel(matches[0][1]);
      }
    } catch {}
  }

  const packageJsonRel = stripWorkspacePrefix(spec.package_json_short_path || "");
  if (packageJsonRel) {
    return findPackageRelDirForPath(createWorkspaceSource(runfiles), packageJsonRel);
  }
  const primaryRel = stripWorkspacePrefix(spec.primary_source_short_path || "");
  if (primaryRel) {
    return findPackageRelDirForPath(createWorkspaceSource(runfiles), primaryRel);
  }
  return ".";
}

function removePath(targetPath) {
  rmSync(targetPath, { force: true, recursive: true });
}

function ensureDir(targetPath) {
  mkdirSync(targetPath, { recursive: true });
}

function linkPath(sourcePath, destinationPath) {
  removePath(destinationPath);
  ensureDir(dirname(destinationPath));
  const sourceStats = lstatSync(sourcePath);
  if (sourceStats.isSymbolicLink()) {
    symlinkSync(readlinkSync(sourcePath), destinationPath);
    return;
  }
  symlinkSync(sourcePath, destinationPath);
}

function copyPath(sourcePath, destinationPath) {
  removePath(destinationPath);
  ensureDir(dirname(destinationPath));
  const resolvedStats = statSync(sourcePath);
  if (resolvedStats.isDirectory()) {
    cpSync(sourcePath, destinationPath, { dereference: true, force: true, recursive: true });
  } else {
    copyFileSync(sourcePath, destinationPath);
  }
}

function materializePath(sourcePath, destinationPath, preferLinks) {
  if (preferLinks && !IS_WINDOWS) {
    linkPath(sourcePath, destinationPath);
  } else {
    copyPath(sourcePath, destinationPath);
  }
}

function materializeTreeContents(sourceRoot, destinationRoot) {
  removePath(destinationRoot);
  ensureDir(destinationRoot);
  for (const entry of readdirSync(sourceRoot)) {
    const sourcePath = join(sourceRoot, entry);
    const destinationPath = join(destinationRoot, entry);
    copyPath(sourcePath, destinationPath);
  }
}

function stageRuntimeToolAlias(sourcePath, destinationPath, preferLinks) {
  removePath(destinationPath);
  ensureDir(dirname(destinationPath));
  if (preferLinks && !IS_WINDOWS) {
    symlinkSync(sourcePath, destinationPath);
    return;
  }
  copyPath(sourcePath, destinationPath);
}

function stageRuntimeToolBin(runtimeWorkspace, bunPath, preferLinks) {
  const runtimeToolBin = join(runtimeWorkspace, ".rules_bun", "bin");
  ensureDir(runtimeToolBin);

  const bunName = IS_WINDOWS ? "bun.exe" : "bun";
  const stagedBunPath = join(runtimeToolBin, bunName);
  materializePath(realpathSync(bunPath), stagedBunPath, preferLinks);

  for (const aliasName of IS_WINDOWS ? ["bunx.exe", "node.exe"] : ["bunx", "node"]) {
    stageRuntimeToolAlias(stagedBunPath, join(runtimeToolBin, aliasName), preferLinks);
  }

  return runtimeToolBin;
}

function stageWorkspaceView(sourceRoot, destinationRoot, packageRelDir) {
  ensureDir(destinationRoot);
  const skippedEntry = firstPathComponent(packageRelDir);
  for (const entry of readdirSync(sourceRoot)) {
    if (entry === skippedEntry) {
      continue;
    }
    materializePath(join(sourceRoot, entry), join(destinationRoot, entry), true);
  }

  if (packageRelDir === ".") {
    return;
  }

  const parts = packageRelDir.split("/");
  let sourceCursor = sourceRoot;
  let destinationCursor = destinationRoot;
  for (let index = 0; index < parts.length - 1; index += 1) {
    const part = parts[index];
    const nextPart = parts[index + 1];
    sourceCursor = join(sourceCursor, part);
    destinationCursor = join(destinationCursor, part);
    ensureDir(destinationCursor);
    for (const sibling of readdirSync(sourceCursor)) {
      if (sibling === nextPart) {
        continue;
      }
      const siblingPath = join(destinationCursor, sibling);
      if (existsSync(siblingPath)) {
        continue;
      }
      materializePath(join(sourceCursor, sibling), siblingPath, true);
    }
  }

  const packageDestination = join(destinationRoot, packageRelDir);
  ensureDir(packageDestination);
  for (const entry of readdirSync(join(sourceRoot, packageRelDir))) {
    materializePath(join(sourceRoot, packageRelDir, entry), join(packageDestination, entry), true);
  }
}

function materializeWorkspaceFromManifest(source, destinationRoot) {
  ensureDir(destinationRoot);
  for (const [relPath, actualPath] of source.fileMap.entries()) {
    copyPath(actualPath, join(destinationRoot, relPath));
  }
}

function buildWorkspacePackageMap(workspaceRoot) {
  const packageMap = new Map();

  function walk(currentDir, relDir) {
    const entries = readdirSync(currentDir, { withFileTypes: true });
    const hasPackageJson = entries.some((entry) => entry.isFile() && entry.name === "package.json");
    if (hasPackageJson) {
      const manifestPath = join(currentDir, "package.json");
      try {
        const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
        if (typeof manifest.name === "string" && manifest.name) {
          packageMap.set(manifest.name, relDir || ".");
        }
      } catch {}
    }

    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name === "node_modules") {
        continue;
      }
      walk(join(currentDir, entry.name), relDir ? `${relDir}/${entry.name}` : entry.name);
    }
  }

  walk(workspaceRoot, "");
  return packageMap;
}

function readInstallMetadata(spec, runfiles) {
  if (!spec.install_metadata_short_path || !runfiles.exists(spec.install_metadata_short_path)) {
    return null;
  }
  try {
    return JSON.parse(readFileSync(runfiles.rlocation(spec.install_metadata_short_path), "utf8"));
  } catch {
    return null;
  }
}

function workspacePackageMapFromInstallMetadata(installMetadata, installRootRelDir) {
  const packageMap = new Map();
  const packagesByDir = installMetadata?.workspace_package_names_by_dir || {};
  for (const [workspaceDir, packageName] of Object.entries(packagesByDir)) {
    if (typeof packageName !== "string" || !packageName) {
      continue;
    }
    const normalizedWorkspaceDir = normalizeRel(workspaceDir);
    const rootedWorkspaceDir =
      installRootRelDir && installRootRelDir !== "."
        ? normalizeRel(join(installRootRelDir, normalizedWorkspaceDir).replace(/\\/g, "/"))
        : normalizedWorkspaceDir;
    packageMap.set(packageName, rootedWorkspaceDir);
  }
  return packageMap;
}

function findNodeModulesRoots(spec, runfiles) {
  const repoRoot = spec.install_repo_runfiles_path || "";
  const results = [];
  for (const relativeRoot of spec.node_modules_roots || []) {
    const runfilesPath = resolveNodeModulesRootRunfilesPath(relativeRoot, repoRoot);
    if (runfiles.isDir(runfilesPath)) {
      results.push(runfilesPath);
    }
  }
  return results.sort((left, right) => left.length - right.length || left.localeCompare(right));
}

function selectPrimaryNodeModules(roots) {
  return roots[0] || "";
}

function readPackageNameFromRunfilesEntry(runfiles, entryRunfilesPath) {
  const packageJsonPath = `${entryRunfilesPath}/package.json`;
  if (!runfiles.exists(packageJsonPath)) {
    return "";
  }
  try {
    const manifest = JSON.parse(readFileSync(runfiles.rlocation(packageJsonPath), "utf8"));
    return typeof manifest.name === "string" ? manifest.name : "";
  } catch {
    return "";
  }
}

function materializeRunfilesSubtree(runfiles, prefix, destinationPath) {
  if (runfiles.runfilesDir && existsSync(runfiles.rlocation(prefix))) {
    copyPath(runfiles.rlocation(prefix), destinationPath);
    return;
  }

  const normalizedPrefix = prefix.replace(/\\/g, "/");
  let copied = false;
  for (const [runfilesPath, actualPath] of runfiles.manifestMap.entries()) {
    if (runfilesPath === normalizedPrefix) {
      copyPath(actualPath, destinationPath);
      copied = true;
      break;
    }
    if (!runfilesPath.startsWith(`${normalizedPrefix}/`)) {
      continue;
    }
    const relPath = runfilesPath.slice(normalizedPrefix.length + 1);
    copyPath(actualPath, join(destinationPath, relPath));
    copied = true;
  }
  if (!copied) {
    removePath(destinationPath);
  }
}

function materializeNodeModulesEntry(
  runfiles,
  sourceRunfilesPath,
  destinationPath,
  workspacePackageMap,
  runtimeWorkspace,
  preferLinks,
) {
  const packageName = readPackageNameFromRunfilesEntry(runfiles, sourceRunfilesPath);
  const workspaceRelDir = packageName ? workspacePackageMap.get(packageName) || "" : "";
  if (workspaceRelDir) {
    const workspaceSourcePath = join(runtimeWorkspace, workspaceRelDir);
    if (existsSync(workspaceSourcePath)) {
      materializePath(workspaceSourcePath, destinationPath, preferLinks);
      return;
    }
  }

  if (runfiles.runfilesDir && existsSync(runfiles.rlocation(sourceRunfilesPath))) {
    materializePath(runfiles.rlocation(sourceRunfilesPath), destinationPath, preferLinks);
    return;
  }

  materializeRunfilesSubtree(runfiles, sourceRunfilesPath, destinationPath);
}

function mirrorNodeModulesDir(
  runfiles,
  sourceNodeModulesRunfilesPath,
  destinationDir,
  workspacePackageMap,
  runtimeWorkspace,
  preferLinks,
) {
  removePath(destinationDir);
  ensureDir(destinationDir);
  for (const entry of runfiles.listChildren(sourceNodeModulesRunfilesPath)) {
    if (entry === ".rules_bun") {
      continue;
    }
    const entryRunfilesPath = `${sourceNodeModulesRunfilesPath}/${entry}`;
    if (entry.startsWith("@") && runfiles.isDir(entryRunfilesPath)) {
      ensureDir(join(destinationDir, entry));
      for (const scopedEntry of runfiles.listChildren(entryRunfilesPath)) {
        materializeNodeModulesEntry(
          runfiles,
          `${entryRunfilesPath}/${scopedEntry}`,
          join(destinationDir, entry, scopedEntry),
          workspacePackageMap,
          runtimeWorkspace,
          preferLinks,
        );
      }
      continue;
    }
    materializeNodeModulesEntry(
      runfiles,
      entryRunfilesPath,
      join(destinationDir, entry),
      workspacePackageMap,
      runtimeWorkspace,
      preferLinks,
    );
  }
}

function findInstallRepoNodeModules(runfiles, repoRootRunfilesPath, packageRelDir) {
  if (packageRelDir !== ".") {
    let candidate = packageRelDir;
    while (true) {
      const candidateRunfilesPath = `${repoRootRunfilesPath}/${candidate}/node_modules`;
      if (runfiles.isDir(candidateRunfilesPath)) {
        return candidateRunfilesPath;
      }
      if (!candidate.includes("/")) {
        break;
      }
      candidate = dirnameRel(candidate);
    }
  }

  const rootNodeModules = `${repoRootRunfilesPath}/node_modules`;
  if (runfiles.isDir(rootNodeModules)) {
    return rootNodeModules;
  }
  return "";
}

function mirrorInstallRepoWorkspaceNodeModules(
  runfiles,
  nodeModulesRoots,
  repoRootRunfilesPath,
  destinationRoot,
  workspacePackageMap,
  runtimeWorkspace,
  preferLinks,
) {
  for (const nodeModulesRunfilesPath of nodeModulesRoots) {
    if (nodeModulesRunfilesPath === `${repoRootRunfilesPath}/node_modules`) {
      continue;
    }
    if (!nodeModulesRunfilesPath.startsWith(`${repoRootRunfilesPath}/`)) {
      continue;
    }
    const relPath = nodeModulesRunfilesPath.slice(repoRootRunfilesPath.length + 1);
    mirrorNodeModulesDir(
      runfiles,
      nodeModulesRunfilesPath,
      join(destinationRoot, relPath),
      workspacePackageMap,
      runtimeWorkspace,
      preferLinks,
    );
  }
}

function buildRuntimePath(
  runtimeToolBin,
  runtimeWorkspace,
  runtimePackageDir,
  runtimeInstallRoot,
  inheritHostPath,
) {
  const entries = [];

  if (existsSync(runtimeToolBin) && statSync(runtimeToolBin).isDirectory()) {
    entries.push(runtimeToolBin);
  }

  const installBin = join(runtimeInstallRoot, "node_modules", ".bin");
  const packageBin = join(runtimePackageDir, "node_modules", ".bin");
  const workspaceBin = join(runtimeWorkspace, "node_modules", ".bin");

  if (existsSync(installBin) && statSync(installBin).isDirectory()) {
    entries.push(installBin);
  }
  if (
    existsSync(packageBin) &&
    statSync(packageBin).isDirectory() &&
    packageBin !== installBin
  ) {
    entries.push(packageBin);
  }
  if (
    existsSync(workspaceBin) &&
    statSync(workspaceBin).isDirectory() &&
    workspaceBin !== packageBin &&
    workspaceBin !== installBin
  ) {
    entries.push(workspaceBin);
  }

  if (inheritHostPath && process.env.PATH) {
    entries.push(process.env.PATH);
  }
  return entries.join(delimiter);
}

function pathEnvKey(env) {
  for (const key of Object.keys(env)) {
    if (key.toUpperCase() === "PATH") {
      return key;
    }
  }
  return "PATH";
}

function runtimePathForRunfile(runfiles, runtimeWorkspace, runfilesPath) {
  if (!runfilesPath) {
    return "";
  }
  const workspaceRel = stripWorkspacePrefix(runfilesPath);
  if (workspaceRel) {
    return workspaceRel === "." ? runtimeWorkspace : join(runtimeWorkspace, workspaceRel);
  }
  return runfiles.rlocation(runfilesPath);
}

function createRuntime(spec, runfiles) {
  const source = createWorkspaceSource(runfiles);
  const packageRelDir = resolvePackageRelDir(spec, source);
  const executionRelDir = resolveExecutionRelDir(spec, packageRelDir, source);
  const installRootRelDir = resolveInstallRootRelDir(spec, packageRelDir, runfiles);
  const packageRelDirInInstallRoot = stripRelPrefix(packageRelDir, installRootRelDir);
  const installMetadata = readInstallMetadata(spec, runfiles);
  const runtimeWorkspace = mkdtempSync(join(tmpdir(), "rules_bun_runtime-"));
  const preferLinks = source.type === "dir" && !IS_WINDOWS;

  if (source.type === "dir") {
    stageWorkspaceView(source.workspaceRoot, runtimeWorkspace, packageRelDir);
  } else {
    materializeWorkspaceFromManifest(source, runtimeWorkspace);
  }

  const runtimePackageDir =
    packageRelDir === "." ? runtimeWorkspace : join(runtimeWorkspace, packageRelDir);
  const runtimeInstallRoot =
    installRootRelDir === "." ? runtimeWorkspace : join(runtimeWorkspace, installRootRelDir);
  const runtimeExecDir =
    executionRelDir === "." ? runtimeWorkspace : join(runtimeWorkspace, executionRelDir);

  ensureDir(runtimePackageDir);
  ensureDir(runtimeInstallRoot);
  ensureDir(runtimeExecDir);

  const primaryRel = stripWorkspacePrefix(spec.primary_source_short_path || "");
  const packageJsonRel = stripWorkspacePrefix(spec.package_json_short_path || "");
  if (source.type === "dir" && primaryRel) {
    materializeTreeContents(source.actualFile(packageRelDir), runtimePackageDir);
  }
  if (source.type === "dir" && packageJsonRel) {
    materializeTreeContents(source.actualFile(installRootRelDir), runtimeInstallRoot);
  }

  const workspacePackageMap = installMetadata
    ? workspacePackageMapFromInstallMetadata(installMetadata, installRootRelDir)
    : buildWorkspacePackageMap(runtimeWorkspace);
  const nodeModulesRoots = findNodeModulesRoots(spec, runfiles);
  const primaryNodeModules = selectPrimaryNodeModules(nodeModulesRoots);

  let installRepoRoot = spec.install_repo_runfiles_path || "";
  if (primaryNodeModules) {
    if (!installRepoRoot) {
      installRepoRoot = posix.dirname(primaryNodeModules);
    }
    ensureDir(runtimeInstallRoot);
    mirrorNodeModulesDir(
      runfiles,
      primaryNodeModules,
      join(runtimeInstallRoot, "node_modules"),
      workspacePackageMap,
      runtimeWorkspace,
      preferLinks,
    );
  }

  if (installRepoRoot) {
    const resolvedInstallNodeModules = findInstallRepoNodeModules(
      runfiles,
      installRepoRoot,
      packageRelDirInInstallRoot,
    );
    if (
      resolvedInstallNodeModules &&
      resolvedInstallNodeModules !== `${installRepoRoot}/node_modules`
    ) {
      mirrorNodeModulesDir(
        runfiles,
        resolvedInstallNodeModules,
        join(runtimePackageDir, "node_modules"),
        workspacePackageMap,
        runtimeWorkspace,
        preferLinks,
      );
    }
    mirrorInstallRepoWorkspaceNodeModules(
      runfiles,
      nodeModulesRoots,
      installRepoRoot,
      runtimeInstallRoot,
      workspacePackageMap,
      runtimeWorkspace,
      preferLinks,
    );
  }

  const runtimeInstallNodeModules = join(runtimeInstallRoot, "node_modules");
  const runtimePackageNodeModules = join(runtimePackageDir, "node_modules");
  if (
    !existsSync(runtimePackageNodeModules) &&
    existsSync(runtimeInstallNodeModules) &&
    runtimeInstallNodeModules !== runtimePackageNodeModules
  ) {
    materializePath(runtimeInstallNodeModules, runtimePackageNodeModules, preferLinks);
  }

  const runtimeToolBin = stageRuntimeToolBin(
    runtimeWorkspace,
    runfiles.rlocation(spec.bun_short_path),
    preferLinks,
  );

  const env = { ...process.env };
  const pathKey = pathEnvKey(env);
  const runtimePath = buildRuntimePath(
    runtimeToolBin,
    runtimeWorkspace,
    runtimePackageDir,
    runtimeInstallRoot,
    Boolean(spec.inherit_host_path),
  );
  if (runtimePath || !spec.inherit_host_path) {
    env[pathKey] = runtimePath;
  }

  return {
    env,
    runtimeExecDir,
    runtimeInstallRoot,
    runtimePackageDir,
    runtimeWorkspace,
    cleanup() {
      removePath(runtimeWorkspace);
    },
  };
}

function composeBunArgs(spec, runfiles, runtime) {
  const args = [...(spec.argv || [])];

  for (const preloadPath of spec.preload_short_paths || []) {
    args.push("--preload", runtimePathForRunfile(runfiles, runtime.runtimeWorkspace, preloadPath));
  }
  for (const envFilePath of spec.env_file_short_paths || []) {
    args.push("--env-file", runtimePathForRunfile(runfiles, runtime.runtimeWorkspace, envFilePath));
  }

  if (spec.kind === "bun_test") {
    let coverageRequested = false;
    let coverageDir = "";
    if (process.env.COVERAGE_DIR) {
      coverageRequested = true;
      coverageDir = process.env.COVERAGE_DIR;
    } else if (spec.coverage) {
      coverageRequested = true;
      coverageDir = process.env.TEST_UNDECLARED_OUTPUTS_DIR || join(runtime.runtimeWorkspace, "coverage");
    }
    if (coverageRequested) {
      args.push("--coverage", "--coverage-dir", coverageDir);
      if ((spec.coverage_reporters || []).length > 0) {
        for (const reporter of spec.coverage_reporters) {
          args.push("--coverage-reporter", reporter);
        }
      } else if (process.env.COVERAGE_DIR) {
        args.push("--coverage-reporter", "lcov");
      }
    }

    if (process.env.TESTBRIDGE_TEST_ONLY) {
      args.push("--test-name-pattern", process.env.TESTBRIDGE_TEST_ONLY);
    }

    if (spec.reporter === "junit") {
      const reporterOut = process.env.XML_OUTPUT_FILE || join(runtime.runtimeWorkspace, "junit.xml");
      args.push("--reporter", "junit", "--reporter-outfile", reporterOut);
    } else if (spec.reporter === "dots") {
      args.push("--reporter", "dots");
    }

    for (const testPath of spec.test_short_paths || []) {
      args.push(runtimePathForRunfile(runfiles, runtime.runtimeWorkspace, testPath));
    }
  } else if (spec.primary_source_short_path) {
    args.push(runtimePathForRunfile(runfiles, runtime.runtimeWorkspace, spec.primary_source_short_path));
  }

  args.push(...(spec.args || []));
  return args;
}

function isWindowsBatchFile(command) {
  return IS_WINDOWS && /\.(cmd|bat)$/i.test(String(command || ""));
}

function quoteForWindowsShell(command) {
  return `"${String(command).replace(/"/g, '""')}"`;
}

function spawnChild(command, args, options) {
  const spawnOptions = {
    ...options,
    stdio: "inherit",
  };
  if (isWindowsBatchFile(command)) {
    return spawn(quoteForWindowsShell(command), args, {
      ...spawnOptions,
      shell: true,
    });
  }
  return spawn(command, args, spawnOptions);
}

function spawnProcess(command, args, options) {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawnChild(command, args, options);
    child.once("error", rejectPromise);
    child.once("exit", (code, signal) => {
      resolvePromise({ child, code, signal });
    });
  });
}

async function runBunOnce(spec, runfiles, extraBunArgs = []) {
  const runtime = createRuntime(spec, runfiles);
  try {
    const bunPath = runfiles.rlocation(spec.bun_short_path);
    const bunArgs = composeBunArgs(spec, runfiles, runtime);
    const result = await spawnProcess(bunPath, [...bunArgs, ...extraBunArgs], {
      cwd: runtime.runtimeExecDir,
      env: runtime.env,
    });
    return typeof result.code === "number" ? result.code : 1;
  } finally {
    runtime.cleanup();
  }
}

function fileMtime(filePath) {
  if (!filePath || !existsSync(filePath)) {
    return "missing";
  }
  return `${statSync(filePath).mtimeMs}`;
}

function sleep(ms) {
  return new Promise((resolvePromise) => {
    setTimeout(resolvePromise, ms);
  });
}

async function terminateChild(child) {
  if (!child || child.exitCode !== null) {
    return;
  }

  await new Promise((resolvePromise) => {
    let finished = false;
    const finalize = () => {
      if (finished) {
        return;
      }
      finished = true;
      resolvePromise();
    };

    child.once("exit", finalize);
    child.kill();
    setTimeout(() => {
      if (child.exitCode === null) {
        child.kill("SIGKILL");
      }
      finalize();
    }, 2000);
  });
}

async function runDevMode(spec, runfiles, userArgs) {
  const watchFlag = spec.watch_mode === "hot" ? "--hot" : "--watch";
  const restartPaths = (spec.restart_on || []).map((runfilesPath) => runfiles.rlocation(runfilesPath));
  const passthroughArgs = spec.passthrough_args ? userArgs : [];

  if (restartPaths.length === 0) {
    return runBunOnce(spec, runfiles, [watchFlag, ...passthroughArgs]);
  }

  let currentRuntime = null;
  let child = null;
  let exitPromise = null;
  let shuttingDown = false;

  const launch = () => {
    currentRuntime = createRuntime(spec, runfiles);
    const bunPath = runfiles.rlocation(spec.bun_short_path);
    const bunArgs = [...composeBunArgs(spec, runfiles, currentRuntime), watchFlag, ...passthroughArgs];
    child = spawnChild(bunPath, bunArgs, {
      cwd: currentRuntime.runtimeExecDir,
      env: currentRuntime.env,
    });
    exitPromise = new Promise((resolvePromise, rejectPromise) => {
      child.once("error", rejectPromise);
      child.once("exit", (code, signal) => resolvePromise({ code, signal }));
    });
  };

  const cleanup = async () => {
    shuttingDown = true;
    await terminateChild(child);
    if (currentRuntime) {
      currentRuntime.cleanup();
      currentRuntime = null;
    }
  };

  const signalHandler = async () => {
    await cleanup();
    process.exit(1);
  };
  process.once("SIGINT", signalHandler);
  process.once("SIGTERM", signalHandler);

  try {
    launch();
    const mtimes = new Map();
    for (const restartPath of restartPaths) {
      mtimes.set(restartPath, fileMtime(restartPath));
    }

    while (!shuttingDown) {
      const tick = sleep(1000).then(() => ({ type: "tick" }));
      const childResult = exitPromise.then((result) => ({ type: "exit", result }));
      const outcome = await Promise.race([tick, childResult]);
      if (outcome.type === "exit") {
        return typeof outcome.result.code === "number" ? outcome.result.code : 1;
      }

      let changed = false;
      for (const restartPath of restartPaths) {
        const currentMtime = fileMtime(restartPath);
        if (currentMtime !== mtimes.get(restartPath)) {
          mtimes.set(restartPath, currentMtime);
          changed = true;
        }
      }
      if (!changed) {
        continue;
      }

      await terminateChild(child);
      currentRuntime.cleanup();
      launch();
    }

    return 1;
  } finally {
    process.removeListener("SIGINT", signalHandler);
    process.removeListener("SIGTERM", signalHandler);
    await cleanup();
  }
}

async function runToolExec(spec, runfiles, userArgs) {
  const runtime = createRuntime(spec, runfiles);
  try {
    const toolPath = runfiles.rlocation(spec.tool_short_path);
    const args = [...(spec.args || [])];
    if (spec.passthrough_args) {
      args.push(...userArgs);
    }
    const result = await spawnProcess(toolPath, args, {
      cwd: runtime.runtimeExecDir,
      env: runtime.env,
    });
    return typeof result.code === "number" ? result.code : 1;
  } finally {
    runtime.cleanup();
  }
}

async function main() {
  const specPath = process.argv[2];
  if (!specPath) {
    fail("rules_bun: expected launcher spec path");
  }

  const spec = JSON.parse(readFileSync(specPath, "utf8"));
  if (spec.version !== 1) {
    fail(`rules_bun: unsupported launcher spec version ${spec.version}`);
  }

  const runfiles = detectRunfiles();
  const userArgs = process.argv.slice(3);

  let exitCode = 1;
  if (spec.kind === "tool_exec") {
    exitCode = await runToolExec(spec, runfiles, userArgs);
  } else if (spec.kind === "bun_test") {
    exitCode = await runBunOnce(spec, runfiles, spec.passthrough_args ? userArgs : []);
  } else if (spec.kind === "bun_run" && spec.watch_mode) {
    exitCode = await runDevMode(spec, runfiles, userArgs);
  } else if (spec.kind === "bun_run") {
    exitCode = await runBunOnce(spec, runfiles, spec.passthrough_args ? userArgs : []);
  } else {
    fail(`rules_bun: unsupported launcher kind ${spec.kind}`);
  }

  process.exit(exitCode);
}

main().catch((error) => {
  const message = error && error.stack ? error.stack : String(error);
  process.stderr.write(`${message}\n`);
  process.exit(1);
});
