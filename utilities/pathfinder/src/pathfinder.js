const paths = new Set()
const symlinks = new Set()
const nvm4w = new Set()

// Identify paths with node.exe
const sources = new Set(Deno.env.get('PATH').split(';'))
for (const dir of sources.values()) {
  try {
    await Deno.stat(`${dir}\\node.exe`)
    paths.add(dir)

    const i = await Deno.lstat(dir)
    if (i.isSymlink) {
      symlinks.add(dir)
      const real = await Deno.realPath(dir)

      try {
        await Deno.stat(`${real}\\..\\nvm.exe`)
        nvm4w.add(dir)
      } catch (e) {}
    }
  } catch (e) {}
}

const directories = Array.from(paths)

let ok = false

console.log('PATH directories containing node.exe:\n')

for (const key in directories) {
  const dir = directories[key]
  const isnvm4w = nvm4w.has(dir)
  const i = parseInt(key, 10)

  if (i === 0 && isnvm4w) {
    ok = true
  }

  console.log(`  ${i + 1}. ${dir}${isnvm4w ? ' (NVM_SYMLINK)' : ''}`)
}

if (ok) {
  console.log('\nNVM for Windows is correctly positioned in the PATH.')
} else {
  console.log('\nNVM for Windows is INCORRECTLY positioned in the PATH (must be first)')
  console.log('A prior/alternative installation of Node.js may be preventing NVM for Windows from functioning.')
}
