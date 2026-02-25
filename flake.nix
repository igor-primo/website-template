{
  description = "Empty Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    { nixpkgs
    , flake-utils
    , llm-agents
    , ...
    }:
    flake-utils.lib.eachDefaultSystem
      (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          nativeBuildInputs = with pkgs; [ ];
          buildInputs = with pkgs; [
            llm-agents.packages."x86_64-linux".copilot-cli
          ];
        in
        {
          devShells.default = pkgs.mkShell { inherit nativeBuildInputs buildInputs; };
        }
      ) // {
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          websiteFiles = pkgs.runCommand "website" { } ''
            mkdir -p $out
            cp ${./src/index.html} $out/index.html
          '';
        in
        {
          options.services.website = {
            enable = lib.mkEnableOption "static website via nginx";
            hostname = lib.mkOption {
              type = lib.types.str;
              default = "localhost";
              description = "The hostname nginx should serve the website on";
            };
            root = lib.mkOption {
              type = lib.types.path;
              default = websiteFiles;
              description = "Path to the static website files";
            };
          };

          config = lib.mkIf config.services.website.enable {
            services.nginx = {
              enable = true;
              virtualHosts.${config.services.website.hostname} = {
                root = config.services.website.root;
                locations."/" = {
                  tryFiles = "$uri $uri/ =404";
                };
              };
            };
          };
        };
    };
}
