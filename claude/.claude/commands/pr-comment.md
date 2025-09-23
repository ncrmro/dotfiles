---
description: Add comment to PR and update daily journal with project status
argument-hint: "<pr_number> <comment>"
allowed-tools: mcp__github__get_pull_request, mcp__github__add_issue_comment, mcp__github__get_pull_request_status, mcp__github__get_pull_request_files, mcp__github__list_issues
---

## Context

- Current directory: !pwd
- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md

## Your task

Add a comment to a pull request and update the daily journal with the current project status by:

1. Determine repository from current directory:
   - Use `!pwd` to get current working directory
   - Map directory to repository using /home/ncrmro/code/ncrmro/obsidian/projects/README.md mappings
   - Extract owner/repo from the project configuration

2. Add comment to the pull request:
   - Use `mcp__github__add_issue_comment` to add the specified comment to the PR
   - Confirm the comment was successfully added

3. Fetch comprehensive PR status:
   - Use `mcp__github__get_pull_request` to get PR details
   - Use `mcp__github__get_pull_request_status` to get review and CI/CD status
   - Use `mcp__github__get_pull_request_files` to understand scope of changes
   - Check for any related issues

4. Determine project context:
   - Identify which project this repository belongs to from /home/ncrmro/code/ncrmro/obsidian/projects/README.md
   - Get project tag (e.g., #project-name)

5. Update daily journal with project status:
   - Read today's journal file
   - Find or create a section for the project (using the project tag)
   - Update with current PR status including:
     - PR number and title
     - Review status (approved/changes requested/pending)
     - CI/CD checks status (passing/failing)
     - Comment just added
     - Any blockers or next steps
     - Timestamp of update
   - Write the updated journal back

6. Present summary:
   - Confirm comment was added to PR
   - Show updated project status in journal
   - Highlight any issues requiring attention
   - Suggest next steps if applicable

## Example journal update format

```markdown
## #project-name

### PR Status Update - [timestamp]

**PR #123: Feature implementation**
- Status: Open, Ready for review
- Reviews: 1 approved, 1 pending
- CI/CD: All checks passing
- Latest comment: "[your comment here]"
- Next steps: Awaiting final review from @reviewer

Related issues:
- #456: Original feature request (linked)
```