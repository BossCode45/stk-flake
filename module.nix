{ config, lib, pkgs, ... }:
with lib;
let
    cfg = config.services.superTuxKarts;
    generateXML = name : value :
        "\t<${name} value=\"" +
        (if (isBool value) then (boolToString value) else (builtins.toString value)) +
        "\" />\n";
    serverConfig = pkgs.writeText "config.xml" (
        "<?xml version='1.0'?>\n<server-config version='6'>\n" +
        (generateXML "server-port" cfg.port) +
        (generateXML "wan-server" false) +
        (generateXML "enable-console" true) +
        (concatStrings (mapAttrsToList (name : value: (generateXML name value)) cfg.serverOptions)) +
        "</server-config>\n");
    stopScript = pkgs.writeShellScript "stk-stop.sh" ''
echo quit > ${config.systemd.sockets.stk.socketConfig.ListenFIFO}   
        '';
in
{
    options.services.superTuxKarts = {
        enable = mkEnableOption "Super Tux Karts server";
        package = mkPackageOption pkgs "superTuxKart" { };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/stk";
            description = ''
        Directory to store STK server releated files.
        '';
        };

        port = mkOption {
            type = types.int;
            default = 2757;
            description = ''
        Port for the server. If 0 then it will use the port specified in stk_config.xml. If you want to use a random port set random-server-port to 1 in user config.
            '';
        };
        openPort = mkOption {
            type = types.bool;
            default = true;
            description = ''
            Open port in the firewall
            '';
        };

        serverOptions = mkOption {
            default = { };
            type = with lib.types; attrsOf (oneOf [bool int str] );
            example = ''
            {
                server-name = "Super Nix Karts";
                server-mode = 0;
                server-difficulty = 3;
                motd = "Welcome to the NixOS STK server";
                track-voting = false;
            }
            '';
            description = ''
Server properties to use.
See
<https://github.com/supertuxkart/stk-code/blob/master/NETWORKING.md>
for documentation on these properties.
'';
        };
    };

    config = mkIf cfg.enable {
        environment.systemPackages = [ cfg.package ];

        networking.firewall = mkIf (cfg.port != 0 && cfg.openPort) {
            allowedUDPPorts = [ cfg.port ];
        };

        users.users.stk = {
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
                SocketGroup = "stk";
                RemoveOnStop = true;
                FlushPending = true;
            };
        };
        systemd.services.stk = {
            wantedBy = [ "multi-user.target" ];
            requires = [ "stk.socket" ];
            after = [ "network.target" "stk.socket" ];
            description = "Super Tux Karts server";
            
            serviceConfig = {
                ExecStart = "${cfg.package}/bin/supertuxkart --server-config=${serverConfig} --network-console --spectators 1";
                ExecStop = "${stopScript}";
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
