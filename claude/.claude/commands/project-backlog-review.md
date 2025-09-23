---
description: Review and analyze project backlog items with current status
argument-hint: "[project_tag]"
allowed-tools: mcp__github__get_issue, mcp__github__search_pull_requests, mcp__github__get_pull_request, mcp__github__list_issues
---

## Context

- Current directory: !pwd
- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md

## Your task

Review and analyze the project backlog with updated status information by:

1. Determine target project:
   - If project_tag provided: Use the specified project
   - If no parameter: Use `!pwd` to get current directory and map to project using /home/ncrmro/code/ncrmro/obsidian/projects/README.md
   - Extract project name and associated repositories

2. Read project backlog:
   - Read `/home/ncrmro/code/ncrmro/obsidian/projects/{PROJECT_NAME}/BACKLOG.md`
   - Parse all backlog items and extract issue numbers
   - If backlog doesn't exist, inform user and suggest creating it

3. Update status for each backlog item:
   - For each issue number found in backlog:
     - Use `mcp__github__get_issue` to get current status
     - Use `mcp__github__search_pull_requests` to find related PRs
     - For each related PR, use `mcp__github__get_pull_request` to get current status
   - Check for any status changes since last backlog update

4. Analyze backlog health:
   - Categorize items by:
     - Recently active (has recent comments or PR activity)
     - Stale (no activity for 30+ days)
     - Blocked (waiting on dependencies)
     - Ready to promote (could be moved back to active development)
   - Identify items that may have been completed but not removed from backlog

5. Generate comprehensive backlog review:
   - **Summary Statistics**:
     - Total backlog items
     - Items by priority (high/medium/low)
     - Items by status (open/closed)
     - Average age of backlog items
   
   - **Status Updates**:
     - Items with recent activity
     - Items that have been closed since last review
     - New PRs or progress on existing items
   
   - **Health Analysis**:
     - Stale items needing attention or closure
     - Items ready for promotion to active development
     - Blocked items and their dependencies
   
   - **Recommendations**:
     - Items to close or archive
     - Items to promote back to active development
     - Items needing updated priority or labels
     - Suggested cleanup actions

6. Update daily journal with review summary:
   - Add a section to today's journal with backlog review summary
   - Include key metrics and actionable items
   - Reference the full backlog file for details

7. Present actionable summary:
   - Show key metrics and health indicators
   - Highlight items needing immediate attention
   - Suggest specific next steps for backlog maintenance
   - Provide links to updated backlog and relevant issues/PRs

## Example review output format

```markdown
# Backlog Review: [PROJECT_NAME] - [date]

## Summary Statistics
- Total items: 15
- Open: 12, Closed: 3
- Priority: High (2), Medium (8), Low (5)
- Average age: 45 days

## Recent Activity
- Issue #123: New PR opened (ready for review)
- Issue #456: Closed as completed
- Issue #789: Updated with new requirements

## Health Analysis
### Ready to Promote (2 items)
- Issue #123: PR is approved and ready to merge
- Issue #456: Simple fix, could be quick win

### Stale Items (3 items)
- Issue #321: No activity for 60 days, consider closing
- Issue #654: Blocked on external dependency

### Recommendations
1. Promote issues #123, #456 back to active development
2. Close or archive issue #321 (outdated)
3. Follow up on blocked dependencies for issue #654
```