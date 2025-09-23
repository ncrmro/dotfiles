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
   - Use `mcp__github__list_issues` to get issues where you are:
     - The creator (author)
     - Currently assigned
     - Filter to open issues only
   - Use `mcp__github__list_pull_requests` to get PRs where you are:
     - The creator (author)
     - Currently assigned as reviewer
     - Filter to open PRs only
   - Use `mcp__github__list_commits` to get recent activity (last 7 days) by you

3. Present organized status overview:
   - Repository name and description
   - Your open issues count with highlights of critical/recent issues
   - Your open PRs count with status (ready for review, draft, etc.)
   - PRs awaiting your review
   - Your recent commit activity
   - Personal workload and priorities

4. For multi-repository projects:
   - Aggregate your personal status across all repositories
   - Show cross-repository dependencies affecting your work
   - Highlight repositories where your attention is needed

5. Suggest actionable next steps based on your personal status:
   - Issues you should prioritize
   - PRs ready for your review
   - Your PRs needing attention
   - Upcoming deadlines or blockers