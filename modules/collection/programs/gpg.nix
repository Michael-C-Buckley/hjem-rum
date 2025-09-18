{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkEnableOption mkIf getExe;
  inherit (lib.types) int package lines;
  cfg = config.rum.programs.gnupg;

  # Returns the line or empty based on the bool, used later with the agent config
  mkCfgLine = bool: string: (
    if bool
    then ''
      ${string}
    ''
    else ''''
  );

  mkExtraLinesOption = file:
    mkOption {
      type = lines;
      default = '''';
      description = "Extra lines added to the `${file}` file.";
    };
in {
  options.rum.programs.gnupg = {
    enable = mkEnableOption "Enable gnupg features for the user.";
    package = mkOption {
      type = package;
      default = pkgs.gnupg;
      description = "Which GnuPG package to use in userspace.";
    };
    pinentryPackage = mkOption {
      type = package;
      default = pkgs.pinentry-curses;
      description = "Which pinentry package to use with GnuPG";
    };
    config = {
      extraLines = mkExtraLinesOption "gpg.conf";
    };
    agent = {
      allowLoopbackPinentry = mkEnableOption "Allow loopback pinentry.";
      enableSSHsupport = mkEnableOption "Enable SSH support for GnuPG";
      cacheTTL = mkOption {
        type = int;
        default = 60;
        description = "The number of seconds to cache the authorization on the GnuPG key.";
      };
      extraLines = mkExtraLinesOption "gpg-agent.conf";
    };
    scdaemon = {
      disable-ccid = mkEnableOption ''
        Stops the CCID conflict from pcscd and scdaemon. Useful for Yubikey OpenPGP.
        See: https://support.yubico.com/hc/en-us/articles/4819584884124-Resolving-GPG-s-CCID-conflicts
      '';
      extraLines = mkExtraLinesOption "scdaemon.conf";
    };
  };

  config = mkIf cfg.enable {
    files = {
      ".gnupg/gpg.conf" = {
        # Currently only has the extra lines
        enable = cfg.config.extraLines != '''';
        text = cfg.config.extraLines;
      };

      ".gnupg/gpg-agent.conf".text =
        ''
          pinentry-program ${getExe cfg.pinentryPackage}
          default-cache-ttl ${builtins.toString cfg.agent.cacheTTL}
        ''
        + mkCfgLine cfg.agent.enableSSHsupport "enable-ssh-support"
        + mkCfgLine cfg.agent.allowLoopbackPinentry "allow-loopback-pinentry";

      ".gnupg/scdaemon.conf" = {
        enable = cfg.scdaemon.disable-ccid;
        text = ''disable-ccid'';
      };
    };
    packages = [
      cfg.pinentryPackage
      cfg.package
    ];
  };
}
