[![Tweet This!][1.1] Tweet This!][1]
[1.1]: http://i.imgur.com/wWzX9uB.png (Tweet about NVM for Windows)
[1]: https://twitter.com/intent/tweet?hashtags=nodejs&original_referer=http%3A%2F%2F127.0.0.1%3A91%2F&text=Check%20out%20NVM%20for%20Windows!&tw_p=tweetbutton&url=http%3A%2F%2Fgithub.com%2Fcoreybutler%2Fnvm-windows&via=goldglovecb

[Become a Patron](https://patreon.com/coreybutler)

## A note on Antivirus

Several users have noticed this app being flagged as a false positive by different antivirus apps. It turns out these antivirus vendors are flagging the signature of the entire Go programming language.... basically everything written in Go is marked as a virus. See [golang/go#16292](https://github.com/golang/go/issues/16292). Details about how NVM4W is dealing with this are available in [issue #182](https://github.com/coreybutler/nvm-windows/issues/182).

**Thanks to several users who have submitted false positive reports, this issue is gradually going away. The latest definitions for Windows Defender, Avast!, and MalwareBytes have all whitelisted the app.**

## NOTICE: SEEKING CORE CONTRIBUTORS & MAINTAINERS

_Are you multilingual?_

I am particularly interested in finding people who can speak something other than English. Several problems have come up with non-latin character sets (Chinese, Japanese, Arabic, etc). I am also interested in producing language packs/translations for the installers.

_Are you outside of the US/UK/Canada?_

Custom mirroring capabilities are available in the master branch, but I would like to work with folks in different geographic regions to assure node is accessible everywhere.

_Other (Anywhere)_

The core concepts of this version manager are pretty simple, so the core code base is pretty focused/simple. I've done some work to make this project available on all operating systems. The only reason it's been so slow to release is anticipation of an explosion of new installers (chocolatey, homebrew, rpm, .deb, .msi, etc). I've partnered up with BitRock to simplify creation of some of these, but the BitRock installers don't support all of these.

Of course, I would also love to have additional maintainers. If you're new to Go, that's OK - I was too, and that's what code reviews are for.

# Node Version Manager (nvm) for Windows

[![Gitter](https://badges.gitter.im/Join Chat.svg)](https://gitter.im/coreybutler/nvm-windows?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) (I post development updates here)

Manage multiple installations of node.js on a Windows computer.

**tl;dr** [nvm](https://github.com/creationix/nvm), but for Windows, with an installer. [Download Now](https://github.com/coreybutler/nvm-windows/releases)! This has always been a node version manager, not an io.js manager, so there is no back-support for io.js. However, node 4+ is supported.

![NVM for Windows](http://coreybutler.github.io/nvm-windows/images/installlatest.jpg)

There are situations where the ability to switch between different versions of Node.js can be very
useful. For example, if you want to test a module you're developing with the latest
bleeding edge version without uninstalling the stable version of node, this utility can help.

![Switch between stable and unstable versions.](http://coreybutler.github.io/nvm-windows/images/use.jpg)

### Installation & Upgrades

It comes with an installer (and uninstaller), because getting it should be easy. Please note, you need to uninstall any existing versions of node.js before installing NVM for Windows.

You should also delete the existing npm install location (e.g. "C:\Users\<user>\AppData\Roaming\npm") so that the nvm install location will be correctly used instead. After install, reinstalling global utilities (e.g. gulp) will have to be done for each installed version of node:

`nvm use 4.4.0`
`npm install gulp-cli -g`
`nvm use 0.10.33`
`npm install gulp-cli -g`

[Download the latest installer from the releases](https://github.com/coreybutler/nvm/releases).

![NVM for Windows Installer](http://coreybutler.github.io/nvm-windows/images/installer.jpg)

**To upgrade**, run the new installer. It will safely overwrite the files it needs to update without touching your node.js installations.
Make sure you use the same installation and symlink folder. If you originally installed to the default locations, you just need to click
"next" on each window until it finishes.

### Usage

NVM for Windows is a command line tool. Simply type `nvm` in the console for help. The basic commands are:

- `nvm arch [32|64]`: Show if node is running in 32 or 64 bit mode. Specify 32 or 64 to override the default architecture.
- `nvm install <version> [arch]`: The version can be a node.js version or "latest" for the latest stable version. Optionally specify whether to install the 32 or 64 bit version (defaults to system arch). Set `[arch]` to "all" to install 32 AND 64 bit versions.
- `nvm list [available]`: List the node.js installations. Type `available` at the end to show a list of versions available for download.
- `nvm on`: Enable node.js version management.
- `nvm off`: Disable node.js version management (does not uninstall anything).
- `nvm proxy [url]`: Set a proxy to use for downloads. Leave `[url]` blank to see the current proxy. Set `[url]` to "none" to remove the proxy.
- `nvm uninstall <version>`: Uninstall a specific version.
- `nvm use <version> [arch]`: Switch to use the specified version. Optionally specify 32/64bit architecture. `nvm use <arch>` will continue using the selected version, but switch to 32/64 bit mode based on the value supplied to `<arch>`.
- `nvm root <path>`: Set the directory where nvm should store different versions of node.js. If `<path>` is not set, the current root will be displayed.
- `nvm version`: Displays the current running version of NVM for Windows.

### Gotcha!

Please note that any global npm modules you may have installed are **not** shared between the various versions of node.js you have installed.
Additionally, some npm modules may not be supported in the version of node you're using, so be aware of your environment as you work.

### Antivirus

Users have reported some problems using antivirus, specifically McAffee. It appears the antivirus software is manipulating access to the VBScript engine. See [issue #133](https://github.com/coreybutler/nvm-windows/issues/133) for details and resolution.

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
approach than hacking around a limited `.bat` file. It does not rely on having an existing node installation. Plus, should the need arise, Go
offers potential for creating a Mac/Linux version on the same code base with a substanially easier migration path than converting a bunch of
batch to shell logic. `bat > sh, it crazy, right?`

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

I also wrote a simple [data feed](https://github.com/coreybutler/nodedistro) containing a list of node.js versions and their associated npm version.
This is how NVM for Windows recognizes the "latest" stable version. It's free for anyone to use.

## Motivation

I needed it, plain and simple. Additionally, it's apparent that [support for multiple versions](https://github.com/nodejs/node-v0.x-archive/issues/8075) is not
coming to node core, or even something they care about. It was also an excuse to play with Go.

## Why Go? Why not Node?

I chose Go because it is cross-platform, felt like less overhead than Java, has been around longer than most people think, and I wanted to experiment with it. I've been asked why I didn't write it with Node. Trying to write a tool with the tool you're trying to install doesn't make sense to me. As a result, my project requirements for this were simple... something that's not Node. Node will continue to evolve and change. If you need a reminder of that, io.js. Or consider all the breaking changes between 4.x.x and 6.x.x. These are inevitable in the world of software.

## License

MIT.

## Thanks

Thanks to everyone who has submitted issues on and off Github, made suggestions, and generally helped make this a better project. Special thanks to [@vkbansal](https://github.com/vkbansal), who has actively provided feedback throughout the releases. Thanks also go to [@rainabba](https://github.com/rainabba) and [@sullivanpt](https://github.com/sullivanpt) for getting Node v4 support integrated.

## Alternatives

- [nodist](https://github.com/marcelklehr/nodist) - Windows Only
- [nvm](https://github.com/creationix/nvm) - Mac/Linux Only
- [n](https://github.com/visionmedia/n) - Mac/Linux Only
