#!/usr/bin/env bash
set -euo pipefail

SRC="$HOME/snap/brave/current/.config/BraveSoftware/Brave-Browser/Default/Bookmarks"
BACKUP_DIR="$HOME/Backups/BraveBookmarks"
KEEP=30

mkdir -p "$BACKUP_DIR"
cp -- "$SRC" "$BACKUP_DIR/Bookmarks-$(date '+%Y-%m-%d').json"

# Keep the most recent $KEEP backups, prune the rest.
shopt -s nullglob
backups=("$BACKUP_DIR"/Bookmarks-*.json)
if ((${#backups[@]} > KEEP)); then
  rm -- "${backups[@]:0:${#backups[@]}-KEEP}"
fi
shopt -u nullglob

echo "Backed up Brave bookmarks -> $BACKUP_DIR/Bookmarks-$(date '+%Y-%m-%d').json"
