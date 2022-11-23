# pathfinder

This app is used to help identify NVM4W installation problems. The executable is not signed, nor is it designed for production user. It is just a troubleshooting tool which is not an officially a supported part of NVM for Windows.

## Usage

[Download pathfinder.exe](https://github.com/coreybutler/nvm-windows/raw/master/utilities/pathfinder/pathfinder.exe) and run it.

The output will look like:

```
> .\pathfinder.exe
PATH directories containing node.exe:

  1. C:\Program Files\nodejs (NVM_SYMLINK)

NVM for Windows is correctly positioned in the PATH.
```

If there is a problem, such as multiple Node installation paths or incorrectly ordered installation paths, this tool will tell you.