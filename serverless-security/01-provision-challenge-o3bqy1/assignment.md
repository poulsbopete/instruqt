---
slug: provision-challenge-o3bqy1
id: esufqdcqkbnb
type: challenge
title: Provision
teaser: Elastic Agent (Defend enabled) pointed at your Serverless Security project.
tabs:
- id: x9pzpqxr8aqw
  title: Terminal
  type: terminal
  hostname: ubuntu
- id: kynknardwrz8
  title: Editor
  type: code
  hostname: ubuntu
  path: /root
difficulty: ""
enhanced_loading: null
---
# 🎯 Assignment: “Spin‑Up, Set‑Off, Shut‑Down” – Your Elastic Serverless Security Mini‑Mission
**Objective** Launch a brand‑new Elastic Serverless Security instance, make it scream with live detections, then nuke it from orbit before it bills you more than a latte.

🛠  Prereqs
| Gear                         | Why                                               |
| ---------------------------- | ------------------------------------------------- |
| [Elastic Cloud login](https://cloud.elastic.co/)          | We can’t defend what we can’t deploy.             |
| Credit card on file          | 💳 ➡ 💔 if you forget cleanup.                    |
| ONE small VM (Win or Linux)  | We are supplying the victim host to enroll the Elastic Agent + Defend. |
| 15 minutes & nerves of steel | Coffee optional, explosions guaranteed.           |


🚀  Part 1 – Launch (5 min)
===
1. Console hop: Log in at https://cloud.elastic.co → Create → Serverless project.
2. Pick a region close to you (latency ≠ legend).
3. Name it something loud, e.g. blast‑lab‑<initials>.
4. Select “Security” as the primary solution.
5. Hit Create project and wait for the magic (≈2 min).

🧪  Part 2 – Ignite (7 min)
===
1. In the new project, open Add integrations → Elastic Defend.
2. Copy the enrollment command and run it on your victim VM. (note, you have Linux x86_64)
3. When the host shows up in Assets → Endpoints, celebrate with a 🔥 emoji.
4. Navigate to Rules --> Detection rules (SIEM) --> Create new rule paste in the following Custom query
```
event.category:"process" and (
process.name:*atomic* or
process.command_line:*atomic* or
process.parent.command_line:*atomic* or
process.command_line:*T1* or
process.parent.command_line:*T1*
)
```
Also, enable all the Elastic Rules, it may take a minute.

5. We also need to enable the Elastic Defend integration

5. Detonate tests. From the [Terminal Tab](tab-0), copy and paste the following:

Big boom:
```
atomic T1055.001        # Linux ptrace process injection
atomic T1053.003        # Cron persistence
atomic T1547.001        # systemd service persistence
atomic T1560.001        # Archive collected files (.tar)
atomic T1110.001        # Bruteforce via /etc/passwd wordlist
```


AI Triage
===
- Navigate to Explore--> Hosts to see your host logs in real-time



