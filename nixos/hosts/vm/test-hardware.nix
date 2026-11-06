# Fake hardware for exercising the control centre in the test VM, which has
# no Wi-Fi or Bluetooth chip and a single sound card:
# - two simulated Wi-Fi access points (mac80211_hwsim + hostapd),
# - a second virtual Bluetooth controller posing as headphones (btvirt),
# - an extra PipeWire output device,
# - mpv with MPRIS and a test track for the media player.
# None of this is imported by the Framework.
{ lib, pkgs, ... }:
let
  # BlueZ's controller emulator is only built with --enable-testing and isn't
  # installed; build it on its own so the VM's real BlueZ stays stock.
  btvirt = pkgs.bluez.overrideAttrs (old: {
    pname = "btvirt";
    configureFlags = old.configureFlags ++ [ "--enable-testing" ];
    outputs = [ "out" ];
    doCheck = false;
    installPhase = ''
      install -Dm755 emulator/btvirt $out/bin/btvirt
    '';
    postInstall = "";
    postFixup = "";
  });

  accessPoint =
    { iface, ssid, password ? null }:
    pkgs.writeText "hostapd-${iface}.conf" (
      ''
        interface=${iface}
        driver=nl80211
        ssid=${ssid}
        hw_mode=g
        channel=6
        ctrl_interface=/run/hostapd
      ''
      + lib.optionalString (password != null) ''
        wpa=2
        wpa_key_mgmt=WPA-PSK
        rsn_pairwise=CCMP
        wpa_passphrase=${password}
      ''
    );

  testTrack = pkgs.runCommand "test-track.ogg" { nativeBuildInputs = [ pkgs.ffmpeg-headless ]; } ''
    ffmpeg -loglevel error -f lavfi -i "sine=frequency=330:duration=180" -ac 2 \
      -metadata title="Glass Test Tone" -metadata artist="system-configs" \
      -metadata album="VM Fixtures" $out.ogg
    mv $out.ogg $out
  '';
in
{
  # Three simulated radios: wlan0 is the VM's client; wlan1 and wlan2 are
  # access points that NetworkManager leaves alone.
  boot.kernelModules = [
    "mac80211_hwsim"
    "hci_vhci"
  ];
  boot.extraModprobeConfig = "options mac80211_hwsim radios=3";
  # build-vm turns wireless off ("Wireless won't work in the VM") at VM
  # override priority; the simulated radios need it.
  virtualisation.vmVariant.networking.wireless.enable = lib.mkOverride 9 true;
  networking.networkmanager.unmanaged = [
    "wlan1"
    "wlan2"
  ];

  systemd.services = {
    # The access points live in their own network namespace, so their
    # DHCP replies aren't dropped as coming from the VM's own addresses.
    test-wifi = {
      description = "Simulated Wi-Fi access points";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      path = [
        pkgs.iproute2
        pkgs.iw
        pkgs.hostapd
        pkgs.dnsmasq
      ];
      serviceConfig = {
        ExecStartPre = "-${pkgs.iproute2}/bin/ip netns delete ap";
        ExecStopPost = "-${pkgs.iproute2}/bin/ip netns delete ap";
      };
      script = ''
        ip netns add ap
        for phy in $(ls /sys/class/ieee80211); do
          [ "$(ls /sys/class/ieee80211/$phy/device/net 2>/dev/null)" = wlan0 ] && continue
          iw phy "$phy" set netns name ap
        done
        ip netns exec ap ip link set lo up
        ip netns exec ap ip link set wlan1 up
        ip netns exec ap ip link set wlan2 up
        ip netns exec ap ip addr add 10.42.1.1/24 dev wlan1
        ip netns exec ap ip addr add 10.42.2.1/24 dev wlan2
        ip netns exec ap hostapd -B ${
          accessPoint {
            iface = "wlan1";
            ssid = "Home Network";
            password = "testpass123";
          }
        } ${
          accessPoint {
            iface = "wlan2";
            ssid = "Cafe Guest";
          }
        }
        exec ip netns exec ap dnsmasq --keep-in-foreground --port=0 --bind-interfaces \
          --interface=wlan1 --interface=wlan2 --no-resolv --pid-file= \
          --dhcp-range=wlan1,10.42.1.10,10.42.1.100,1h \
          --dhcp-range=wlan2,10.42.2.10,10.42.2.100,1h
      '';
    };

    # Two virtual controllers: hci0 is the VM's adapter, hci1 is set up as
    # discoverable "Test Headphones" that pairs without a PIN.
    test-bluetooth = {
      description = "Virtual Bluetooth controllers";
      wantedBy = [ "multi-user.target" ];
      before = [ "bluetooth.service" ];
      serviceConfig.ExecStart = "${btvirt}/bin/btvirt -l2";
    };
    test-bluetooth-headphones = {
      description = "Make the second virtual controller look like headphones";
      wantedBy = [ "multi-user.target" ];
      after = [
        "bluetooth.service"
        "test-bluetooth.service"
      ];
      path = [ pkgs.bluez ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 5;
      };
      script = ''
        # Wait until the kernel has registered the second controller.
        for _ in $(seq 60); do btmgmt info 2>/dev/null | grep -q '^hci1:' && break; ${pkgs.coreutils}/bin/sleep 1; done
        btmgmt --index 1 power off
        btmgmt --index 1 name "Test Headphones"
        btmgmt --index 1 class 4 4
        btmgmt --index 1 io-cap 3
        btmgmt --index 1 bondable on
        btmgmt --index 1 connectable on
        btmgmt --index 1 power on
        btmgmt --index 1 discov on
      '';
    };
  };

  # The fake headphones stay discoverable instead of timing out after 3 min.
  hardware.bluetooth.settings.General.DiscoverableTimeout = 0;

  # A second output beside the virtual sound card. (A fake microphone made
  # this way stops WirePlumber choosing default devices, so there isn't one.)
  services.pipewire.extraConfig.pipewire."90-test-devices" = {
    "context.objects" = [
      {
        factory = "adapter";
        args = {
          "factory.name" = "support.null-audio-sink";
          "node.name" = "test-usb-headphones";
          "node.description" = "USB Headphones";
          "media.class" = "Audio/Sink";
          "audio.position" = "FL,FR";
        };
      }
    ];
  };

  # `play-test-track` starts mpv in the background, visible to MPRIS.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "play-test-track" ''
      exec ${
        pkgs.mpv.override { scripts = [ pkgs.mpvScripts.mpris ]; }
      }/bin/mpv --no-video --loop=inf --title="Glass Test Tone" ${testTrack}
    '')
  ];
}
