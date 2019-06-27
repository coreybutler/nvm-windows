The npm/Microsoft/Google recommended **Node.js version manager for _Windows_**.

# This is not the same thing as [nvm](https://github.com/creationix/nvm), which is a completely separate project for Mac/Linux only.

Like this project? Let people know with a [tweet](https://twitter.com/intent/tweet?hashtags=nodejs&original_referer=http%3A%2F%2F127.0.0.1%3A91%2F&text=Check%20out%20NVM%20for%20Windows!&tw_p=tweetbutton&url=http%3A%2F%2Fgithub.com%2Fcoreybutler%2Fnvm-windows&via=goldglovecb). Better yet, [support the effort on Patreon](https://patreon.com/coreybutler).

## NOTICES

_Are you multilingual?_

~~I am particularly interested in finding people who can speak something other than English. Several problems have come up with non-latin character sets (Chinese, Japanese, Arabic, etc). I am also interested in producing language packs/translations for the installers. If you are interested in translating, please [signup here](https://coreybutler.typeform.com/to/ybqT6F).~~

_The response for multilingual contributions has been phenomenal_. However; due to the necessarily slow pace of development (see "other" below), multilingual support won't arrive until 2.0.0 (which will likely be a cross-platform version manager with a new name).

~~**I am seeking donations to help pay for a lingohub.com account** to make life easier for translators! Please consider becoming a [becoming a patron](https://patreon.com/coreybutler) to support this.~~

_Are you outside of the US/UK/Canada?_

Custom mirroring capabilities are available in the master branch, but I would like to work with folks in different geographic regions to assure node is accessible everywhere.

_Other (Anywhere)_

The core concepts of this version manager are pretty simple, so the core code base is pretty focused/simple. I've done some work to make this project available on all operating systems. The only reason it's been so slow to release is anticipation of an explosion of new installers (chocolatey, homebrew, rpm, .deb, .msi, etc). I've partnered up with BitRock to simplify creation of some of these, but the BitRock installers don't support all of these.

Of course, I would also love to have additional maintainers. I greatly appreciate the existing maintainers who are answering questions and responding to issues, but be advised I have always been and am currently the only person working on new feature development (aside from some incredible contributions from people). I've been preoccupied with paid contract work to a) live and b) bootstrap [author.io](https://author.io) (a company to support this project and several others). My time has been very limited.

# Node Version Manager (nvm) for Windows

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/coreybutler/nvm-windows?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) (I post development updates here)

![Issues](https://img.shields.io/github/issues/coreybutler/nvm-windows.svg)
![Stars](https://img.shields.io/github/stars/coreybutler/nvm-windows.svg)
[![Open Source Helpers](https://www.codetriage.com/coreybutler/nvm-windows/badges/users.svg)](https://www.codetriage.com/coreybutler/nvm-windows)

Manage multiple installations of node.js on a Windows computer.

**tl;dr** [nvm](https://github.com/creationix/nvm), but for Windows, with an installer. [Download Now](https://github.com/coreybutler/nvm-windows/releases)! This has always been a node version manager, not an io.js manager, so there is no back-support for io.js. However, node 4+ is supported.

![NVM for Windows](http://i.imgur.com/BNlcbi4.png)

There are situations where the ability to switch between different versions of Node.js can be very
useful. For example, if you want to test a module you're developing with the latest
bleeding edge version without uninstalling the stable version of node, this utility can help.

![Switch between stable and unstable versions.](http://i.imgur.com/zHEz8Oq.png)

### Installation & Upgrades

#### Uninstall existing node

Please note, you need to uninstall any existing versions of node.js before installing NVM for Windows. Also delete any existing nodejs installation directories (e.g., "C:\Program Files\nodejs") that might remain. NVM's generated symlink will not overwrite an existing (even empty) installation directory.

#### Uninstall existing npm

You should also delete the existing npm install location (e.g. "C:\Users\<user>\AppData\Roaming\npm") so that the nvm install location will be correctly used instead. 

#### Install nvm-windows

[Download the latest nvm-windows installer](https://github.com/coreybutler/nvm/releases) and install it.

![NVM for Windows Installer](http://i.imgur.com/x8EzjSC.png)

#### Reinstall any global utilities

After install, reinstalling global utilities (e.g. gulp) will have to be done for each installed version of node:

```
nvm use 4.4.0
npm install gulp-cli -g
nvm use 0.10.33
npm install gulp-cli -g
```

#### Using Yarn

If you're using yarn, just `npm i -g yarn`

See the [wiki](https://github.com/coreybutler/nvm-windows/wiki/Common-Issues#how-do-i-use-yarn-with-nvm-windows) for details.

### Upgrading nvm-windows

**To upgrade nvm-windows**, run the new installer. It will safely overwrite the files it needs to update without touching your node.js installations. Make sure you use the same installation and symlink folder. If you originally installed to the default locations, you just need to click "next" on each window until it finishes.

### Usage

**nvm-windows runs in an Admin shell**. You'll need to start `powershell` or Command Prompt as Administrator to use nvm-windows

NVM for Windows is a command line tool. Simply type `nvm` in the console for help. The basic commands are:

- `nvm arch [32|64]`: Show if node is running in 32 or 64 bit mode. Specify 32 or 64 to override the default architecture.
- `nvm install <version> [arch]`: The version can be a node.js version or "latest" for the latest stable version. Optionally specify whether to install the 32 or 64 bit version (defaults to system arch). Set `[arch]` to "all" to install 32 AND 64 bit versions.
- `nvm list [available]`: List the node.js installations. Type `available` at the end to show a list of versions available for download.
- `nvm on`: Enable node.js version management.
- `nvm off`: Disable node.js version management (does not uninstall anything).
- `nvm proxy [url]`: Set a proxy to use for downloads. Leave `[url]` blank to see the current proxy. Set `[url]` to "none" to remove the proxy.
- `nvm uninstall <version>`: Uninstall a specific version.
- `nvm use <version> [arch]`: Switch to use the specified version. Optionally specify 32/64bit architecture. `nvm use <arch>` will continue using the selected version, but switch to 32/64 bit mode based on the value supplied to `<arch>`. For information about using `use` in a specific directory (or using `.nvmrc`), please refer to [issue #16](https://github.com/coreybutler/nvm-windows/issues/16).
- `nvm root <path>`: Set the directory where nvm should store different versions of node.js. If `<path>` is not set, the current root will be displayed.
- `nvm version`: Displays the current running version of NVM for Windows.
- `nvm node_mirror <node_mirror_url>`: Set the node mirror.People in China can use *https://npm.taobao.org/mirrors/node/*
- `nvm npm_mirror <npm_mirror_url>`: Set the npm mirror.People in China can use *https://npm.taobao.org/mirrors/npm/*

### Gotcha!

Please note that any global npm modules you may have installed are **not** shared between the various versions of node.js you have installed. Additionally, some npm modules may not be supported in the version of node you're using, so be aware of your environment as you work.

### Antivirus

Users have reported some problems using antivirus, specifically McAfee. It appears the antivirus software is manipulating access to the VBScript engine. See [issue #133](https://github.com/coreybutler/nvm-windows/issues/133) for details and resolution.

As of 1.1.7, the executable and installation files are code-signed by [Ecor Ventures LLC](https://ecorventures.com)/[Author.io](https://author.io). This should help prevent false positives with most antivirus software.


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



## Why another version manager?

There are several version managers for node.js. Tools like [nvm](https://github.com/creationix/nvm) and [n](https://github.com/tj/n)
only run on Mac OSX and Linux. Windows users are left in the cold? No. [nvmw](https://github.com/hakobera/nvmw) and [nodist](https://github.com/marcelklehr/nodist)
are both designed for Windows. So, why another version manager for Windows?

The architecture of most node version managers for Windows rely on `.bat` files, which do some clever tricks to set or mimic environment variables.
Some of them use node itself (once it's downloaded), which is admirable, but prone to problems. Right around node 0.10.30, the installation
structure changed a little, causing some of these to just stop working with anything new.

Additionally, some users struggle to install these modules since it requires a little more knowledge of node's installation structure. I believe if it
were easier for people to switch between versions, people might take the time to test their code on back and future versions... which is
just good practice.

## What's the big difference?

First and foremost, this version of nvm has no dependency on node. It's written in [Go](https://golang.org/), which is a much more structured
approach than hacking around a limited `.bat` file. It does not rely on having an existing node installation. Go
offers the ability to create a Mac/Linux version on the same code base. In fact, this is already underway.

The control mechanism is also quite different. There are two general ways to support multiple node installations with hot switching capabilities.
The first is to modify the system `PATH` any time you switch versions, or bypass it by using a `.bat` file to mimic the node executable and redirect
accordingly. This always seemed a little hackish to me, and there are some quirks as a result of this implementation.

The second option is to use a symlink. This concept requires putting the symlink in the system `PATH`, then updating its target to
the node installation directory you want to use. This is a straightforward approach, and seems to be what people recommend.... until they
realize just how much of a pain symlinks are on Windows. This is why it hasn't happened before.

In order to create/modify a symlink, you must be running as an admin, and you must get around Windows UAC (that annoying prompt). Luckily, this is
a challenge I already solved with some helper scripts in [node-windows](https://github.com/coreybutler/node-windows). As a result, NVM for Windows
maintains a single symlink that is put in the system `PATH` during installation only. Switching to different versions of node is a matter of
switching the symlink target. As a result, this utility does **not** require you to run `nvm use x.x.x` every time you open a console window.
When you _do_ run `nvm use x.x.x`, the active version of node is automatically updated across all open console windows. It also persists
between system reboots, so you only need to use nvm when you want to make a change.

NVM for Windows comes with an installer, courtesy of a byproduct of my work on [Fenix Web Server](http://fenixwebserver.com).

Overall, this project brings together some ideas, a few battle-hardened pieces of other modules, and support for newer versions of node.

NVM for Windows recognizes the "latest" versions using a [list](https://nodejs.org/download/release/index.json) provided by the Node project. Version 1.1.1+ use this list. Before this list existed, I was scraping releases and serving it as a standalone [data feed](https://github.com/coreybutler/nodedistro). This list was used in versions 1.1.0 and prior, but is now deprecated.

## Motivation

I needed it, plain and simple. Additionally, it's apparent that [support for multiple versions](https://github.com/nodejs/node-v0.x-archive/issues/8075) is not
coming to node core, or even something they care about. It was also an excuse to play with Go.

## Why Go? Why not Node?

I chose Go because it is cross-platform, felt like less overhead than Java, has been around longer than most people think, and I wanted to experiment with it. I've been asked why I didn't write it with Node. Trying to write a tool with the tool you're trying to install doesn't make sense to me. As a result, my project requirements for this were simple... something that's not Node. Node will continue to evolve and change. If you need a reminder of that, io.js. Or consider all the breaking changes between 4.x.x and 6.x.x. These are inevitable in the world of software.

## License

MIT.

## Thanks

Thanks to everyone who has submitted issues on and off Github, made suggestions, and generally helped make this a better project. Special thanks to 

- [@vkbansal](https://github.com/vkbansal), who provided significant early feedback throughout the early releases.
- [@rainabba](https://github.com/rainabba) and [@sullivanpt](https://github.com/sullivanpt) for getting Node v4 support integrated.
- [@s-h-a-d-o-w](https://github.com/s-h-a-d-o-w) who resolved the longstanding space escaping issue in path names ([#355](https://github.com/coreybutler/nvm-windows/pull/355)).
