# TO-DOS

## Configure Backups - 2026-01-04 00:46

- **Set up backup system for NixOS** - Configure automated backups for the system. **Problem:** No backup strategy currently in place for user data, configs, or system state. **Files:** `hosts/common/configuration.nix`, `hosts/common/home.nix`. **Solution:** Consider restic, borgbackup, or Syncthing for different backup needs (local snapshots vs offsite). May need to configure backup destinations and schedules per-host.

## Configure Brave Sync - 2026-01-04 00:46

- **Set up Brave browser sync** - Enable Brave sync across all hosts for bookmarks, settings, etc. **Problem:** Brave browser installed but sync not configured, so bookmarks/settings won't persist across mischief, intrepid, and vigilant. **Files:** N/A (browser UI configuration). **Solution:** Use Brave's built-in sync chain feature - create chain on one device, join from others using sync code.
