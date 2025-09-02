{ config, lib, pkgs, ... }:
with lib;
let
    cfg = config.services.superTuxKarts;
    serverConfig = pkgs.writeText "config.xml" (builtins.toXML config.services.superTuxKarts.serverOptions);
in
{
    options.services.superTuxKarts = {
        enable = mkEnableOption "Super Tux Karts server";
        package = mkPackageOption pkgs "supertuxkart" { };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/stk";
            description = ''
Directory to store STK server releated files.
'';
        };

        serverOptions = mkOption {
            type = types.submodule {
                name = mkOption {
                    type = types.str;
                    default = "STK server";
                    description = ''
Name for the Super Tux Karts server
'';
                };
                port = mkOption {
                    type = types.int;
                    default = 2759;
                    description = ''
Port for the server. If 0 then it will use the port specified in stk_config.xml. If you want to use a random port set random-server-port to 1 in user config. This port will be opened in the firwall if it is not 0.
'';
                };
            };
        };
    };

    config = mkIf cfg.enable {
        environment.systemPackages = [ cfg.package pkgs.screen ];

        networking.firewall = mkIf (cfg.serverPort != 0) {
            allowedUDPPorts = [ cfg.serverPort ];
        };

        users.users.STK = {
            description = "Super Tux Karts server service user";
            home = cfg.dataDir;
            createHome = true;
            isSystemUser = true;
            group = "stk";
        };
        users.groups.stk = { };

        systemd.sockets.stk = {
            bindsTo = [ "stk.service" ];
            socketConfig = {
                ListenFIFO = "/run/stk.stdin";
                SocketMode = "0660";
                SocketUser = "stk";
                SocketGroup = "stdk";
                RemoveOnStop = true;
                FlushPending = true;
            };
        };
        systemd.services.stk = {
            wantedBy = [ "multi-user.target" ];
            requires = [ "stk.socket" ];
            after = [ "network.target" "stk.socket" ];
            description = "Super Tux Karts server";
            
            servicesConfig = {
                ExecStart = "${cfg.package}/bin/supertuxkart --server-config=${serverConfig} --network-console";
                ExecStop = "echo quit > ${config.systemd.sockets.stk.socketConfig.ListenFIFO}";
                Restart = "always";
                User = "stk";
                WorkingDirectory = cfg.dataDir;

                StandardInput = "socket";
                StandardOutput = "journal";
                StandardError = "journal";
            };
        };
    };
}
