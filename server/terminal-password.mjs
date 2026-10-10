import { stdin, stdout } from 'node:process';

export async function hiddenPassword(prompt) {
  if (!stdin.isTTY) throw new Error('Run this command in an interactive terminal; passwords are not accepted as command-line arguments.');
  stdout.write(prompt);
  stdin.setRawMode(true); stdin.resume(); stdin.setEncoding('utf8');
  return new Promise((resolve, reject) => {
    let value = '';
    const cleanup = () => { stdin.off('data', receive); stdin.setRawMode(false); stdin.pause(); stdout.write('\n'); };
    const receive = chunk => {
      for (const char of chunk) {
        if (char === '\u0003') { cleanup(); reject(new Error('Cancelled.')); return; }
        if (char === '\r' || char === '\n') { cleanup(); resolve(value); return; }
        if (char === '\u007f' || char === '\b') value = [...value].slice(0, -1).join('');
        else if (char >= ' ') value += char;
      }
    };
    stdin.on('data', receive);
  });
}
