# Node Version Manager (nvm) for Windows

Manage multiple installations of node.js on a Windows computer.

**tl;dr** This is the Windows version of [nvm](https://github.com/creationix/nvm).

There are situations where the ability to switch between different versions of Node.js can be very
useful and save a lot of time. For example, if you want to test a module you're developing with the latest
bleeding edge version without uninstalling the stable version of node, this utility can help.

### Installation

Download the latest from the [releases](https://github.com/coreybutler/nvm/releases) and run the installer.

### Usage

nvm for Windows is a command line tool. Simply type `nvm` in the console for help. The basic commands are:

- `nvm install <version>`: Install a specific version, i.e. `0.10.32`. This will also accept `latest`, which will install the latest stable version.
- `nvm uninstall <version>`: Uninstall a specific version.
- `nvm use <version>`: Switch to a specific version of node.
- `nvm list <installed | available>`: List the versions of node that are currently installed or the versions available from nodejs.org.
- `nvm on`: Turn on nvm management.
- `nvm off`: Turn off nvm entirely.

### Gotcha!

Please note that any global npm modules you may have installed are **not** shared between the various versions of node.js installed.

---

## Why another version manager?

There are several version managers for node.js. Tools like [nvm](https://github.com/creationix/nvm) and [n](https://github.com/visionmedia/n)
are specifically designed for Mac OSX and Linux. [nvmw](https://github.com/hakobera/nvmw) and [nodist](https://github.com/marcelklehr/nodist)
are both designed for Windows. So, why another version manager for Windows?

Right around node 0.10.30, the installation structure changed a little, causing some issues with the other modules. Additionally, some users
struggle to install those modules. The architecture of most node managers on Windows focus primarily around the use of `bat` files, which
do some clever hackery to set environment variables. Some of them use node itself (once it's downloaded), which is admirable, but prone to
problems.

## What's the difference?

First and foremost, this version of nvm has no dependency on node. It's written in [Go](http://golang.org/), which is a much more structured
approach than using a `.bat` file. It does not rely on having an existing node installation. Plus, the potential for creating a
Mac/Linux version is substanially easier than converting a bunch of `.bat --> .sh` logic.

The approach is also quite different. There are two general ideas for supporting multiple node installations and readily switching between them.
One is to modify the system `PATH` any time you switch versions. This always seemed a little hackish to me, and it has some quirks. The other option
is to use a symlink. This concept requires one to put the symlink in the system `PATH`, then just update the symlink to point to whichever node
installation directory you want to use. This is a more straightforward approach, and the one most people recommend.... until they realize just how much
of a pain symlinks are on Windows. In order to create/modify a symlink, you must be running as an admin, and you must get around Windows UAC (that
annoying prompt). Luckily, this is a challenge I already solved with some helper scripts in [node-windows](http://github.com/coreybutler/node-windows).

This version of of nvm for Windows comes with an installer, courtesy of a byproduct of the node-webkit work I did on [Fenix Web Server](http://fenixwebserver.com).

Overall, this project brings together some robust new technology, a few battle-hardened pieces of other modules, and support for newer versions of node.

## Why?

I needed it, plain and simple. Additionally, it's apparent that [support for multiple versions](https://github.com/joyent/node/issues/8075) is not
coming to node core. It was also an excuse to play with Go :)

## License

MIT. See the LICENSE file.
