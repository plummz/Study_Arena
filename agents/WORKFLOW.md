# Work flow and closure gates

1. **Intake:** work intake records the request, source, affected student journey, acceptance criteria, sensitivity, dependencies, and only deadlines the user gave. Program manager accepts scope and assigns a head.
2. **Discovery:** learning/product checks real feedback and curriculum claims; design checks flows and language; engineering checks architecture and feasibility. Each specialist sends a deliverable and three pass check to its head.
3. **Head review:** the responsible head reviews specialist output, resolves or logs findings, and hands a versioned, reviewable packet to the program manager.
4. **Implementation:** engineering or content/design owners complete the authorized task. App coordinator suggests tools only after checking availability and data suitability.
5. **Independent gates:** quality head assigns independent verification; QA runs relevant tests; code reviewer examines every code change. Security/privacy review is required when accounts, student data, uploads, AI, social features, rewards, or admin permissions are touched. Findings return to owner and repeat affected gates.
6. **Closure:** program manager checks acceptance evidence, head reviews, QA, independent verification, code review when applicable, and unresolved findings. Only then mark Done. Record residual limitations. Never turn test counts into a quality percentage without a defined denominator and evidence.

Statuses: **Inbox → Scoped → In progress → Head review → Independent verification → QA / code review → Done**. **Blocked** can be entered from any stage; keep the reason and next action visible.

GitHub publication gate: prepare an exact file list, destination, summary, and privacy review for the user before any push, PR, issue, or other GitHub change.
