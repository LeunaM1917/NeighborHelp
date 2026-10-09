import { readFile, writeFile, mkdtemp } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';

// Credentials are read only from the ignored local configuration, never printed.
const directory = fileURLToPath(new URL('.', import.meta.url));
const repository = resolve(directory, '..', '..');
const config = JSON.parse(await readFile(join(repository, '.cursor', 'mcp.json'), 'utf8'));
const server = config.servers?.stitch ?? config.mcpServers?.stitch;
if (server?.url !== 'https://stitch.googleapis.com/mcp') {
  throw new Error('Expected the configured Google Stitch MCP endpoint.');
}
const secrets = Object.values(server.headers ?? {}).filter(value => typeof value === 'string');
const sanitize = value => secrets.reduce((text, secret) => secret ? text.split(secret).join('[REDACTED]') : text, String(value))
  .replace(/(?:AIza|AQ\.)[A-Za-z0-9_.-]+/g, '[REDACTED]');
let nextId = 1;
let session;
const headers = { ...server.headers, Accept: 'application/json, text/event-stream', 'Content-Type': 'application/json' };

async function rpc(method, params, notification = false) {
  const body = { jsonrpc: '2.0', method, params };
  if (!notification) body.id = nextId++;
  let response;
  try {
    response = await fetch(server.url, {
      method: 'POST', headers: { ...headers, ...(session ? { 'Mcp-Session-Id': session } : {}) },
      body: JSON.stringify(body), signal: AbortSignal.timeout(method === 'tools/call' ? 600000 : 30000),
    });
  } catch {
    throw new Error('Stitch network request failed or timed out. Do not replay a generation request; inspect project screens.');
  }
  if (!response.ok) throw new Error(`Stitch HTTP ${response.status} for ${method}.`);
  session = response.headers.get('mcp-session-id') ?? session;
  const raw = await response.text();
  if (notification || !raw.trim()) return;
  let parsed;
  try {
    if (raw.trim().startsWith('{')) parsed = JSON.parse(raw);
    else {
      const events = raw.split(/\r?\n/).filter(line => line.startsWith('data:'))
        .map(line => { try { return JSON.parse(line.slice(5).trim()); } catch { return null; } });
      parsed = events.findLast(event => event?.id === body.id);
    }
  } catch { throw new Error('Stitch returned an unreadable MCP response.'); }
  if (!parsed) throw new Error('Stitch returned no matching MCP response.');
  if (parsed.error) throw new Error(`Stitch RPC error ${parsed.error.code}: ${sanitize(parsed.error.message)}`);
  if (parsed.result?.isError) throw new Error('Stitch reported a tool error. No success has been recorded.');
  return parsed.result;
}

function decode(result) {
  if (result?.structuredContent) return result.structuredContent;
  for (const block of result?.content ?? []) {
    if (block.type === 'text') { try { return JSON.parse(block.text); } catch { /* Other blocks may contain structured JSON. */ } }
  }
  return result;
}

function screensIn(value) {
  const screens = new Map();
  function visit(node) {
    if (!node || typeof node !== 'object') return;
    if (typeof node.name === 'string' && /^projects\/[^/]+\/screens\/[^/]+$/.test(node.name)) {
      screens.set(node.name, { name: node.name, title: node.title, width: node.width, height: node.height,
        status: node.screenMetadata?.status, hasHtml: Boolean(node.htmlCode), hasFigmaExport: Boolean(node.figmaExport) });
    }
    for (const child of Object.values(node)) {
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === 'object') visit(child);
    }
  }
  visit(value);
  return [...screens.values()];
}

async function main() {
  await rpc('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'neighborhelp-hci-handoff', version: '1.0.0' } });
  await rpc('notifications/initialized', {}, true);
  const flags = process.argv.slice(2);
  const projectFlag = flags.indexOf('--project');
  const projectId = projectFlag >= 0 ? flags[projectFlag + 1] : undefined;
  if (!flags.includes('--sync')) {
    const value = decode(await rpc('tools/call', { name: 'list_projects', arguments: {} }));
    console.log(JSON.stringify({ projects: (value.projects ?? []).map(project => ({ name: project.name, title: project.title })) }, null, 2));
    return;
  }
  if (!projectId || !/^\d+$/.test(projectId)) throw new Error('Pass --project with the verified Stitch project ID.');
  await rpc('tools/call', { name: 'get_project', arguments: { name: `projects/${projectId}` } });
  const payload = JSON.parse(await readFile(join(directory, 'stitch-requests.json'), 'utf8'));
  const outputDirectory = await mkdtemp(join(tmpdir(), 'neighborhelp-stitch-'));
  const manifest = { status: 'submitted-not-verified', projectId, screens: [], requestCount: payload.requests.length };
  for (let index = 0; index < payload.requests.length; index++) {
    const request = payload.requests[index];
    console.log(`Generating ${index + 1}/${payload.requests.length}: ${request.frameName}`);
    const result = await rpc('tools/call', { name: request.tool, arguments: { ...request.arguments, projectId } });
    await writeFile(join(outputDirectory, `response-${index + 1}.json`), sanitize(JSON.stringify(result, null, 2)));
    const generated = screensIn(decode(result));
    manifest.screens.push(...generated.map(screen => ({ ...screen, requestedFrameName: request.frameName })));
    await writeFile(join(directory, 'stitch-sync-result.json'), JSON.stringify(manifest, null, 2) + '\n');
    // Surface generation text/suggestions as required by the MCP tool instructions.
    for (const component of decode(result)?.outputComponents ?? []) {
      if (component.text) console.log(sanitize(component.text));
      if (component.suggestion) console.log(`Stitch suggestion: ${sanitize(component.suggestion)}`);
    }
    if (!generated.length) throw new Error('No screen IDs returned; inspect the saved response and list_screens before proceeding.');
  }
  const saved = screensIn(decode(await rpc('tools/call', { name: 'list_screens', arguments: { projectId } })));
  const verified = manifest.screens.every(screen => saved.some(candidate => candidate.name === screen.name && candidate.status === 'COMPLETE'));
  manifest.status = verified ? 'screens-saved-export-validation-pending' : 'screen-completion-verification-pending';
  manifest.responseDirectory = outputDirectory;
  await writeFile(join(directory, 'stitch-sync-result.json'), JSON.stringify(manifest, null, 2) + '\n');
  console.log(JSON.stringify(manifest, null, 2));
}

main().catch(error => { console.error(sanitize(error.message)); process.exitCode = 1; });
