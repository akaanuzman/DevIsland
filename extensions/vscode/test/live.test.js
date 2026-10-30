'use strict';
// Runs only in an isolated VS Code extension test host, never in a user's terminals.
const vscode = require('vscode');
const fs = require('node:fs');
const net = require('node:net');
const assert = require('node:assert/strict');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
exports.run = async function () {
  const ext = vscode.extensions.getExtension('dev-island-local.terminal-router');
  assert.ok(ext, 'Development extension not loaded');
  const api = await ext.activate(); assert.ok(api, 'Extension did not activate');
  const first = vscode.window.createTerminal({ name: 'Dev Island owned test A', shellPath: '/bin/zsh', shellArgs: ['-f'] });
  const second = vscode.window.createTerminal({ name: 'Dev Island owned test B', shellPath: '/bin/zsh', shellArgs: ['-f'] });
  try {
    const pids = [await first.processId, await second.processId];
    await api.refresh();
    const record = JSON.parse(fs.readFileSync(api.registryPath));
    for (const pid of [pids[1],pids[0]]) {
      const terminal = record.terminals.find(t => t.processID === pid); assert.ok(terminal, 'Terminal not registered');
      const request = { version:1, action:'focus', requestID: 'live-' + pid, windowID:record.windowID, terminalID:terminal.id, processID:pid, token:record.token };
      const reply = await new Promise((resolve,reject) => {
        const socket = net.createConnection(record.socketPath); let data='';
        socket.on('error',reject); socket.setTimeout(2500,()=>{socket.destroy();reject(new Error('IPC timeout'));});
        socket.on('connect',()=>socket.write(JSON.stringify(request)+'\n'));
        socket.on('data',chunk=>{data+=chunk;if(data.includes('\n')){socket.end();resolve(JSON.parse(data.split('\n')[0]));}});
      });
      assert.equal(reply.ok,true); assert.equal(vscode.window.activeTerminal.processId ? await vscode.window.activeTerminal.processId : 0,pid);
      assert.equal(vscode.window.state.focused,true);
    }
    if (process.env.DEV_ISLAND_LIVE_RESULT) fs.writeFileSync(process.env.DEV_ISLAND_LIVE_RESULT, JSON.stringify({passed:true,realVSCodeAPI:true,terminals:2,windowFocused:true,workspace:vscode.workspace.workspaceFolders?.[0]?.uri.fsPath}));
  } finally { first.dispose(); second.dispose(); await wait(50); }
};
