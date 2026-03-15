const pathValue = process.env.PATH ?? "";

console.log(JSON.stringify({
  hasHostSentinel: pathValue.includes("rules_bun_host_path_sentinel"),
}));
