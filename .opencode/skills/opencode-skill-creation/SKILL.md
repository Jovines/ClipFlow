---
name: opencode-skill-creation
description: Create reusable agent skills for OpenCode. Define custom SKILL.md files to teach agents specific workflows, patterns, or conventions for your project.
license: MIT
compatibility: opencode
metadata:
  audience: developers
  workflow: documentation
---

# OpenCode Skill Creation Guide

This skill teaches you how to create reusable OpenCode agent skills for your projects.

## What is an OpenCode Skill?

An OpenCode Skill is a markdown file that defines reusable instructions for agents. Skills help agents understand project-specific conventions, workflows, and patterns without repeated explanations.

## File Structure

Create a folder per skill with a `SKILL.md` file inside:

```
.opencode/
└── skills/
    └── my-skill-name/
        └── SKILL.md
```

Or globally:

```
~/.config/opencode/skills/my-skill-name/SKILL.md
```

Also supports Claude-compatible paths:

```
.claude/skills/my-skill-name/SKILL.md
```

## Required Frontmatter

Each `SKILL.md` must start with YAML frontmatter:

```yaml
---
name: skill-name-here
description: Brief description (1-1024 chars)
license: MIT
compatibility: opencode
metadata:
  key1: value1
  key2: value2
---
```

**Required fields:**
- `name` - lowercase, alphanumeric, hyphens only (1-64 chars)
- `description` - 1-1024 characters, be specific

**Optional fields:**
- `license` - e.g., MIT, Apache-2.0
- `compatibility` - e.g., opencode, claude
- `metadata` - string-to-string map for custom data

## Name Validation

The skill name must:
- Be 1-64 characters
- Be lowercase alphanumeric with single hyphens
- Not start or end with `-`
- Not contain consecutive `--`
- Match the directory name

Regex: `^[a-z0-9]+(-[a-z0-9]+)*$`

## Content Structure

After frontmatter, write clear sections:

```markdown
## Overview
Brief introduction of what this skill teaches.

## When to Use
When should an agent load this skill.

## How to Apply
Detailed instructions, code examples, or patterns.

## Examples
Concrete examples showing the skill in action.
```

## Complete Example

Create `.opencode/skills/git-release/SKILL.md`:

```yaml
---
name: git-release
description: Create consistent releases and changelogs
license: MIT
compatibility: opencode
metadata:
  audience: maintainers
  workflow: github
---

## What I do
- Draft release notes from merged PRs
- Propose a version bump
- Provide a copy-pasteable `gh release create` command

## When to Use
Use this when you are preparing a tagged release. Ask clarifying questions if the target versioning scheme is unclear.
```

## How Agents Use Skills

1. Agent sees available skills in the `skill` tool description
2. Agent calls `skill({ name: "skill-name" })` to load the skill
3. Agent applies the skill's instructions to the current task

## Permission Control

In `opencode.json`, control skill access:

```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "pr-review": "allow",
      "internal-*": "deny",
      "experimental-*": "ask"
    }
  }
}
```

| Permission | Behavior |
|------------|----------|
| `allow` | Loads immediately |
| `deny` | Hidden from agent |
| `ask` | User prompted first |

## Troubleshooting

If a skill doesn't appear:
1. Verify `SKILL.md` is spelled in all caps
2. Ensure frontmatter has `name` and `description`
3. Check skill name format is valid
4. Verify file is in correct location
5. Check permissions in `opencode.json`

## Official Documentation

For complete details, see:
https://opencode.ai/docs/skills

## Best Practices

1. **Keep descriptions specific** - Help agents choose the right skill
2. **Use consistent naming** - Follow the hyphenated-lowercase convention
3. **Include examples** - Show the skill in action
4. **Document when to use** - Clear triggers for skill usage
5. **Version your skills** - Update as project evolves
6. **Commit to git** - Share skills across your team

## Skill Ideas

Common skill topics:
- Code style and conventions
- Testing requirements
- Git workflow rules
- PR review criteria
- Deployment procedures
- Project-specific patterns
- Documentation standards
- Release procedures
