const path = require("node:path");

module.exports = {
  apps: [
    {
      name: "docia-api-monorepo",
      cwd: path.join(__dirname, "api"),
      script: path.join(__dirname, "api/dist/main.js"),
      interpreter: process.execPath,
      instances: 1,
      exec_mode: "fork",
      autorestart: true,
      max_restarts: 10,
      min_uptime: "10s",
      time: true,
      env: {
        NODE_ENV: "production",
        HOST: "127.0.0.1",
        PORT: "3100",
        // Optional common public config; credentials remain exclusively in api/.env.
        DOCIA_SITES_FILE: path.join(__dirname, "PUBLIC_CONFIG.env"),
        DOCIA_RELEASE: path.basename(__dirname),
        STORAGE_ROOT: "/var/www/docia/monorepo/deploy/shared/storage",
      },
    },
  ],
};
