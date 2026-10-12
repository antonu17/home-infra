# Synology acme.sh certificate delivery: NAS .40.5 -> router .40.1 TCP22.
# Private material is uploaded separately; no certificate/key content in this file.
:do {
    :foreach identity in={"Pi-hole ACME SSH";"Pi-hole ACME HTTPS verification"} do={
        :if ([:len [/ip firewall filter find where comment=$identity]] > 1) do={ :error "Duplicate Pi-hole ACME rule" }
    }
    :if ([:len [/system script find where name="pihole-install-cert"]] > 1) do={ :error "Duplicate Pi-hole certificate script" }
    :if ([:len [/user group find where name="pihole-acme"]] > 1) do={ :error "Duplicate Pi-hole ACME group" }
    :if ([:len [/user find where name="pihole-acme"]] > 1) do={ :error "Duplicate Pi-hole ACME user" }
    :if ([:len [/ip firewall filter find where comment="input default deny"]] != 1) do={ :error "Import file09 first" }
    :if ([:len [/ip firewall filter find where comment="forward default deny"]] != 1) do={ :error "Import file09 first" }
    :local acmeGroup [/user group find where name="pihole-acme"]
    :if ([:len $acmeGroup] = 0) do={ /user group add name=pihole-acme policy=ssh,ftp,read,write,test } else={ /user group set $acmeGroup policy=ssh,ftp,read,write,test }
    :local account [/user find where name="pihole-acme"]
    :if ([:len $account] = 0) do={
        # Initially disabled; import the dedicated public key before enabling.
        /user add name=pihole-acme group=pihole-acme address=192.168.40.5/32 disabled=yes password=[:rndstr length=48] comment="Synology Pi-hole certificate delivery"
    } else={
        /user set $account group=pihole-acme address=192.168.40.5/32 comment="Synology Pi-hole certificate delivery"
    }
    # Public-key bootstrap is additive; private key remains on Synology.
    :if (([:len [/user ssh-keys find where user="pihole-acme"]] = 0) && ([:len [/file find where name="pihole-acme.pub"]] = 1)) do={
        /user ssh-keys import user=pihole-acme public-key-file=pihole-acme.pub
    }
    :if ([:len [/user ssh-keys find where user="pihole-acme"]] > 0) do={ /user enable [find where name="pihole-acme"] }
    :local rule [/ip firewall filter find where comment="Pi-hole ACME SSH"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=input disabled=yes comment="Pi-hole ACME SSH"; :set rule [/ip firewall filter find where comment="Pi-hole ACME SSH"] }
    /ip firewall filter set $rule !out-interface !src-address-list !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=input action=accept in-interface-list=CLOUD src-address=192.168.40.5 dst-address=192.168.40.1 protocol=tcp dst-port=22 disabled=no log=no
    /ip firewall filter move $rule destination=[/ip firewall filter find where comment="input default deny"]
    :set rule [/ip firewall filter find where comment="Pi-hole ACME HTTPS verification"]
    :if ([:len $rule] = 0) do={ /ip firewall filter add chain=forward disabled=yes comment="Pi-hole ACME HTTPS verification"; :set rule [/ip firewall filter find where comment="Pi-hole ACME HTTPS verification"] }
    /ip firewall filter set $rule !src-address-list !dst-address-list !in-interface !out-interface-list !src-port !connection-state !connection-mark !connection-nat-state !ipsec-policy !routing-mark !tcp-flags !icmp-options !limit !dst-limit !time chain=forward action=accept in-interface-list=CLOUD src-address=192.168.40.5 out-interface=bridge-pihole dst-address=172.31.254.2 protocol=tcp dst-port=443 disabled=no log=no
    /ip firewall filter move $rule destination=[/ip firewall filter find where comment="forward default deny"]
    :local installer [/system script find where name="pihole-install-cert"]
    :if ([:len $installer] = 0) do={ /system script add name=pihole-install-cert policy=ftp,read,write,test; :set installer [/system script find where name="pihole-install-cert"] }
    /system script set $installer policy=ftp,read,write,test dont-require-permissions=no source={
        :local instance [/container find where name="pihole"]
        :if ([:len $instance] != 1) do={ :error "One Pi-hole container required" }
        :if ([/container get $instance mountlists] != "pihole-data") do={ :error "Unexpected Pi-hole mounts" }
        :local mount [/container mounts find where list="pihole-data"]
        :if ([:len $mount] != 1) do={ :error "One Pi-hole data mount required" }
        :if ([/container mounts get $mount dst] != "/etc/pihole") do={ :error "Unexpected Pi-hole mount destination" }
        :local dataPath [/container mounts get $mount src]
        :if ([:pick $dataPath 0 1] = "/") do={ :set dataPath [:pick $dataPath 1 [:len $dataPath]] }
        :if ($dataPath != "flash/volumes/pihole") do={ :error "Unexpected Pi-hole certificate storage path" }
        :local current ($dataPath . "/tls.pem")
        :local staged ($dataPath . "/tls.pem.next")
        :local previous ($dataPath . "/tls.pem.previous")
        :local incoming [/file find where name=$staged]
        :if ([:len $incoming] != 1) do={ :error "Staged certificate required" }
        :local bundleSize [/file get $incoming size]
        :if (($bundleSize < 1024) || ($bundleSize > 60000)) do={ :error "Unexpected certificate bundle size" }
        :if ([:len [/file find where name=$current]] != 1) do={ :error "Existing Pi-hole TLS bundle required" }
        /container stop $instance
        :local isStopped false
        :for attempt from=1 to=30 do={
            :if ([:len [/container find where name="pihole" and stopped]] = 1) do={ :set isStopped true; :break }
            :delay 1s
        }
        :if ($isStopped != true) do={ :error "Pi-hole stop timed out; certificate unchanged" }
        :local rotated false
        :do {
            /file remove [find where name=$previous]
            /file set [find where name=$current] name=$previous
            :set rotated true
            /file set $incoming name=$current
            /container start $instance
        } on-error={
            :if ($rotated = true) do={
                /file remove [find where name=$current]
                /file set [find where name=$previous] name=$current
            }
            /container start $instance
            :error "Certificate installation failed; previous bundle restored"
        }
        :local ready false
        :for attempt from=1 to=60 do={
            :do {
                :local answer [:resolve "example.com" server=172.31.254.2]
                :if ([:len [:tostr $answer]] > 0) do={ :set ready true }
            } on-error={}
            :if ($ready = true) do={ :break }
            :delay 1s
        }
        :if ($ready != true) do={ :error "Pi-hole DNS readiness failed; previous bundle retained" }
        :put "PIHOLE_TLS_INSTALLED"
    }
}
