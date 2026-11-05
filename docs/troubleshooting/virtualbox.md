# VirtualBox / Vagrant — Troubleshooting

This document records real infrastructure issues encountered while building the DevOps lab using Vagrant, VirtualBox, and Ubuntu.

Each case documents the symptoms, diagnostic commands, observed results, technical conclusions, and resolution.

---

## Issue 1 — DNS Resolution Failure in VirtualBox NAT

**Status:** Resolved  
**Component:** VirtualBox NAT / Ubuntu DNS / Netplan  
**Impact:** AWS CLI could not reliably access AWS endpoints.

### 1. Environment

The Ubuntu VM was provisioned using Vagrant with VirtualBox as the hypervisor.

Network configuration:

| Parameter | Value |
|---|---|
| Interface | `enp0s3` |
| Network mode | VirtualBox NAT |
| Guest IP | `10.0.2.15` |
| Default gateway | `10.0.2.2` |
| DHCP-provided DNS | `10.0.2.3` |
| Ubuntu network configuration | Netplan + systemd-resolved |

### 2. Problem Description

While configuring AWS CLI with IAM Identity Center (SSO), the VM experienced DNS resolution failures when accessing AWS endpoints.

The initial question was whether the problem was caused by AWS authentication, general internet connectivity, or DNS resolution inside the VirtualBox guest.

### 3. Troubleshooting

#### Step A — Verify IP connectivity

```bash
ping -c 3 1.1.1.1
```

**Observed result:** Successful ICMP responses.

**Conclusion:** The VM could reach an external IP address. General IP connectivity through VirtualBox NAT was working.

#### Step B — Test DNS resolution using an independent resolver

```bash
dig @1.1.1.1 oidc.eu-north-1.amazonaws.com
```

**Observed result:** DNS resolution succeeded.

**Conclusion:** The AWS domain could be resolved using an external DNS server. This narrowed the investigation to the VM's configured DNS resolution path.

#### Step C — Inspect the DNS configuration

```bash
resolvectl status enp0s3
```

The VM was receiving the DNS server `10.0.2.3` from VirtualBox NAT DHCP.

This address represents the VirtualBox NAT DNS proxy.

**Finding:** DNS requests through the DHCP-provided resolver were not responding, while direct queries to `1.1.1.1` succeeded.

**Conclusion:** The evidence pointed to a problem with the VirtualBox NAT DNS resolution path, rather than AWS authentication or general IP connectivity.

The underlying reason for the NAT DNS proxy failure was not established.

#### Step D — Inspect Netplan configuration

```bash
ls -l /etc/netplan/
```

The VM already had a Cloud-init-generated network configuration:

```text
/etc/netplan/50-cloud-init.yaml
```

Rather than modifying the Cloud-init-managed file, a separate configuration was chosen.

### 4. Resolution

Created:

```text
/etc/netplan/99-dns.yaml
```

Configuration:

```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4-overrides:
        use-dns: false
      dhcp6-overrides:
        use-dns: false
      nameservers:
        addresses: [1.1.1.1]
```

**Explanation:**

- `use-dns: false` prevents DHCP-provided DNS servers from being used.
- `nameservers` explicitly configures Cloudflare DNS (`1.1.1.1`).
- The interface continues to receive its IP address and default route through DHCP.
- `99-dns.yaml` is processed after `50-cloud-init.yaml`, allowing the later settings to override the earlier DNS-related settings.

The filename `99-dns.yaml` has no special meaning beyond its ordering.

### 5. Apply and Validate

Restrict configuration file permissions:

```bash
sudo chmod 600 /etc/netplan/99-dns.yaml
```

Validate Netplan syntax and configuration:

```bash
sudo netplan generate
```

**Observed result:** Completed successfully.

Apply the configuration with automatic rollback protection:

```bash
sudo netplan try --timeout 120
```

**Observed result:** Configuration applied successfully and was confirmed.

After rebooting the VM, verify the effective DNS configuration:

```bash
resolvectl status enp0s3
```

**Observed result:** The interface used `1.1.1.1` as its DNS server. The previous `10.0.2.3` DNS server was no longer listed for that interface.

### 6. Root Cause and Findings

**Confirmed:**

- External IP connectivity worked.
- DNS resolution through `1.1.1.1` worked.
- The DHCP-provided VirtualBox NAT DNS server `10.0.2.3` did not respond as expected.
- Overriding DHCP DNS settings through Netplan resolved the observed DNS configuration problem.
- The configuration persisted after a VM reboot.

**Not confirmed:**

The specific internal reason why the VirtualBox NAT DNS proxy failed.

This is a validated workaround, not proof of a VirtualBox software defect.

### 7. Configuration in Git

The tested Netplan configuration is stored at:

```text
configs/netplan/99-dns.yaml
```

To apply it to another Ubuntu VM using the same interface name:

```bash
sudo cp 99-dns.yaml /etc/netplan/99-dns.yaml
sudo chmod 600 /etc/netplan/99-dns.yaml
sudo netplan generate
sudo netplan try --timeout 120
```

The source path in the first command is relative to the directory containing the downloaded configuration file.

**Important:** Verify the actual interface name before applying the configuration. It may differ between environments.

### 8. Future Improvement

Integrate this configuration into Vagrant/Ansible provisioning so that the workaround can be applied automatically and reproducibly.

The fix should be configurable rather than assumed necessary for every VirtualBox installation.

---

## Issue 2 — AWS CLI Signature Expired Due to Clock Skew

**Status:** Under investigation  
**Component:** Ubuntu system clock / VirtualBox / AWS CLI

### 1. Problem Description

After successful AWS IAM Identity Center authentication, the following command failed:

```bash
aws sts get-caller-identity --profile devops-admin
```

The AWS STS error was:

```text
SignatureDoesNotMatch
Signature expired: 20261105T111301Z is now
earlier than 20261105T135922Z
(20261105T141422Z - 15 min.)
```

The timestamps indicated a difference of approximately three hours between the request signature and AWS server time.

### 2. Verify System Clock

```bash
timedatectl status
```

**Observed:**

```text
Time zone: Etc/UTC (UTC, +0000)
System clock synchronized: yes
NTP service: active
RTC in local TZ: no
```

The VM reported successful synchronization, but this did not explain the AWS timestamp mismatch.

### 3. Inspect NTP Synchronization

```bash
timedatectl timesync-status
```

Relevant output:

```text
Server: 185.125.190.56 (ntp.ubuntu.com)
Stratum: 2
Offset: -5.692ms
Delay: 85.303ms
Jitter: 3.339ms
Packet count: 7
```

The NTP client reported a small offset relative to its selected time source.

### 4. Compare Against an External Server

```bash
curl -sI https://aws.amazon.com/ | grep -i '^date:'
```

**Observed:**

```text
date: Thu, 05 Nov 2026 14:18:15 GMT
```

Check the guest system time:

```bash
date -u '+%Y-%m-%d %H:%M:%S UTC'
```

**Observed:**

```text
2026-11-05 11:17:37 UTC
```

The observations were made close together and confirmed an approximately three-hour discrepancy.

### 5. Current Conclusion

The AWS authentication failure is consistent with clock skew between the Ubuntu guest and AWS.

However, the reason for the discrepancy remains unresolved.

Potential areas for further investigation include VirtualBox guest clock handling, host/guest time synchronization, and the NTP synchronization mechanism.

Changing the timezone from `Etc/UTC` to `Asia/Jerusalem` changes local time representation but does not correct an incorrect UTC clock.

**Resolution:** Pending investigation and verification.