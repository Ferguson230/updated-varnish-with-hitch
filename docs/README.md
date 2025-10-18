# Documentation

## Quick Links

- **[QUICK_REFERENCE.md](../QUICK_REFERENCE.md)** - 5-minute deployment guide (START HERE)
- **[../README.md](../README.md)** - Main project README with usage and troubleshooting

## Detailed Documentation

### For System Administrators

- **[CPANEL_PLUGIN_IMPLEMENTATION_REPORT.md](CPANEL_PLUGIN_IMPLEMENTATION_REPORT.md)** - Complete deployment guide with testing procedures
- **[CPANEL_PLUGIN_ARCHITECTURE.md](CPANEL_PLUGIN_ARCHITECTURE.md)** - Technical architecture details of the cPanel plugin refactoring

### For Developers

- **[CPANEL_PLUGIN_REFACTORING_SUMMARY.md](CPANEL_PLUGIN_REFACTORING_SUMMARY.md)** - Complete summary of all changes made
- **[REFACTORING_CHECKLIST.md](REFACTORING_CHECKLIST.md)** - Implementation verification checklist

## Documentation Overview

| Document | Purpose | Audience |
|----------|---------|----------|
| QUICK_REFERENCE.md | One-page deployment guide | Admins |
| CPANEL_PLUGIN_IMPLEMENTATION_REPORT.md | Full deployment guide with testing | Admins |
| CPANEL_PLUGIN_ARCHITECTURE.md | Architecture and migration details | Developers |
| CPANEL_PLUGIN_REFACTORING_SUMMARY.md | Summary of all changes | Developers |
| REFACTORING_CHECKLIST.md | Implementation verification | QA/Testing |

## Getting Started

1. **Clone the repo:**
   ```bash
   git clone https://github.com/Ferguson230/updated-varnish-with-hitch.git
   cd updated-varnish-with-hitch
   ```

2. **Read the quick start:**
   - Start with [QUICK_REFERENCE.md](../QUICK_REFERENCE.md)
   - Or the main [README.md](../README.md)

3. **Deploy:**
   ```bash
   sudo ./install.sh
   ```

4. **Troubleshooting:**
   - See [README.md troubleshooting section](../README.md#troubleshooting-cpanel-ui)
   - Or detailed guide in [CPANEL_PLUGIN_IMPLEMENTATION_REPORT.md](CPANEL_PLUGIN_IMPLEMENTATION_REPORT.md)

## Changes Summary

The cPanel plugin was refactored from a failing DynamicUI YAML approach to the proven native cPanel plugin registration pattern (install.json + .live.php). See [CPANEL_PLUGIN_ARCHITECTURE.md](CPANEL_PLUGIN_ARCHITECTURE.md) for details.
