{
  description = "rules_bun development flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    devshell-lib.url = "git+https://git.dgren.dev/eric/nix-flake-lib?ref=v1.0.5";
    devshell-lib.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      devshell-lib,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          bazel9 = pkgs.writeShellScriptBin "bazel" ''
            export USE_BAZEL_VERSION="''${USE_BAZEL_VERSION:-9.0.0}"
            exec ${pkgs.bazelisk}/bin/bazelisk "$@"
          '';
          env = devshell-lib.lib.mkDevShell {
            inherit system;

            extraPackages = with pkgs; [
              go
              gopls
              gotools
              bun
              bazel9
              bazel-buildtools
              self.packages.${system}.release
            ];

            features = {
              oxfmt = true;
            };

            formatters = {
              shfmt.enable = true;
            };

            formatterSettings = {
              shfmt.options = [
                "-i"
                "2"
                "-s"
                "-w"
              ];
            };

            additionalHooks = {
              tests = {
                enable = true;
                entry = "echo 'No tests defined yet.'";
                pass_filenames = false;
                stages = [ "pre-push" ];
              };
            };

            tools = [
              {
                name = "Bun";
                bin = "${pkgs.bun}/bin/bun";
                versionCmd = "--version";
                color = "YELLOW";
              }
              {
                name = "Go";
                bin = "${pkgs.go}/bin/go";
                versionCmd = "version";
                color = "CYAN";
              }
              {
                name = "Bazel";
                bin = "${bazel9}/bin/bazel";
                versionCmd = "--version";
                color = "GREEN";
              }
            ];

            extraShellHook = ''
              export USE_BAZEL_VERSION="''${USE_BAZEL_VERSION:-9.0.0}"
              export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
              export PATH="$BUN_INSTALL/bin:$PATH"
            '';
          };
        in
        {
          default = env.shell;
        }
      );

      checks = forAllSystems (
        system:
        let
          env = devshell-lib.lib.mkDevShell { inherit system; };
        in
        {
          inherit (env) pre-commit-check;
        }
      );

      formatter = forAllSystems (system: (devshell-lib.lib.mkDevShell { inherit system; }).formatter);

      # Optional: release command (`release`)
      #
      # The release script always updates VERSION first, then:
      #   1) runs release steps in order (file writes and scripts)
      #   2) runs postVersion hook
      #   3) formats, stages, commits, tags, and pushes
      #
      # Runtime env vars available in release.run/postVersion:
      #   BASE_VERSION, CHANNEL, PRERELEASE_NUM, FULL_VERSION, FULL_TAG
      #
      packages = forAllSystems (system: {
        release = devshell-lib.lib.mkRelease {
          inherit system;

          release = [
            {
              run = ''
                sed -E -i 's#^([[:space:]]*version[[:space:]]*=[[:space:]]*")[^"]*(",)$#\1'"$FULL_VERSION"'\2#' "$ROOT_DIR/MODULE.bazel"
              '';
            }
            {
              run = ''
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
          ];

          postVersion = ''
            echo "Released $FULL_TAG"
          '';
        };
      });

    };

}
