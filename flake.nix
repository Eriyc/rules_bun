{
  description = "rules_bun development flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    git-hooks.url = "github:cachix/git-hooks.nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      treefmtEvalFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";

          programs = {
            nixfmt.enable = true;
            shfmt.enable = true;
            oxfmt.enable = true;
          };

          settings = {
            formatter = {
              shfmt = {
                options = [
                  "-i"
                  "2"
                  "-s"
                  "-w"
                ];
              };
              oxfmt = {
                includes = [
                  "*.md"
                  "*.yaml"
                  "*.yml"
                  "*.json"
                  "*.html"
                  "*.css"
                  "*.js"
                  "*.ts"
                  "*.tsx"
                  "*.svelte"
                ];
              };
            };
          };
        };
    in
    {
      formatter = forAllSystems (system: (treefmtEvalFor system).config.build.wrapper);

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          pre-commit-check = inputs.git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              treefmt = {
                enable = true;
                entry = "${(treefmtEvalFor system).config.build.wrapper}/bin/treefmt";
                pass_filenames = true;
              };
              gitlint.enable = true;

              gitleaks = {
                enable = true;
                entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged";
                pass_filenames = false;
              };

              tests = {
                enable = true;
                entry = "echo 'No tests defined yet.'";
                pass_filenames = false;
                stages = [
                  "pre-push"
                ];
              };
            };
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
          customShellHook = shellHook + "";
          bazel9 = pkgs.writeShellScriptBin "bazel" ''
            export USE_BAZEL_VERSION="''${USE_BAZEL_VERSION:-9.0.0}"
            exec ${pkgs.bazelisk}/bin/bazelisk "$@"
          '';

        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              go
              gopls
              gotools

              bun
              gitlint
              bazel9
              bazel-buildtools
            ];

            shellHook = ''
                ${customShellHook}
                export USE_BAZEL_VERSION="''${USE_BAZEL_VERSION:-9.0.0}"
                export BUN_INSTALL="''${BUN_INSTALL:-$HOME/.bun}"
                export PATH="$BUN_INSTALL/bin:$PATH"

                if ! command -v oxfmt >/dev/null 2>&1; then
                  bun add --global oxfmt
                fi

                if ! command -v oxlint >/dev/null 2>&1; then
                  bun add --global oxlint
                fi

              if [ -t 1 ]; then
                if command -v tput >/dev/null 2>&1; then
                  tput clear
                else
                  printf '\033c'
                fi
              fi

              GREEN='\033[1;32m'
              CYAN='\033[1;36m'
              YELLOW='\033[1;33m'
              BLUE='\033[1;34m'
              RESET='\033[0m'

              printf "\n$GREEN 🚀 Monorepo dev shell ready$RESET\n\n"
              printf "  $CYAN Bun:$RESET   $YELLOW%s$RESET\n" "$(bun --version)"
              printf "  $CYAN Go:$RESET    $YELLOW%s$RESET\n" "$(go version)"
              printf "  $CYAN Bazel:$RESET $BLUE%s$RESET\n\n" "$(bazel --version)"
            '';
            buildInputs = enabledPackages;
          };
        }
      );
    };
}
