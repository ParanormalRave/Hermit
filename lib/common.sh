#!/usr/bin/env bash
# lib/common.sh — logging helpers shared by every hermit command.
# shellcheck shell=bash

info()  { printf '[hermit] %s\n' "$*" >&2; }
warn()  { printf '[hermit] WARN: %s\n' "$*" >&2; }
error() { printf '[hermit] ERROR: %s\n' "$*" >&2; exit 1; }
