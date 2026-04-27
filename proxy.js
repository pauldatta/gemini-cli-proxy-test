const http = require("http");
const net = require("net");

const port = 8080;

const server = http.createServer((req, res) => {
  console.log(`[HTTP] ${req.method} ${req.url}`);
  const url = new URL(req.url);
  const options = {
    hostname: url.hostname,
    port: url.port || 80,
    path: url.pathname + url.search,
    method: req.method,
    headers: req.headers,
  };

  const proxyReq = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });

  req.pipe(proxyReq);
  proxyReq.on("error", (err) => {
    console.error(`[ERROR] HTTP Proxy: ${err.message}`);
    res.statusCode = 502;
    res.end();
  });
});

// Handle HTTPS CONNECT tunneling
server.on("connect", (req, clientSocket, head) => {
  const [host, targetPort] = req.url.split(":");
  console.log(`[HTTPS/CONNECT] ${host}:${targetPort || 443}`);

  const serverSocket = net.connect(targetPort || 443, host, () => {
    clientSocket.write("HTTP/1.1 200 Connection Established\r\n\r\n");
    serverSocket.write(head);
    serverSocket.pipe(clientSocket);
    clientSocket.pipe(serverSocket);
  });

  serverSocket.on("error", (err) => {
    console.error(`[ERROR] HTTPS Tunnel: ${err.message}`);
    clientSocket.end();
  });

  clientSocket.on("error", () => serverSocket.end());
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Local proxy server running at http://127.0.0.1:${port}`);
  console.log("Press Ctrl+C to stop.");
});
