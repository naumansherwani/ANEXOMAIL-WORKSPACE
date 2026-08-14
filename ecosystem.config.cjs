// ANEXOMAIL — PM2 ecosystem (frontend SSR on Node 22, Bun sirf build ke liye)
//
// HETZNER COMMANDS:
//   cd /opt/anexomail-web
//   git pull
//   bun install
//   bun run build:node
//   pm2 start ecosystem.config.cjs        # pehli baar
//   pm2 reload ecosystem.config.cjs       # agar already running ho
//   pm2 save
//
// Note: Agar Node 22 ka path /usr/bin/node se alag ho toh interpreter line update karo.
module.exports = {
  apps: [
    {
      name: "anexomail-web",
      script: "./.output/server/index.mjs",
      interpreter: "/usr/bin/node",
      instances: 1,
      exec_mode: "fork",
      max_memory_restart: "512M",
      env: {
        NODE_ENV: "production",
        PORT: 3000,
      },
      env_production: {
        NODE_ENV: "production",
      },
      log_file: "/var/log/pm2/anexomail-web.log",
      out_file: "/var/log/pm2/anexomail-web-out.log",
      error_file: "/var/log/pm2/anexomail-web-error.log",
      merge_logs: true,
      time: true,
      restart_delay: 3000,
      max_restarts: 5,
      min_uptime: "10s",
      watch: false,
    },
  ],
};
