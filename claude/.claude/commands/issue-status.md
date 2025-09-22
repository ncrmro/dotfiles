---
description: Get GitHub issue status for current directory's repository
argument-hint: "<issue_number>"
allowed-tools: mcp__github__get_issue, mcp__github__get_issue_comments
---

## Context

- Current directory: !pwd
- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md

## Your task

Get the status and details of a GitHub issue in the current directory's repository by:

1. Determine repository from current directory:
   - Use `!pwd` to get current working directory
   - Map directory to repository using /home/ncrmro/code/ncrmro/obsidian/projects/README.md mappings
   - Extract owner/repo from the project configuration

2. Fetch issue details:
   - Use the GitHub MCP tool to retrieve issue details including:
     - Title and description
     - Status (open/closed)
     - Assignees
     - Labels
     - Comments count
     - Creation and last update dates

3. Present comprehensive issue information:
   - Show issue URL, number, title, and status
   - Display assignees and labels if any
   - Show creation and last update timestamps
   - Include direct link for easy access

4. Optional: Show recent comments if requested or if there are important updates