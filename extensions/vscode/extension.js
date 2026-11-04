'use strict';
const vscode = require('vscode');
const { createRouter } = require('./router');
let router;
async function activate(context) {
  if (process.platform !== 'darwin' || vscode.env.remoteName || vscode.env.uriScheme !== 'vscode') return;
  const output = vscode.window.createOutputChannel('Dev Island');
  context.subscriptions.push(output);
  try {
    router = await createRouter(vscode);
    context.subscriptions.push(router);
    context.subscriptions.push(vscode.commands.registerCommand('devIsland.connectionStatus', () => {
      vscode.window.showInformationMessage(`Dev Island: this window is connected (${vscode.window.terminals.length} terminals).`);
    }));
    return { windowID: router.windowID, registryPath: router.registryPath, refresh: router.refresh, registerExternalTerminal: router.registerExternalTerminal };
  } catch (error) { output.appendLine(`Local routing unavailable: ${error.message}`); }
}
function deactivate() { router?.dispose(); router = undefined; }
module.exports = { activate, deactivate };
