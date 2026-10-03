{ esc }:
{
  "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
  logo = {
    type = "kitty-direct";
    width = 26;
    height = 17;
    padding = {
      top = 5;
      right = 5;
      left = 3;
    };
  };
  display = {
    color = {
      keys = "38;2;226;52;42";
    };
    key = {
      width = 9;
    };
    separator = "  ";
    percent = {
      type = 9;
      color = {
        green = "38;2;127;191;106";
        yellow = "38;2;217;164;65";
        red = "38;2;226;52;42";
      };
    };
  };
  modules = [
    "break"
    {
      type = "title";
      format = "${esc}[1;38;2;243;237;225m{user-name}${esc}[0m${esc}[38;2;143;135;112m @ ${esc}[0m${esc}[1;38;2;243;237;225m{host-name}${esc}[0m";
    }
    {
      type = "custom";
      format = "${esc}[38;2;226;52;42m■${esc}[0m ${esc}[38;2;143;135;112mQᴜɪᴇᴛᴄʀᴀꜰᴛ · 力 · Aspire to inspire, before you expire.${esc}[0m";
    }
    "break"
    {
      type = "custom";
      format = "${esc}[38;2;226;52;42m──${esc}[0m ${esc}[1;38;2;243;237;225mVITALS${esc}[0m ${esc}[38;2;58;46;36m──────────────────────────${esc}[0m";
    }
    {
      type = "cpu";
      key = "CPU";
    }
    {
      type = "gpu";
      key = "GPU";
      detectionMethod = "pci";
    }
    {
      type = "memory";
      key = "MEMORY";
    }
    {
      type = "disk";
      key = "DISK";
    }
    "break"
    {
      type = "custom";
      format = "${esc}[38;2;226;52;42m──${esc}[0m ${esc}[1;38;2;243;237;225mSYSTEM${esc}[0m ${esc}[38;2;58;46;36m──────────────────────────${esc}[0m";
    }
    {
      type = "os";
      key = "OS";
    }
    {
      type = "display";
      key = "DISPLAY";
    }
    {
      type = "kernel";
      key = "KERNEL";
    }
    {
      type = "wm";
      key = "WM";
    }
    {
      type = "de";
      key = "DE";
    }
    {
      type = "shell";
      key = "SHELL";
    }
    {
      type = "packages";
      key = "PKGS";
    }
    "break"
    {
      type = "custom";
      format = "${esc}[38;2;226;52;42m──${esc}[0m ${esc}[1;38;2;243;237;225mSESSION${esc}[0m ${esc}[38;2;58;46;36m─────────────────────────${esc}[0m";
    }
    {
      type = "uptime";
      key = "UPTIME";
    }
    {
      type = "command";
      key = "AGE";
      text = "echo $(( ($(date +%s) - $(stat -c %W /)) / 86400 )) days";
    }
    {
      type = "terminal";
      key = "TERM";
    }
    "break"
    {
      type = "colors";
      symbol = "circle";
      paddingLeft = 2;
    }
    "break"
  ];
}
