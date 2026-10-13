# Getting started with agentic coding

Agentic coding works best as a conversation with a capable teammate. Open a
terminal in the project you want to change and run `codex`. Start with a
concrete goal:

> Add a search box to the customer list. Match the existing style, test it,
> and explain what changed.

You do not need to describe every implementation step. Give the agent the
outcome you want, point out constraints that matter, and let it inspect the
project. Ask it to show evidence—tests, screenshots, or command output—before
you accept the result.

## A productive first session

1. Begin in the repository so the agent can see its files and instructions.
2. Ask for one well-defined outcome rather than a broad rewrite.
3. Mention anything that must not change, such as an API or visual style.
4. Let the agent make and check the change.
5. Review the summary and diff, then ask follow-up questions in plain English.
6. Commit only after you understand and are happy with the result.

Useful follow-ups include “explain this as if I am new to the project,” “check
for edge cases,” “run the relevant tests,” and “make this simpler.” If a task is
large, ask the agent to split it into small, reviewable stages.

## What is available

- **Codex** is the main coding agent. It can inspect a repository, edit files,
  run checks, and explain its work.
- **Semantic project search** helps the agent understand relationships across
  a large codebase. Run `codex-semantic` if you want to explore it yourself.
- **Context audit** creates a compact overview of a repository for an AI. Run
  `codex-context-audit .` when a large project is difficult to fit into one
  conversation.
- **Codex harness** can queue longer jobs in the background. For example,
  `codex-harness enqueue --repo "$PWD" --prompt "review the project and suggest three small reliability improvements"`.
  Use `codex-harness status` to see queued and completed work.
- **Antigravity** is an alternative coding-agent command, available as `agy`.
  It is useful when you want a second opinion or a separate conversation.
- Git, language-aware navigation, Nix assistance, and common data tools are
  already available to the agents. Usually you can simply ask for the outcome
  instead of invoking these helpers yourself.

## Get better results

Share the reason behind a change, not just the requested edit. A sentence such
as “this runs on every keystroke, so responsiveness matters” helps the agent
make better tradeoffs. Provide examples of desired behavior and name a nearby
file or screen when you know one.

Keep approval prompts meaningful. Read commands before approving them, be
especially careful with deletion or deployment, and never paste secrets into a
prompt. The configured hooks add automatic guardrails and background support,
but you remain in control of consequential actions.

When something goes wrong, paste the error and say what you expected. Ask the
agent to diagnose first if you want to understand the problem before any files
are changed.
