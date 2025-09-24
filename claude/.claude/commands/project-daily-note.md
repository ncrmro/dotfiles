---
description: Add a project note to today's daily journal with context validation
argument-hint: "\"note content\""
allowed-tools: Edit, Read
---

## Context

- Current directory: !pwd
- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md

## Your task

Add a project-specific note to today's daily journal and ensure clarity by:

1. Determine project from current directory:
   - Use `!pwd` to get current working directory
   - Map directory to project using /home/ncrmro/code/ncrmro/obsidian/projects/README.md mappings
   - Extract project hashtag and repository information

2. Handle note content:
   - If note content is provided: Review the provided note content for clarity
   - If no note is provided: Infer a status update based on current context:
     * Check git status for modified/added/deleted files
     * Review recent commits (last 3-5 commits)
     * Examine file changes to understand what work has been done
     * Generate a concise status update summarizing recent activity
     * Format as: `- Status: [inferred activity summary]`

3. Analyze note content for clarity:
   - Assess if the "why" (purpose/motivation) is clear in the project context
   - Assess if the "so what" (impact/significance) is clear in the project context
   - Identify any missing context that would help future understanding

4. Add note to today's journal:
   - Open today's journal file
   - Find or create the appropriate project section under "Today"
   - Add the note under the correct project hashtag and repository
   - Format as: `- Note: [content]` or `- Status: [content]` for inferred updates

5. Validate clarity and prompt for clarification if needed:
   - If the "why" is unclear: Ask user to clarify the motivation or purpose behind this note
   - If the "so what" is unclear: Ask user to clarify the impact, outcome, or significance
   - If context is missing: Ask for additional background that would help future understanding
   - Suggest adding clarifying details to make the note more valuable for future reference

6. Update the journal entry with any clarifications:
   - Incorporate user's clarifications into the note
   - Ensure the final note is self-contained and understandable
   - Follow journal formatting conventions from CLAUDE.md

The goal is to ensure that when you read this note weeks or months later, you'll understand both why it was important and what it means for the project.