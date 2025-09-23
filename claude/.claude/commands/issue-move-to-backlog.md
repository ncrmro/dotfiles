---
description: Move issue from daily journal to project backlog
argument-hint: "<issue_number> [project_tag]"
allowed-tools: mcp__github__get_issue, mcp__github__update_issue, mcp__github__search_pull_requests, mcp__github__get_pull_request
---

## Context

- Current directory: !pwd
- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md

## Your task

Move an issue from the daily journal to the project backlog by:

1. Determine repository and project context:
   - Use `!pwd` to get current working directory
   - Map directory to repository using /home/ncrmro/code/ncrmro/obsidian/projects/README.md mappings
   - Extract owner/repo from the project configuration
   - If project_tag provided, use it; otherwise derive from repository mapping

2. Fetch issue details:
   - Use `mcp__github__get_issue` to get issue details including:
     - Title and description
     - Current status and labels
     - Assignees and metadata
     - Creation and update dates

3. Find related pull requests:
   - Use `mcp__github__search_pull_requests` to find PRs that reference this issue
   - Search for PRs containing the issue number in title or description
   - For each related PR, use `mcp__github__get_pull_request` to get:
     - PR status (open/merged/closed)
     - Review status
     - CI/CD status
     - Author and reviewers

4. Update issue with backlog label:
   - Use `mcp__github__update_issue` to add "backlog" label if not already present
   - Consider adding appropriate priority labels (low, medium, high)

5. Find and update project backlog:
   - Determine project name from project tag or repository mapping
   - Read `/home/ncrmro/code/ncrmro/obsidian/projects/{PROJECT_NAME}/BACKLOG.md`
   - If BACKLOG.md doesn't exist, create it with proper structure
   - Add issue to backlog with format:
     ```markdown
     ## Backlog Items
     
     ### Issue #[number]: [title]
     - **Status**: [open/closed]
     - **Priority**: [high/medium/low]
     - **Labels**: [list of labels]
     - **Assignee**: [assignee if any]
     - **Created**: [creation date]
     - **Moved to backlog**: [current date]
     - **Repository**: [owner/repo]
     - **Link**: [GitHub issue URL]
     
     **Description**: [brief description or first paragraph]
     
     **Related Pull Requests**:
     [For each related PR:]
     - PR #[number]: [title] - [status] ([link])
       - Review status: [approved/changes requested/pending]
       - CI status: [passing/failing/pending]
     
     **Reason for backlog**: [why moved to backlog - e.g., "not immediate priority", "waiting for dependencies", etc.]
     
     ---
     ```

6. Remove from daily journal:
   - Read today's journal file
   - Find any references to this issue (by number, title, or in project sections)
   - Completely remove the issue entry from the journal (do not mark as completed)
   - If the issue was the only item in a project section, remove the entire section
   - Update journal file with the cleaned content

7. Present summary:
   - Confirm issue has been moved to backlog
   - Show backlog location
   - Display updated issue status
   - List any related PRs and their status
   - Provide link to both GitHub issue and backlog file

## Backlog file structure

If creating a new BACKLOG.md file, use this template:

```markdown
# [PROJECT_NAME] Backlog

This file contains issues that have been moved from active development to the backlog.

## Priority Classification

- **High**: Critical features or bugs that should be addressed soon
- **Medium**: Important improvements or features for future iterations
- **Low**: Nice-to-have features or minor improvements

## Backlog Items

[Issues will be added here in reverse chronological order - newest first]

## Completed Backlog Items

[Completed items will be moved here for reference]
```