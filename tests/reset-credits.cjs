// Run with: node tests/reset-credits.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const qml = fs.readFileSync('contents/ui/main.qml', 'utf8');
function extract(name) {
    const start = qml.indexOf('    function ' + name + '(');
    assert.ok(start >= 0, name);
    let end = qml.indexOf('{', start) + 1;
    let depth = 1;
    while (depth) {
        if (qml[end] === '{') depth++;
        if (qml[end] === '}') depth--;
        end++;
    }
    return qml.slice(start, end);
}
const context = vm.createContext({
    codexResetCredits: { availableCount: 3 },
    codexResetCreditsAccount: 'account-A',
    entries: [],
    codexResetCreditsWatchdog: { stop() { this.stopped = true; }, restart() { this.restarted = true; } },
    codexResetCreditsExecutable: {
        connectedSources: ['pending'],
        connectSource(source) { this.connectedSources.push(source); }
    },
    codexResetCreditsCommandLine() { return 'codexbar oauth'; },
    activeProvider: '', activeSource: '',
    selectedProvider: 'detect', selectedSource: 'detect'
});
vm.runInContext(['withCodexResetCredits', 'applyCodexResetCredits',
    'stopCodexResetCredits', 'cancelCodexResetCredits', 'refreshCodexResetCredits',
    'candidateList'].map(extract).join('\n'), context);
const merge = context.withCodexResetCredits;
const a = merge({ provider: 'codex', account: 'account-A' });
assert.equal(a.codexResetCredits.availableCount, 3);
assert.equal(merge({ provider: 'codex', account: 'account-B' }).codexResetCredits, null);
assert.equal(merge({ provider: 'codex', account: '' }).codexResetCredits, null);
const native = { provider: 'codex', account: 'account-B', codexResetCredits: { availableCount: 1 } };
assert.equal(merge(native), native);
const other = { provider: 'claude' };
assert.equal(merge(other), other);
context.entries = [a, native, other];
context.stopCodexResetCredits();
assert.equal(context.codexResetCreditsExecutable.connectedSources.length, 0);
assert.equal(context.codexResetCredits.availableCount, 3);
assert.equal(context.entries[0].codexResetCredits.availableCount, 3);
context.refreshCodexResetCredits([{ provider: 'codex', account: 'account-A' }]);
assert.equal(context.codexResetCreditsExecutable.connectedSources[0], 'codexbar oauth');
assert.equal(context.codexResetCredits.availableCount, 3);
context.refreshCodexResetCredits([native, other]);
assert.equal(context.codexResetCredits, null);
assert.equal(context.entries[1], native);
context.codexResetCredits = { availableCount: 3 };
context.codexResetCreditsAccount = 'account-A';
context.codexResetCreditsExecutable.connectedSources = ['pending'];
context.codexResetCreditsWatchdog.stopped = false;
context.applyCodexResetCredits();
context.cancelCodexResetCredits();
assert.equal(context.codexResetCredits, null);
assert.equal(context.codexResetCreditsAccount, '');
assert.equal(context.codexResetCreditsWatchdog.stopped, true);
assert.equal(context.codexResetCreditsExecutable.connectedSources.length, 0);
assert.equal(context.entries[0].codexResetCredits, null);
assert.equal(context.entries[1], native);
assert.equal(context.entries[2], other);
assert.equal(context.candidateList()[0].provider, '');
context.selectedProvider = 'codex';
assert.equal(context.candidateList()[0].source, 'oauth');
console.log('Reset-credit account isolation, refresh retention, cancellation, and provider ordering passed.');
