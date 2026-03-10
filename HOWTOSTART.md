# OpenClaw Docker Quick Start

Simple commands to manage the OpenClaw gateway running in Docker.

## Quick Start

```bash
cd /home/admin/code/openclaw && docker compose up -d openclaw-gateway
```

## Shell Aliases (Recommended)

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# OpenClaw Docker aliases
alias openclaw-up='cd /home/admin/code/openclaw && docker compose up -d openclaw-gateway'
alias openclaw-down='cd /home/admin/code/openclaw && docker compose down'
alias openclaw-logs='cd /home/admin/code/openclaw && docker compose logs -f openclaw-gateway'
alias openclaw-status='docker compose -f /home/admin/code/openclaw/docker-compose.yml run --rm openclaw-cli channels status'
alias openclaw-cli='docker compose -f /home/admin/code/openclaw/docker-compose.yml run --rm openclaw-cli'
```

Then reload your shell (`source ~/.bashrc` or `source ~/.zshrc`) and use:

| Command | Description |
|---------|-------------|
| `openclaw-up` | Start the gateway |
| `openclaw-down` | Stop the gateway |
| `openclaw-logs` | Follow gateway logs |
| `openclaw-status` | Check gateway and channel status |
| `openclaw-cli <command>` | Run any OpenClaw CLI command |

## Example CLI Commands

```bash
# Check status
openclaw-cli channels status

# Add a channel (example: Discord)
openclaw-cli channels add --channel discord --token <your-bot-token>

# View config
openclaw-cli config get gateway.controlUi.allowedOrigins

# Send a message
openclaw-cli message send --channel telegram --to <chat-id> "Hello from OpenClaw"
```

## Device Pairing

When connecting a new device/browser to the Control UI, you need to approve it:

```bash
# List pending pairing requests
openclaw-cli devices list

# Approve a request by ID
openclaw-cli devices approve <requestId>
```

Example:
```bash
openclaw-cli devices approve 6749f38e-dc0c-406a-bd6e-387ab51e3175
```

Docs: https://docs.openclaw.ai/web/control-ui#device-pairing-first-connection

## Troubleshooting

If the gateway fails to start:

```bash
# Check logs
openclaw-logs

# Restart the gateway
openclaw-down && openclaw-up

# Verify configuration
docker compose -f /home/admin/code/openclaw/docker-compose.yml run --rm openclaw-cli config get gateway.controlUi.allowedOrigins
```

## Ports

- Gateway API: `18789`
- Bridge (if enabled): `18790`

## Data Locations

- Config: `~/.openclaw/`
- Workspace: `~/.openclaw/workspace/`
