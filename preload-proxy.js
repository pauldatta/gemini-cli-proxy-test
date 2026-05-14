// Bootstraps global-agent to patch Node's http.globalAgent.
// This makes ALL HTTP/HTTPS requests use the proxy defined in
// GLOBAL_AGENT_HTTP_PROXY / GLOBAL_AGENT_HTTPS_PROXY env vars,
// without relying on HTTPS_PROXY (which triggers the broken
// gaxios dynamic import of https-proxy-agent in Gemini CLI).
const { bootstrap } = require('global-agent');
bootstrap();
