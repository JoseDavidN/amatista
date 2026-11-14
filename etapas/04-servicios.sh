#!/usr/bin/env bash
set -euo pipefail

sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now upower.service
