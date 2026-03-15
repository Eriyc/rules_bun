import { spawnSync } from "node:child_process";

const pathValue = process.env.PATH ?? "";

function commandSucceeds(command: string, args: string[]): boolean {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    env: process.env,
  });
  return result.status === 0;
}

console.log(JSON.stringify({
  hasHostSentinel: pathValue.includes("rules_bun_host_path_sentinel"),
  canRunBun: commandSucceeds("bun", ["-e", "process.exit(0)"]),
  canRunBunx: commandSucceeds("bunx", ["--version"]),
  canRunNode: commandSucceeds("node", ["-e", "process.exit(0)"]),
}));
