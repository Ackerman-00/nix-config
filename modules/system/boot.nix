{ pkgs, ... }:
{
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        bootCounting.enable = true;
        editor = false;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.kernelModules = [ "amdgpu" ];

    # unused network protocol modules
    blacklistedKernelModules = [
      "dccp"
      "rds"
      "sctp"
      "tipc"
    ];
    consoleLogLevel = 3;
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "amd_pstate=active"
      "amdgpu.gpu_recovery=1"
      "slab_nomerge"
      "init_on_alloc=1"
      "page_alloc.shuffle=1"
    ];

    # KSPP sysctls
    kernel.sysctl = {
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.kexec_load_disabled" = 1;
      "kernel.perf_event_paranoid" = 3;
      "kernel.unprivileged_bpf_disabled" = 1;
      "kernel.yama.ptrace_scope" = 1;
      "dev.tty.ldisc_autoload" = 0;
      "net.core.bpf_jit_harden" = 2;
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "fs.suid_dumpable" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
    };
  };

  # zram is in-memory swap, so the kernel should swap before dropping page cache
  # https://docs.kernel.org/admin-guide/sysctl/vm.html#swappiness
  boot.kernel.sysctl."vm.swappiness" = 100;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 5;
  };
}
