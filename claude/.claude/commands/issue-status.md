---
description: Get GitHub issue and pull request status for current directory's repository
argument-hint: "<issue_or_pr_number>"
allowed-tools: mcp__github__get_issue, mcp__github__get_issue_comments, mcp__github__get_pull_request, mcp__github__get_pull_request_status, mcp__github__list_pull_requests
---

## Context

- Current directory: !pwd
- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md

## Your task

Get the status and details of a GitHub issue or pull request in the current directory's repository by:

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

3. Check for associated pull requests:
   - Search for pull requests that reference this issue
   - For each related PR, fetch:
     - PR number, title, and status (open/merged/closed)
     - Review status (approved/changes requested/pending)
     - CI/CD check status (passing/failing)
     - Merge conflicts status
     - Author and reviewers

4. Present comprehensive information:
   - Show issue URL, number, title, and status
   - Display assignees and labels if any
   - Show creation and last update timestamps
   - Include direct link for easy access
   - If pull requests exist:
     - List each PR with its status
     - Show review approval status
     - Indicate CI/CD check results
     - Note any merge conflicts
     - Provide direct links to PRs

5. Summary:
   - Provide a brief summary of the overall status
   - Highlight any blockers (failing tests, requested changes, conflicts)
   - Indicate if the issue is ready to close or needs attention