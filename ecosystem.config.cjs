// ANEXOMAIL — PM2 ecosystem (frontend SSR on BUN runtime)
//
// TECHNOLOGY LOCK: Rust (:3200 + WT/QUIC udp 3443) PRIMARY engine.
// Frontend SSR ab Bun runtime par chalta hai (Nitro `bun` preset) — Node nahi.
//
// HETZNER COMMANDS:
//   cd /opt/anexomail-web
//   git pull
//   bun install
//   bun run build:bun
//   pm2 delete anexomail-web || true
//   pm2 start ecosystem.config.cjs
//   pm2 save
//
// Bun path check: `which bun` (aksar /root/.bun/bin/bun ya /usr/local/bin/bun).
// Agar path alag ho to neeche interpreter line update karo.

const BUN = process.env.BUN_PATH || "/root/.bun/bin/bun";

module.exports = {
  apps: [
    {
      name: "anexomail-web",
      script: "./.output/server/index.mjs",
      interpreter: BUN,
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
