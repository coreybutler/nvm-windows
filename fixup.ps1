"Before:"
dir env:NVM*

$nvmhome = $env:NVM_HOME
$old = $env:NVM_SYMLINK
$new = $nvmhome.Replace('nvm','nodejs')
$env:NVM_SYMLINK = $new
$env:Path = $env:Path.Replace($old, $new)

""
"After:"
dir env:NVM*
