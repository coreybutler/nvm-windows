<h1 align="center">NVM for Windows</h1>

<div align="center">
  The <a href="https://docs.microsoft.com/en-us/windows/nodejs/setup-on-windows">Microsoft</a>/<a href="https://docs.npmjs.com/cli/v7/configuring-npm/install#windows-node-version-managers">npm</a>/Google recommended Node.js version manager for <em>Windows</em>.<br/>

<details>
<summary><b>This is not the same thing as nvm!</b> (expand for details)</summary>

_The original [nvm](https://github.com/nvm-sh/nvm) is a completely separate project for Mac/Linux only._ This project uses an entirely different philosophy and is not just a clone of nvm. Details are listed in [Why another version manager?](#bulb-why-another-version-manager) and [what&#39;s the big difference?](#bulb-whats-the-big-difference).
</details>

[![Download Now](https://img.shields.io/badge/-Download%20Now!-%2322A6F2)](https://github.com/coreybutler/nvm-windows/releases) [![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/coreybutler/nvm-windows?label=Latest%20Release&style=social&x=1)]((https://github.com/coreybutler/nvm-windows/releases)) ![GitHub Release Date](https://img.shields.io/github/release-date/coreybutler/nvm-windows?label=Released&style=social) ![GitHub all releases](https://img.shields.io/github/downloads/coreybutler/nvm-windows/total?label=Downloads&style=social) [![Discuss](https://img.shields.io/badge/-Discuss-blue)](https://github.com/coreybutler/nvm-windows/discussions) [![Twitter URL](https://img.shields.io/twitter/url?style=social&url=https%3A%2F%2Ftwitter.com%2Fintent%2Ftweet%3Fhashtags%3Dnodejs%26original_referer%3Dhttp%253A%252F%252F127.0.0.1%253A91%252F%26text%3DCheck%2520out%2520NVM%2520for%2520Windows%21%26tw_p%3Dtweetbutton%26url%3Dhttp%253A%252F%252Fgithub.com%252Fcoreybutler%252Fnvm-windows%26via%3Dgoldglovecb)](https://twitter.com/intent/tweet?hashtags=nodejs&original_referer=http%3A%2F%2F127.0.0.1%3A91%2F&text=Check%20out%20NVM%20for%20Windows!&tw_p=tweetbutton&url=http%3A%2F%2Fgithub.com%2Fcoreybutler%2Fnvm-windows&via=goldglovecb)
</div>

<h5 align="center">Sponsors</h5>

<div align="center">
  <table cellpadding="5" cellspacing="0" border="0" align="center">
    <tr>
      <td><a href="https://metadoc.io"><img src="https://github.com/coreybutler/staticassets/raw/master/sponsors/metadoclogobig.png" width="200px"/></a></td>
      <td><a href="https://enabledb.com"><img src="https://github.com/coreybutler/staticassets/raw/master/images/logos/logo_enabledb_w_text.png" width="200px"/></a></td>
      <td><a href="https://butlerlogic.com"><img src="https://github.com/coreybutler/staticassets/raw/master/sponsors/butlerlogic_logo.png" width="200px"/></a></td>
      <td width="25%" align="center"><a href="https://github.com/microsoft"><img src="https://user-images.githubusercontent.com/770982/195955265-5c3dca78-7140-4ec6-b05a-f308518643ee.png" height="30px"/></a></td>
    </tr>
    <tr>
      <td colspan="4" align="center">
        <a href="https://github.com/sponsors/coreybutler"><img src="https://img.shields.io/github/sponsors/coreybutler?label=Individual%20Sponsors&logo=github&style=social"/></a>
        &nbsp;<a href="https://github.com/sponsors/coreybutler"><img src="https://img.shields.io/badge/-Become%20a%20Sponsor-yellow"/></a>
      </td>
    </tr>
  </table>
</div>
<br/>

<div align="center"><b>Running into issues?</b> See the <a href="https://github.com/coreybutler/nvm-windows/wiki/Common-Issues">common issues wiki</a>.</div>

<br/>
<table style="background-color:red;padding:6px;border-radius:3px;">
  <tr><td>
    <h3>Seeking Feedback:</h3>
    We're working on <a href="https://github.com/coreybutler/nvm-windows/wiki/Runtime">Runtime (rt)</a>, the successor to NVM For Windows. Please contribute by taking a minute to complete <a href="https://t.co/oGqQCM9FPx">this form</a>. Thank you!
    <h3></h3>
  </td></tr>
</table>

## Overview

Manage multiple installations of node.js on a Windows computer.

**tl;dr** Similar (not identical) to [nvm](https://github.com/creationix/nvm), but for Windows. Has an installer. [Download Now](https://github.com/coreybutler/nvm-windows/releases)!

This has always been a node version manager, not an io.js manager, so there is no back-support for io.js. Node 4+ is supported. Remember when running `nvm install` or `nvm use`, Windows usually requires administrative rights (to create symlinks).

![NVM for Windows](https://github.com/coreybutler/staticassets/raw/master/images/nvm-1.1.8-screenshot.jpg)

There are situations where the ability to switch between different versions of Node.js can be very useful. For example, if you want to test a module you're developing with the latest bleeding edge version without uninstalling the stable version of node, this utility can help.

![Switch between stable and unstable versions.](https://github.com/coreybutler/staticassets/raw/master/images/nvm-usage-highlighted.jpg)

### Installation & Upgrades

#### :star: :star: Uninstall any pre-existing Node installations!! :star: :star:

Uninstall any existing versions of Node.js before installing NVM for Windows (otherwise you'll have conflicting versions). Delete any existing Node.js installation directories (e.g., `%ProgramFiles%\nodejs`) that might remain. NVM's generated symlink will not overwrite an existing (even empty) installation directory.

:eyes: **Backup any global `npmrc` config** :eyes:
(e.g. `%AppData%\npm\etc\npmrc`)

Alternatively, copy the settings to the user config `%UserProfile%\.npmrc`. Delete the existing npm install location (e.g. `%AppData%\npm`) to prevent global module conflicts.

#### Install nvm-windows

Use the [latest installer](https://github.com/coreybutler/nvm/releases) (comes with an uninstaller). Alternatively, follow the  [manual installation](https://github.com/coreybutler/nvm-windows/wiki#manual-installation) guide.

_If NVM4W doesn't appear to work immediately after installation, restart the terminal/powershell (not the whole computer)._

![NVM for Windows Installer](https://github.com/coreybutler/staticassets/raw/master/images/nvm-installer.jpg)

#### Reinstall any global utilities

After install, reinstalling global utilities (e.g. yarn) will have to be done for each installed version of node:

```
nvm use 14.0.0
npm install -g yarn
nvm use 12.0.1
npm install -g yarn
```

### Upgrading nvm-windows

:bulb: _As of v1.1.8, there is an upgrade utility that will automate the upgrade process._

**To upgrade nvm-windows**, run the new installer. It will safely overwrite the files it needs to update without touching your node.js installations. Make sure you use the same installation and symlink folder. If you originally installed to the default locations, you just need to click "next" on each window until it finishes.

### Usage

**nvm-windows runs in an Admin shell**. You'll need to start `powershell` or Command Prompt as Administrator to use nvm-windows

NVM for Windows is a command line tool. Simply type `nvm` in the console for help. The basic commands are:

- **`nvm arch [32|64]`**: Show if node is running in 32 or 64 bit mode. Specify 32 or 64 to override the default architecture.
- **`nvm current`**: Display active version.
- **`nvm install <version> [arch]`**:  The version can be a specific version, "latest" for the latest current version, or "lts" for the most recent LTS version. Optionally specify whether to install the 32 or 64 bit version (defaults to system arch). Set [arch] to "all" to install 32 AND 64 bit versions. Add `--insecure` to the end of this command to bypass SSL validation of the remote download server.
- **`nvm list [available]`**: List the node.js installations. Type `available` at the end to show a list of versions available for download.
- **`nvm on`**: Enable node.js version management.
- **`nvm off`**: Disable node.js version management (does not uninstall anything).
- **`nvm proxy [url]`**: Set a proxy to use for downloads. Leave `[url]` blank to see the current proxy. Set `[url]` to "none" to remove the proxy.
- **`nvm uninstall <version>`**: Uninstall a specific version.
- **`nvm use <version> [arch]`**: Switch to use the specified version. Optionally use `latest`, `lts`, or `newest`. `newest` is the latest _installed_ version. Optionally specify 32/64bit architecture. `nvm use <arch>` will continue using the selected version, but switch to 32/64 bit mode. For information about using `use` in a specific directory (or using `.nvmrc`), please refer to [issue #16](https://github.com/coreybutler/nvm-windows/issues/16).
- **`nvm root <path>`**: Set the directory where nvm should store different versions of node.js. If `<path>` is not set, the current root will be displayed.
- **`nvm version`**: Displays the current running version of NVM for Windows.
- **`nvm node_mirror <node_mirror_url>`**: Set the node mirror.People in China can use *https://npmmirror.com/mirrors/node/*
- **`nvm npm_mirror <npm_mirror_url>`**: Set the npm mirror.People in China can use *https://npmmirror.com/mirrors/npm/*

### :warning: Gotcha!

Please note that any global npm modules you may have installed are **not** shared between the various versions of node.js you have installed. Additionally, some npm modules may not be supported in the version of node you're using, so be aware of your environment as you work.

### :name_badge: Antivirus

Users have reported some problems using antivirus, specifically McAfee. It appears the antivirus software is manipulating access to the VBScript engine. See [issue #133](https://github.com/coreybutler/nvm-windows/issues/133) for details and resolution.

**v1.1.8 is not code signed**, but all other versions are signed by [Ecor Ventures LLC](https://ecorventures.com)/[Author.io](https://author.io). This should help prevent false positives with most antivirus software.

> v1.1.8+ was not code signed due to an expired certificate (see the [release notes](https://github.com/coreybutler/nvm-windows/releases/tag/1.1.8) for reasons). **v1.1.9 _is_ code signed** thanks to [ajyong](https://github.com/ajyong), who sponsored the new certificate.

### Using Yarn

**tldr;** `npm i -g yarn`

See the [wiki](https://github.com/coreybutler/nvm-windows/wiki/Common-Issues#how-do-i-use-yarn-with-nvm-windows) for details.

### Build from source

- Install go from http://golang.org
- Download source / Git Clone the repo
- Change GOARCH to amd64 in build.bat if you feel like building a 64-bit executable
- Fire up a Windows command prompt and change directory to project dir
- Execute `go get github.com/blang/semver`
- Execute `go get github.com/olekukonko/tablewriter`
- Execute `build.bat`
- Check the `dist`directory for generated setup program.

---

## :bulb: Why another version manager?

There are several version managers for node.js. Tools like [nvm](https://github.com/creationix/nvm) and [n](https://github.com/tj/n)
only run on Mac OSX and Linux. Windows users are left in the cold? No. [nvmw](https://github.com/hakobera/nvmw) and [nodist](https://github.com/marcelklehr/nodist)
are both designed for Windows. So, why another version manager for Windows?

The architecture of most node version managers for Windows rely on `.bat` files, which do some clever tricks to set or mimic environment variables. Some of them use node itself (once it's downloaded), which is admirable, but prone to problems. Right around node 0.10.30, the installation structure changed a little, causing some of these to just stop working with anything new.

Additionally, some users struggle to install these modules since it requires a little more knowledge of node's installation structure. I believe if it were easier for people to switch between versions, people might take the time to test their code on back and future versions... which is just good practice.

## :bulb: What's the big difference?

First and foremost, this version of nvm has no dependency on node. It's written in [Go](https://golang.org/), which is a much more structured approach than hacking around a limited `.bat` file. It does not rely on having an existing node installation. Go offers the ability to create a Mac/Linux version on the same code base. In fact, this is already underway.

The control mechanism is also quite different. There are two general ways to support multiple node installations with hot switching capabilities. The first is to modify the system `PATH` any time you switch versions, or bypass it by using a `.bat` file to mimic the node executable and redirect accordingly. This always seemed a little hackish to me, and there are some quirks as a result of this implementation.

The second option is to use a symlink. This concept requires putting the symlink in the system `PATH`, then updating its target to the node installation directory you want to use. This is a straightforward approach, and seems to be what people recommend.... until they realize just how much of a pain symlinks are on Windows. This is why it hasn't happened before.

In order to create/modify a symlink, you must be running as an admin, and you must get around Windows UAC (that annoying prompt). Luckily, this is a challenge I already solved with some helper scripts in [node-windows](https://github.com/coreybutler/node-windows). As a result, NVM for Windows maintains a single symlink that is put in the system `PATH` during installation only. Switching to different versions of node is a matter of switching the symlink target. As a result, this utility does **not** require you to run `nvm use x.x.x` every time you open a console window. When you _do_ run `nvm use x.x.x`, the active version of node is automatically updated across all open console windows. It also persists between system reboots, so you only need to use nvm when you want to make a change.

NVM for Windows comes with an installer, courtesy of a byproduct of my work on [Fenix Web Server](https://preview.fenixwebserver.com).

Overall, this project brings together some ideas, a few battle-hardened pieces of other modules, and support for newer versions of node.

NVM for Windows recognizes the "latest" versions using a [list](https://nodejs.org/download/release/index.json) provided by the Node project. Version 1.1.1+ use this list. Before this list existed, I was scraping releases and serving it as a standalone [data feed](https://github.com/coreybutler/nodedistro). This list was used in versions 1.1.0 and prior, but is now deprecated.

## Motivation

I needed it, plain and simple. Additionally, it's apparent that [support for multiple versions](https://github.com/nodejs/node-v0.x-archive/issues/8075) is not coming to node core. It was also an excuse to play with Go.

## Why Go? Why not Node?

I chose Go because it is cross-platform, felt like less overhead than Java, has been around longer than most people think. Plus, I wanted to experiment with it. I've been asked why I didn't write it with Node. Trying to write a tool with the tool you're trying to install doesn't make sense to me. As a result, my project requirements for this were simple... something that's not Node. Node will continue to evolve and change. If you need a reminder of that, remember io.js, Ayo, all the breaking changes between 4.x.x and 6.x.x, and the shift to ES Modules in 12+. Change is inevitable in the world of software. JavaScript is extremely dynamic.

## :pray: Thanks

Thanks to everyone who has submitted issues on and off Github, made suggestions, and generally helped make this a better project. Special thanks to

- [@vkbansal](https://github.com/vkbansal), who provided significant early feedback throughout the early releases.
- [@rainabba](https://github.com/rainabba) and [@sullivanpt](https://github.com/sullivanpt) for getting Node v4 support integrated.
- [@s-h-a-d-o-w](https://github.com/s-h-a-d-o-w) who resolved the longstanding space escaping issue in path names ([#355](https://github.com/coreybutler/nvm-windows/pull/355)).
- [ajyong](https://github.com/ajyong) who sponsored the code signing certificate in late 2021.

<br/>

![Contributors](https://contrib.rocks/image?repo=coreybutler/nvm-windows)
