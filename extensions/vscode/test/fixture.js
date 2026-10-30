'use strict';
const { createRouter } = require('../router');
const { createFake } = require('./fake-vscode');
const fs = require('node:fs');
const path = require('node:path');
const fake = createFake([Number(process.argv[3]), 123456]);
const show = fake.window.terminals[0].show;
fake.window.terminals[0].show = function(focus) { show(focus); fs.writeFileSync(path.join(process.argv[2], 'focused'), 'correct-terminal'); };
createRouter(fake, { root: process.argv[2] }).then(router => {
  process.stdout.write('READY\n');
  process.on('SIGTERM', () => { router.dispose(); process.exit(0); });
}).catch(error => { process.stderr.write(String(error)); process.exit(1); });
