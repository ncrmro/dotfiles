---
description: Create a GitHub issue in current directory's repository and track in daily journal
argument-hint: "\"issue description\" [\"detailed body\"]"
allowed-tools: mcp__github__create_issue, mcp__github__assign_copilot_to_issue, Edit
---

## Context

- Current directory: !pwd
- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md

## Your task

Create a GitHub issue for the current directory's repository and track progress in daily journal by:

1. Determine repository from current directory:
   - Use `!pwd` to get current working directory
   - Map directory to repository using /home/ncrmro/code/ncrmro/obsidian/projects/README.md mappings
   - Extract owner/repo from the project configuration

2. Create the issue:
   - Use the GitHub MCP tool to create an issue with the provided description
   - Set the title as a brief summary of the description (first sentence or first 50 characters)
   - Use the full description as the issue body

3. Present the created issue to the user:
   - Show the issue URL, number, title, and description
   - Ask if the user would like to assign GitHub Copilot to this issue
   - Explain what Copilot assignment will do (analyze requirements, generate implementation, create PR)

4. If user wants Copilot assignment:
   - Use the GitHub MCP tool to assign Copilot to the issue
   - Confirm the assignment was successful

5. Update today's journal:
   - Add the issue to today's "Today" section under the appropriate project and repository
   - Format as: `- [ ] [Issue #123](https://github.com/owner/repo/issues/123): Title`
   - Follow the journal structure with project headers and repo bullets

6. Provide final status:
   - Show the complete issue details with assignment status (Copilot or unassigned)
   - Include journal update confirmation
   - Provide direct links for easy access