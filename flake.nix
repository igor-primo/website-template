{
  description = "Simple website template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    llm-agents.url = "github:numtide/llm-agents.nix";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ nixpkgs
    , flake-utils
    , llm-agents
    , devenv
    , ...
    }:
    flake-utils.lib.eachDefaultSystem
      (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          devShells.default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              ({ pkgs, config, ... }: {
                packages = [
                  llm-agents.packages."x86_64-linux".copilot-cli
                  pkgs.live-server
                ];
                services.nginx = {
                  enable = true;
                  httpConfig = ''
                    server {
                      listen 8000;
                      location / {
                        root ${config.env.DEVENV_ROOT}/src;
                        index index.html;
                      }
                    }
                  '';
                };
                process.manager.implementation = "overmind";
                processes.live-server.exec = "live-server --hard --port 8000";
              })
            ];
          };
        }
      ) // {
      nixosModules. default = { config, lib, pkgs, ... }:
        let
          websiteFiles = pkgs.runCommand "website" { } ''
            mkdir -p $out
            cp ${./src/index.html} $out/index.html
          '';
        in
        {
          options. services. website = {
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
