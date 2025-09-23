---
description: Update today's journal entry based on yesterday's tasks and provide daily overview
argument-hint: "[optional time block duration in hours, default: 8]"
allowed-tools: Read, Write, Edit
---

## Context

- Projects: @/home/ncrmro/code/ncrmro/obsidian/projects/README.md
- Yesterday's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date -d yesterday +%Y-%m-%d`.md
- Today's journal: @/home/ncrmro/code/ncrmro/obsidian/Journal/!`date +%Y-%m-%d`.md
- Journal template: @/home/ncrmro/code/ncrmro/obsidian/Journal/Template.md

## Your task

Update today's journal entry based on yesterday's tasks and provide a timeboxed daily overview by:

1. Read yesterday's journal entry:
   - Extract all tasks from yesterday's "Today" section
   - Identify completed tasks marked with [x]
   - Identify uncompleted tasks marked with [ ]
   - Note project and repository tags (lines starting with #)

2. Create or update today's journal:
   - Move ONLY completed tasks ([x]) from yesterday's "Today" section to today's "Yesterday" section
     * DO NOT copy yesterday's "Yesterday" section
     * Extract only [x] marked tasks from yesterday's "Today" section
     * Simplify by removing strikethrough and excessive nesting
   - Carry forward uncompleted tasks ([ ]) from yesterday's "Today" to today's "Today" section
   - Preserve the project/repository hierarchy structure (#ProjectTag -> #owner/repo -> tasks)
   - Keep any blockers that are still relevant

3. Journal structure format:
   - Projects as markdown headers (e.g., `#### #Catalyst`) with blank line after
   - Repository tags as bullet points under project headers (e.g., `- #owner/repo`)
   - Tasks as checkboxes under repositories (e.g., `- [ ] task description`)
   - Preserve any existing content in today's journal that was manually added

4. Generate timeboxed daily overview:
   - Calculate available hours (default: 8 hours if not specified)
   - Analyze today's tasks and estimate time for each
   - Create a prioritized schedule with time blocks
   - Include buffer time for context switching
   - Highlight critical path items and dependencies
   - Note any potential blockers or risks

5. Present comprehensive summary:
   - Show journal update confirmation
   - Display timeboxed schedule for the day
   - List top 3 priorities
   - Identify any carried-over blockers
   - Suggest focus areas based on task urgency

## Example timeboxed overview format

```markdown
## Daily Timeboxed Overview - [date]

**Available Time:** 8 hours
**Task Count:** 12 tasks across 3 projects

### Schedule
- **9:00-10:30** (1.5h): #project-a - Complete PR review and merge
- **10:30-12:00** (1.5h): #project-b - Debug authentication issue
- **12:00-13:00**: Lunch break
- **13:00-15:00** (2h): #project-a - Implement new feature
- **15:00-15:30** (0.5h): Buffer/Context switching
- **15:30-17:00** (1.5h): #project-c - Write tests and documentation

### Top Priorities
1. Unblock team by merging PR #123
2. Fix critical authentication bug
3. Complete feature for tomorrow's demo

### Carried Over
- 3 tasks from yesterday (2 in progress, 1 blocked)
- Blocker: Waiting for API credentials from DevOps

### Focus Recommendation
Morning focus on unblocking tasks, afternoon on deep work features.
```
