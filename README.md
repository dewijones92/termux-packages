<!-- ───────────────────────── FORK NOTE ───────────────────────── -->
# Fork: Android API 23 (Android 6.0) native build

This fork adds a workflow ([`.github/workflows/build-native-api23.yml`](.github/workflows/build-native-api23.yml))
that builds the native runtime — **CPython, ffmpeg, quickjs-ng, aria2** — from source targeting
**Android API 23 (Android 6.0)**, below Termux's normal API-24 floor. It's **L1** of a stack that
runs yt-dlp on old Android (consumed by the
[youtubedl-android fork](https://github.com/dewijones92/youtubedl-android)).

The only change to make it work is pinning `TERMUX_PKG_API_LEVEL=23`: CPython's `configure` then
feature-detects the API-24 libc functions (`lockf`, `preadv`, …) as absent and uses fallbacks, so
the binaries have **zero undefined API-24 symbols** — no post-hoc shim needed.

### Supported ABIs

| ABI | Status |
|---|---|
| `arm64-v8a` (aarch64) | ✅ builds, 0 undefined symbols |
| `x86_64` | ✅ builds, 0 undefined symbols |
| **`armeabi-v7a` (32-bit ARM)** | ❌ **not supported** — see below |
| **`x86` (i686, 32-bit)** | ❌ **not supported** — see below |

This fork ships the **64-bit ABIs only**: `arm64-v8a` (real devices) and `x86_64` (emulator).

### Why no 32-bit ABIs

Both 32-bit ABIs reference libc symbols **bionic only added at API 24** (`@LIBC_N`), used
*unconditionally* by the toolchain / libc++, so they can't be satisfied at API 23:

- **`armeabi-v7a`** — the ARM-EABI memory helpers `__aeabi_memcpy`/`memset`/`memmove*`/`memclr*`.
  A 32-bit lib (e.g. `libncursesw.so`) ends up with unresolved `__aeabi_memcpy@LIBC_N`; the link
  fails (`--no-allow-shlib-undefined`) and it would crash on-device even if forced.
- **`x86` (i686)** — `fseeko`/`ftello` (large-file I/O), which libc++'s `<fstream>` uses
  unconditionally: `error: no member named 'fseeko'` when any C++ code (e.g. aria2) includes it.

The **64-bit ABIs never reference these** (64-bit `off_t` is already large; no `__aeabi_*`), so they
build cleanly. Fixing 32-bit would mean backfilling versioned `@LIBC_N` symbols or an older NDK —
non-trivial, and the 32-bit device base is small, so this fork omits both 32-bit ABIs.

<!-- ─────────────────────── END FORK NOTE ─────────────────────── -->

# Termux packages

![GitHub repo size](https://img.shields.io/github/repo-size/termux/termux-packages)
[![Packages last build status](https://github.com/termux/termux-packages/actions/workflows/packages.yml/badge.svg?branch=master)](https://github.com/termux/termux-packages/actions)
[![Docker image status](https://github.com/termux/termux-packages/workflows/Docker%20image/badge.svg)](https://hub.docker.com/r/termux/package-builder)
[![Repology metadata](https://github.com/termux/repology-metadata/workflows/Repology%20metadata/badge.svg)](https://repology.org/repository/termux)

[![Join the Termux Discord server](https://img.shields.io/discord/641256914684084234.svg?label=&logo=discord&logoColor=ffffff&color=5865F2)](https://discord.gg/HXpF69X)
[![Join the Termux space on Matrix](https://img.shields.io/badge/Matrix-%E2%80%8B?style=plastic&logo=matrix&logoColor=white&color=green)](https://matrix.to/#/#Termux:matrix.org)
[![Join the Termux server on Telegram](https://img.shields.io/badge/Telegram-%E2%80%8B?style=plastic&logo=telegram&logoColor=white&color=blue)](https://t.me/termux24x7)
[![Official subreddit](https://img.shields.io/badge/Reddit-%E2%80%8B?style=plastic&logo=reddit&logoColor=white&color=red)](https://www.reddit.com/r/termux/)

[![Repository status](https://repology.org/badge/repository-big/termux.svg)](https://repology.org/repository/termux)

<img src=".github/static/hosted-by-hetzner.png" alt="Hosted by Hetzner" width="128px"></img>

This project contains scripts and patches to build packages for the [Termux](https://github.com/termux/termux-app)
Android application.

Quick how-to about Termux package management is available at [Package Management](https://github.com/termux/termux-packages/wiki/Package-Management). It also has info on how to fix **`repository is under maintenance or down`** errors when running `apt` or `pkg` commands.

## Contributing

Read [CONTRIBUTING.md](/CONTRIBUTING.md) and [Developer's Wiki](https://github.com/termux/termux-packages/wiki) for more details.

## Community

The Termux Community docs are available [here](https://github.com/termux/termux-community/blob/site/site/pages/en/index.md).

**All our community members must follow the rules that are defined [here](https://github.com/termux/termux-community/blob/site/site/pages/en/rules/index.md) and any [Content Not Allowed](https://github.com/termux/termux-community/blob/site/site/pages/en/rules/index.md#8-content-not-allowed) must not be posted.**
##



## Sponsors and Funders

[<img alt="GitHub Accelerator" width="25%" src="site/assets/sponsors/github.png" />](https://github.com)  
*[GitHub Accelerator](https://github.com/accelerator) ([1](https://github.blog/2023-04-12-github-accelerator-our-first-cohort-and-whats-next))*

&nbsp;

[<img alt="GitHub Secure Open Source Fund" width="25%" src="site/assets/sponsors/github.png" />](https://github.com)  
*[GitHub Secure Open Source Fund](https://resources.github.com/github-secure-open-source-fund) ([1](https://github.blog/open-source/maintainers/securing-the-supply-chain-at-scale-starting-with-71-important-open-source-projects), [2](https://termux.dev/en/posts/general/2025/08/11/termux-selected-for-github-secure-open-source-fund-session-2.html))*

&nbsp;

[<img alt="NLnet NGI Mobifree" width="25%" src="site/assets/sponsors/nlnet-ngi-mobifree.png" />](https://nlnet.nl/mobifree)  
*[NLnet NGI Mobifree](https://nlnet.nl/mobifree) ([1](https://nlnet.nl/news/2024/20241111-NGI-Mobifree-grants.html), [2](https://termux.dev/en/posts/general/2024/11/11/termux-selected-for-nlnet-ngi-mobifree-grant.html))*

&nbsp;

[<img alt="Cloudflare" width="25%" src="site/assets/sponsors/cloudflare.png" />](https://www.cloudflare.com)  
*[Cloudflare](https://www.cloudflare.com) ([1](https://packages-cf.termux.dev))*

&nbsp;

[<img alt="Warp" width="25%" src="https://github.com/warpdotdev/brand-assets/blob/640dffd347439bbcb535321ab36b7281cf4446c0/Github/Sponsor/Warp-Github-LG-03.png" />](https://www.warp.dev/?utm_source=github&utm_medium=readme&utm_campaign=termux)  
[*Warp, built for coding with multiple AI agents*](https://www.warp.dev/?utm_source=github&utm_medium=readme&utm_campaign=termux)
