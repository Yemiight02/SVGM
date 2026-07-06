# SVGM — Phase 2 (Service Agent)

This folder contains everything needed to register SVGM as a **Service
Agent** on the Anvita Flow Developer Console for the Pharos Agent
Carnival Phase 2.

## Layout

```
phase2/
├── README.md                  ← this file
├── AGENT_CARD.md              ← ready-to-paste Agent Card content
├── PRE_SUBMISSION_CHECKLIST.md← walk-through before clicking Submit
└── svgm/                      ← the actual skill folder
    ├── SKILL.md               ← Anthropic-spec skill description
    ├── scripts/               ← Node.js runtime (viem-based)
    ├── references/            ← ARCHITECTURE, SECURITY, TERMUX, SUBMISSION
    └── assets/                ← logos, sample SVGs
```

## To produce the upload zip

```bash
cd phase2
zip -r ../svgm.zip svgm/ -x "*.DS_Store" "*.git/*" "node_modules/*"
```

Then upload `svgm.zip` at https://flow.anvita.xyz/service-agents when
the Developer Console opens on **July 8, 19:00 HKT**.

## Service Agent card

See `AGENT_CARD.md`. All fields are pre-drafted for paste-in.

## Walk-through

See `PRE_SUBMISSION_CHECKLIST.md`. Don't click Submit until every
checkbox is green.

## Timeline

| Date (HKT) | Event                                              |
| ---------- | -------------------------------------------------- |
| Jul 8 7 PM | Skill uploads open                                 |
| Jul 10 6 PM| Phase 2 hard deadline                              |

## Critical

- Do **not** paste private keys anywhere in the Anvita console or in
  GitHub. Use `.env` and `nano`.
- Do **not** use personal names (DonYemiight, etc.) in the Agent
  Card or anywhere user-facing.
- Price in **PROS** (not USDC) to get the 20% discount.
