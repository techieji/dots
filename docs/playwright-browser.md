# Using Playwright with Codex

Playwright gives Codex a browser it can navigate and inspect. It is useful for
work that depends on rendered web pages rather than files or command-line
output. In this configuration, Playwright launches a separate Helium browser
profile, keeping automated browsing apart from the normal personal profile.

## Capabilities

Playwright can:

- open pages and manage multiple tabs;
- read page text, links, forms, and accessibility structure;
- click, type, select options, and fill several form fields;
- take screenshots and resize the viewport for responsive testing;
- inspect browser console messages and network requests;
- upload or download files when explicitly permitted;
- wait for dynamic content and follow multi-page workflows; and
- preserve or isolate browser state, depending on how the server is configured.

These capabilities make it effective for research, data collection, visual
verification, and repetitive web workflows. It is still browser automation,
not a source of truth: pages may be incomplete, outdated, deceptive, or
designed to influence an agent. Important information should be verified.

## Applying for jobs

Playwright can reduce the repetitive work around a job search while leaving
important decisions and final submissions to the applicant.

Examples include:

- Search company career pages and collect roles matching a location, field,
  experience level, or technology.
- Compare a job description with a resume and identify relevant experience or
  missing qualifications.
- Extract the title, company, location, salary range, closing date, and source
  URL into a consistent shortlist.
- Check whether apparently duplicated listings differ in team, seniority, or
  requirements.
- Open an application and identify every required field or document before the
  applicant starts.
- Draft tailored resume bullets or a cover letter from verified information in
  the posting.
- Fill routine fields from information supplied for that application, then stop
  before submission for review.
- Revisit saved application pages to check status without changing them.

Example prompts:

> Search these three company career sites for software internships in New York
> or remote. Return a table with title, location, deadline, requirements, and
> the direct posting URL. Do not start an application.

> Read this job posting and compare it with my resume. Suggest truthful edits,
> but do not modify the resume or interact with the application form.

> Fill the application using the information I provide. Do not answer voluntary
> demographic questions, agree to legal terms, or submit the application. Stop
> on the final review page.

Applications should not be submitted automatically. The applicant should
personally verify factual claims, work authorization answers, compensation
expectations, legal acknowledgements, and any voluntary demographic data.

## Helping a student

Playwright can gather information spread across a learning-management system,
course pages, documentation, and library resources.

Examples include:

- List enrolled courses and locate their syllabus, modules, and assignments.
- Build a weekly deadline summary by checking individual course pages as well
  as the global calendar.
- Find assignments that are listed only in modules, schedules, announcements,
  or external course tools.
- Collect office hours, exam dates, grading policies, and required readings.
- Turn a course schedule into a study plan or checklist.
- Open assigned readings and produce study questions or concise summaries.
- Check announcements for schedule changes and compare them with an existing
  plan.
- Inspect public documentation while working on a programming assignment.
- Test a student web project at several viewport sizes and report console,
  accessibility, or layout problems.

Example prompts:

> Review each of my active courses and list work due in the next seven days.
> Check assignments, modules, schedules, and announcements because the global
> calendar may be incomplete. Do not submit or modify anything.

> Find the exam dates and permitted materials in each syllabus. Include the
> page where each fact was found and flag any conflicting information.

> Open my local web project, test the primary workflow at desktop and mobile
> sizes, and report problems. Do not change the code yet.

Playwright should not take quizzes, complete graded work, submit assignments,
post discussions, dismiss announcements, or alter course settings unless the
student explicitly requests an appropriate action and reviews it.

## Safe operating practices

- State whether a task is read-only and name actions that are prohibited.
- Ask the agent to stop before submissions, purchases, messages, deletions, or
  acceptance of terms.
- Enter passwords and multi-factor authentication codes directly in the
  browser, never in chat.
- Keep financial, administrative, primary email, and password-manager sessions
  out of the automation profile.
- Review extracted dates and requirements against the original page.
- Use an isolated session for untrusted sites or disposable research.
- Close the browser or end the Codex session when automated access is no longer
  needed.

The most reliable prompts specify the sites to inspect, the desired output,
the date range or other scope, and the actions that must not be performed.
