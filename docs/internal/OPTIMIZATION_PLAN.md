# Raybridge Optimization & Doppler Integration Plan

## 🎯 Immediate Actions

### 1. Remove Unnecessary Dependencies

Create a minimal profile by editing `package.json`:

```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.29.0",
    "@raycast/api": "^1.104.13"
  },
  "devDependencies": {
    "@types/bun": "^1.3.13",
    "typescript": "^6.0.3"
  }
}
```

**Benefits:**
- Reduces bundle size by ~80%
- Faster startup time
- Fewer security vulnerabilities

### 2. Optimize Configuration

Your current config is already well-optimized. Just add performance settings:

```json
{
  "performance": {
    "workerPoolSize": 2,
    "toolTimeout": 30000,
    "extensionCacheTTL": 300000,
    "enableMetrics": false
  }
}
```

### 3. Doppler Integration

#### Option A: Full Doppler Wrap (Recommended)

Update your Claude Desktop config:

```json
{
  "raybridge": {
    "command": "doppler",
    "args": [
      "run",
      "--project", "raybridge",
      "--config", "prod",
      "--",
      "bun", "run", "/Users/davidortiz/Git-Projects/raybridge/src/index.ts"
    ],
    "env": {
      "RAYBRIDGE_LOG_LEVEL": "info"
    }
  }
}
```

#### Doppler Project Setup

```bash
# Create Doppler project
doppler projects create raybridge

# Create config
doppler configs create raybridge prod

# Add secrets
doppler secrets set SHODAN_API_KEY your_shodan_key
doppler secrets set GITHUB_TOKEN your_github_token
doppler secrets set SLACK_TOKEN your_slack_token

# Test locally
doppler run --config prod -- bun run src/index.ts
```

## 📋 Extension Optimization

### Keep These (High Value)
- ✅ **github** - Essential for development
- ✅ **obsidian** - Knowledge management
- ✅ **slack** - Team communication
- ✅ **google-calendar** - Meeting management
- ✅ **apple-notes** - Quick notes
- ✅ **apple-reminders** - Task management

### Consider Adding
- 🤔 **music** - If you want AI to control Apple Music
- 🤔 **timers** - For time tracking

### Keep Disabled
- ❌ **ccusage** - Usage stats (not needed)
- ❌ **pomodoro** - Productivity (optional)
- ❌ **mcp** - Meta tool (rarely needed)

## 🔧 Performance Tweaks

### 1. Worker Pool Optimization
```typescript
// In src/worker-executor.ts
const WORKER_CONFIG = {
  maxWorkers: 2,  // Limit concurrent workers
  idleTimeout: 60000,  // Kill idle workers after 1min
  maxMemory: 512 * 1024 * 1024,  // 512MB per worker
};
```

### 2. Caching Layer
```typescript
// Add to src/config.ts
interface CacheConfig {
  enableToolCache: boolean;
  cacheTTL: number;
  maxCacheSize: number;
}

const CACHE_CONFIG: CacheConfig = {
  enableToolCache: true,
  cacheTTL: 300000,  // 5 minutes
  maxCacheSize: 100,  // Max 100 cached results
};
```

### 3. Rate Limiting
```typescript
// Add to src/rate-limiter.ts
class RateLimiter {
  private limits = new Map<string, { count: number; resetTime: number }>();
  
  checkLimit(extension: string, tool: string): boolean {
    const key = `${extension}:${tool}`;
    const limit = this.getLimit(extension, tool);
    // Implementation...
  }
}
```

## 🛡️ Security Hardening

### Current Security Score: 8/10

#### Already Implemented:
- ✅ Allowlist mode
- ✅ No destructive system actions
- ✅ No AppleScript
- ✅ No command launch

#### Additional Recommendations:
```json
{
  "security": {
    "auditLog": true,
    "sanitizeInputs": true,
    "validateOutputs": true,
    "maxRequestSize": "10MB"
  }
}
```

## 📊 Monitoring Setup

### 1. Health Check Endpoint
```typescript
// Add to src/http-server.ts
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    extensions: activeExtensions.length,
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});
```

### 2. Metrics Collection
```typescript
// Add to src/metrics.ts
export class Metrics {
  static toolCalls = new Counter('tool_calls_total', ['extension', 'tool']);
  static errors = new Counter('errors_total', ['type']);
  static duration = new Histogram('tool_duration_seconds');
}
```

## 🚀 Deployment Strategy

### Development
```bash
# Start with Doppler
doppler run --config dev -- bun run dev

# Test specific extension
doppler run --config dev -- bun run test:extension github
```

### Production
```bash
# Build optimized version
bun run build

# Start with Doppler
doppler run --config prod -- nohup bun run dist/index.js > raybridge.log 2>&1 &
```

## 📈 Success Metrics

### Performance Targets
- Startup time: < 2 seconds
- Tool execution: < 5 seconds (average)
- Memory usage: < 256MB
- CPU usage: < 10% (idle)

### Reliability Targets
- Uptime: 99.9%
- Error rate: < 1%
- Response time: < 1 second (95th percentile)

## 🔄 Maintenance Automation

### Daily Health Check
```bash
#!/bin/bash
# health-check.sh
doppler run --config prod -- bun run raybridge doctor
if [ $? -ne 0 ]; then
  echo "Raybridge health check failed" | mail -s "Raybridge Alert" admin@example.com
fi
```

### Weekly Update Script
```bash
#!/bin/bash
# update-raybridge.sh
cd /Users/davidortiz/Git-Projects/raybridge
git pull
bun install
bun run build
systemctl restart raybridge
```

## 🎯 Quick Win Checklist

- [ ] Remove UI dependencies from package.json
- [ ] Add Doppler configuration
- [ ] Set up Doppler project with secrets
- [ ] Update Claude Desktop config with Doppler wrap
- [ ] Add performance settings to tools.json
- [ ] Enable health check endpoint
- [ ] Set up basic monitoring
- [ ] Test all enabled extensions
- [ ] Document API key requirements

## 📝 Implementation Order

1. **Day 1**: Doppler setup and basic optimization
2. **Day 2**: Dependency cleanup and performance tweaks
3. **Day 3**: Monitoring and health checks
4. **Day 4**: Security hardening
5. **Day 5**: Documentation and maintenance scripts

This plan will give you a lean, secure, and highly performant Raybridge setup that integrates seamlessly with Doppler for secret management.
