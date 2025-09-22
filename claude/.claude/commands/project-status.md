---
description: Get project status overview for current directory or specified project
argument-hint: "[#project_tag]"
allowed-tools: mcp__github__list_issues, mcp__github__list_pull_requests, mcp__github__list_commits
---

## Context

- Current directory: !pwd
- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md

## Your task

Get an overview of project status including issues, pull requests, and recent activity by:

1. Determine target repository/repositories:
   - If no parameter provided: Use `!pwd` to get current working directory and map to repository using /home/ncrmro/code/ncrmro/obsidian/projects/README.md
   - If project tag provided: Read /home/ncrmro/code/ncrmro/obsidian/projects/README.md to find all associated repositories for that project

2. Fetch comprehensive status for each repository:
   - Use `mcp__github__list_issues` to get open issues (limit to recent/important ones)
   - Use `mcp__github__list_pull_requests` to get open PRs
   - Use `mcp__github__list_commits` to get recent activity (last 7 days)

3. Present organized status overview:
   - Repository name and description
   - Open issues count with highlights of critical/recent issues
   - Open PRs count with status (ready for review, draft, etc.)
   - Recent commit activity and contributors
   - Overall project health indicators

4. For multi-repository projects:
   - Aggregate status across all repositories
   - Show cross-repository dependencies if any
   - Highlight repositories needing attention

5. Optional: Suggest actionable next steps based on status