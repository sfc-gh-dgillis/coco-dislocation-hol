#!/bin/bash
set -e

# Optional: installs the local Coco companion skill "dislocation-lab"
# into your Coco skills directory, so you can invoke it in any Coco
# session to get guided help driving this lab.
#
# This is a LOCAL (client-side) Coco skill and is unrelated to the 5 Cortex
# Agent skills in skills/ that setup.sh uploads to the Snowflake stage.

SKILL_NAME="dislocation-lab"
SKILL_DIR="$HOME/.snowflake/cortex/skills/$SKILL_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/coco-skill/$SKILL_NAME/SKILL.md" "$SKILL_DIR/SKILL.md"

echo "Skill installed: invoke with 'dislocation lab' in any Coco session"
