// This is a deno helper script to locally build the installer using Inno Setup
// Yeah, I know  it's not Node, but we need to compile this and Node SEAs on Win32 are a PITA.
const content = await Deno.readTextFile('./nvm.iss')
const data = JSON.parse(await Deno.readTextFile('./src/manifest.json'))
const {version} = data
const output = content.replaceAll('{{VERSION}}', version)
await Deno.writeTextFile('./.tmp.iss', output)

console.log('Viewing /.tmp.iss')
output.split("\n").forEach((line, num) => {
  let n = `${num+1}`
  while (n.length < 3) {
    n = ' ' + n
  }

  console.log(`${n} | ${line}`)
})

const command = await new Deno.Command('.\\assets\\buildtools\\iscc.exe', {
  args: ['.\\.tmp.iss'],
  stdout: 'piped',
  stderr: 'piped',
})

const process = command.spawn();

// Stream stdout
(async () => {
  const decoder = new TextDecoder();
  for await (const chunk of process.stdout) {
    console.log(decoder.decode(chunk));
  }
})();

// Stream stderr
(async () => {
  const decoder = new TextDecoder();
  for await (const chunk of process.stderr) {
    console.error(decoder.decode(chunk));
  }
})();

// Wait for completion
const status = await process.status;
Deno.remove('.\\.tmp.iss');
if (!status.success) {
  Deno.exit(status.code);
}
