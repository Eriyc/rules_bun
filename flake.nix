{
  description = "rules_bun development flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    repo-lib.url = "git+https://git.dgren.dev/eric/nix-flake-lib?ref=refs/tags/v3.0.0";
    repo-lib.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      repo-lib,
      ...
    }:
    let
      bazelVersion = "9.0.1";
    in
    repo-lib.lib.mkRepo {
      inherit self nixpkgs;
      src = ./.;

      config = {
        shell.extraShellText = ''
          export USE_BAZEL_VERSION="''${USE_BAZEL_VERSION:-${bazelVersion}}"
          export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
          export PATH="$BUN_INSTALL/bin:$PATH"
        '';

        formatting = {
          programs.shfmt.enable = true;
          settings.shfmt.options = [
            "-i"
            "2"
            "-s"
            "-w"
          ];
        };

        release = {
          steps = [
            {
              run.script = ''
                sed -E -i 's#^([[:space:]]*version[[:space:]]*=[[:space:]]*")[^"]*(",)$#\1'"$FULL_VERSION"'\2#' "$ROOT_DIR/MODULE.bazel"
              '';
            }
            {
              run.script = ''
                README="$ROOT_DIR/README.md"
                TMP="$README.tmp"

                awk -v stable="$BASE_VERSION" -v prerelease="$BASE_VERSION-rc.1" '
                  {
                    line = $0

                    if (line ~ /bazel_dep\(name = "rules_bun", version = "/ && line !~ /-rc\.1/) {
                      sub(/version = "[^"]+"/, "version = \"" stable "\"", line)
                    } else if (line ~ /bazel_dep\(name = "rules_bun", version = "/ && line ~ /-rc\.1/) {
                      sub(/version = "[^"]+"/, "version = \"" prerelease "\"", line)
                    } else if (line ~ /archive\/refs\/tags\/v/ && line !~ /-rc\.1/) {
                      sub(/v[^"]+\.tar\.gz/, "v" stable ".tar.gz", line)
                    } else if (line ~ /archive\/refs\/tags\/v/ && line ~ /-rc\.1/) {
                      sub(/v[^"]+\.tar\.gz/, "v" prerelease ".tar.gz", line)
                    } else if (line ~ /strip_prefix = "rules_bun-v/ && line !~ /-rc\.1/) {
                      sub(/rules_bun-v[^"]+/, "rules_bun-v" stable, line)
                    } else if (line ~ /strip_prefix = "rules_bun-v/ && line ~ /-rc\.1/) {
                      sub(/rules_bun-v[^"]+/, "rules_bun-v" prerelease, line)
                    } else if (line ~ /For channel\/pre-release tags \(for example `v.*-rc\.1`\), use the matching folder prefix:/) {
                      sub(/`v[^`]+`/, "`v" prerelease "`", line)
                    }

                    print line
                  }
                ' "$README" > "$TMP" && mv "$TMP" "$README"
              '';
            }
            {
              run.script = ''
                bazel cquery //tests/... >/dev/null
              '';
            }
          ];

          postVersion = ''
            echo "Released $FULL_TAG"
          '';
        };
      };

      perSystem =
        {
          pkgs,
          system,
          ...
        }:
        let
          bazel9 = pkgs.writeShellScriptBin "bazel" ''
            export USE_BAZEL_VERSION="''${USE_BAZEL_VERSION:-${bazelVersion}}"
            exec ${pkgs.bazelisk}/bin/bazelisk "$@"
          '';
        in
        {
          tools = [
            (repo-lib.lib.tools.fromPackage {
              name = "Bun";
              package = pkgs.bun;
              version.args = [ "--version" ];
              banner.color = "YELLOW";
            })
            (repo-lib.lib.tools.fromPackage {
              name = "Bazel";
              package = bazel9;
              version.args = [ "--version" ];
              banner.color = "GREEN";
            })
          ];

          shell.packages = [
            pkgs.bazel-buildtools
            self.packages.${system}.release
          ];

          checks.tests = {
            command = "bazelisk test //tests/...";
            stage = "pre-push";
            passFilenames = false;
            runtimeInputs = [
              bazel9
              pkgs.bun
            ];
          };
        };
    };
}
