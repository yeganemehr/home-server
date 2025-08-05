# 🏠 HOME Server

Turn your Docker image into a bootable OS image - complete with kernel, systemd, and bootloader - for physical machines or VMs.

This project powers my personal home server. It's based on a blog post I wrote:  
👉 [HOWTO boot a Docker image](https://yeganemehr.net/posts/boot-docker-image)

## 🛠️ What This Project Does

- Builds a bootable disk image (`.img`) from a Dockerfile
- Installs a Linux kernel, init system (systemd), and userland tools
- Configures a lightweight bootloader (`extlinux`)
- Automates everything via a Bash script
- Includes a GitHub Actions workflow to rebuild the image on major changes

## 🚀 Quick Start

> ⚠️ **This will overwrite drives if you’re not careful. Test in QEMU first.**

### 1. Build the Disk Image

```bash
./build.sh
```

This creates a `dist/debian.img` file containing:

* A partitioned ext4 filesystem
* Kernel + initrd
* Bootloader + `syslinux.cfg`
* All software defined in the Dockerfile

### 2. Test with QEMU

```bash
qemu-system-x86_64 -hda dist/debian.img -m 512
```

### 4. Write to USB (Be careful!)

```bash
./install-to-usb.sh
```


## 🧠 Why?

This setup started as a "what if": _what if I could convert a Docker image into a bootable OS?_
Turns out, you can. It's not standard, but it works great for:

* VPS images
* Automated provisioning
* Bare-metal recovery systems
* Just geeking out

Read the full blog post for background and a detailed explanation:
📖 [HOWTO boot a Docker image](https://yeganemehr.net/posts/boot-docker-image)


## ✅ Requirements

* Docker
* QEMU (optional, for testing)
* Bash (for `build.sh`)
* `extlinux` / `syslinux` tools
* `losetup`, `mkfs.ext4`, `dd`, etc.


## 📝 License

MIT — feel free to fork, adapt, and experiment. PRs welcome!
