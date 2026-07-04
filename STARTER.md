## Project Blueprint: Decentralized AI Psychiatric Simulator

## 1. Core Concept & Single-Track Progression Architecture

The game is a choice-driven, strategic psychology simulation where players diagnose and treat patients over daily sessions.
Instead of separating the product into distinct commercial and institutional applications, the game deploys a Unified Single-Track System. Every player begins their career as an entry-level counselor dealing with straightforward behavioral anomalies. As the player invests time, logs successful clinical outcomes, and expands their academic credentials, the entire game engine—including the UI, the depth of the AI simulation, and the grading complexity—organically evolves into a rigorous, professional-tier medical simulator.


## 2. Technical Architecture & Stack

Designed as a zero-server-compute model to completely eliminate scalable AI cloud hosting costs.

          ┌────────────────────────────────────────────────────────┐
          │                 FLUTTER FRONTEND APP                   │
          └───────┬───────────────────┬────────────────────┬───────┘
                  │                   │                    │
          (WebSocket / HTTPS)  (WebRTC Data)       (FFI / C++)
                  │                   │                    │
                  ▼                   ▼                    ▼
      ┌───────────────────────┐ ┌──────────────┐ ┌────────────────────┐
      │    Central Server     │ │  P2P Swarm   │ │  Local Inference   │
      │ • Signaling & Auth    │ │ • Model File │ │ • llama.cpp (GGUF) │
      │ • STUN/TURN (Nat)     │ │   Transfers  │ │ • Action Choices   │
      │ • AI Training Pipeline│ │ • Matchmaking│ │   (Local LLM)      │
      └───────────────────────┘ └──────────────┘ └────────────────────┘


* Frontend UI: Built with Flutter for cross-platform deployment across iOS, Android, Windows, Mac, and Linux.
* Local AI Execution: Utilizes llama.cpp compiled as a shared library via Flutter FFI. Runs highly quantized, low-RAM small models entirely on the user's local hardware.
* Hybrid P2P Network: Relies on a WebRTC data network (p2p_dart) to share patient data files directly between users without a database.
* Lightweight Central Server: Hosted on an affordable VPS to run a Signaling / STUN / TURN architecture (via Coturn) to pierce cell-network firewalls, validate anti-cheat global leaderboards, and execute the core automated Patient Creation & AI Training Pipeline.


### Implementation Priority: Minimal Cross-Platform Runtime First

Before any large-scale networking, content distribution, or advanced economy systems are built, the first engineering milestone should be a minimal proof-of-concept that proves the core loop works inside Flutter on both an Android emulator and a Linux Ubuntu machine.

* Minimal Model First: The initial implementation should target the smallest practical local model that can run through llama.cpp via Flutter FFI and produce believable, structured session responses. The goal is not maximum fidelity at this stage, but reliable execution and stable integration.
* Minimal Manifest First: A tiny patient manifest JSON should be designed as the first playable content object. It should contain only the essential fields needed to drive a single-session interaction, such as patient identity, baseline mood, trust state, symptom pressure, and a few card or response tags.
* End-to-End Loop: The first build should connect the following path in a single flow: Flutter UI → load patient manifest JSON → compose a prompt from the manifest and game state → run local inference through the model → render the output back into the session view.
* Cross-Platform Validation: The same build path must be tested on both Android emulator and Linux desktop so the engineering team can confirm that model loading, asset bundling, JSON parsing, and runtime execution behave consistently across environments.
* Success Criteria: If the minimal model and minimal manifest can produce a coherent session result on both targets, the team has proven the foundational architecture. Only after that should the project expand into richer content, P2P transfer, or advanced clinical simulation logic.

This milestone should be treated as the true first implementation phase, because it validates the project's core promise: that a lightweight local model, a compact patient manifest, and a Flutter-based game loop can run effectively on real devices and desktop environments.


## 3. Server-Side Patient Generation & Distribution Frame

To maintain a high-quality simulation, patient content should move through a clear lifecycle: generation, validation, routing, and distribution. This section defines the server-side framework that produces, verifies, and publishes patient cases in a way that remains controllable and scalable.

### 3.1 Content Generation Pipeline

The server should act as the authoritative content factory for patient cases. It should combine structured author input, procedural synthesis, and gameplay rules into a playable patient manifest.

* Content Assembly: The server should generate patient narratives by combining nine core axes: clinical profile, workplace culture, domestic pressure, cultural context, cognitive distortions, attachment style, somatic vulnerability, maladaptive schema, and insight stage.
* Procedural Variation: Each generated case should receive a unique combination of difficulty, emotional volatility, reward weight, and narrative tone while staying within the intended progression tier.
* Synthetic Training Material: The server may also create synthetic dialogue transcripts or training examples from approved manifests to support local model tuning, but these should remain secondary to the gameplay manifest itself.
* Manifest Output: Each patient case should be compiled into a compact manifest package including identity data, state values, compatibility rules, reward metadata, and a versioned content checksum.

### 3.2 Validation & Safety Gate

A generated patient should not be published directly. It should pass through a validation pipeline before it can enter the live content network.

* Structural Validation: The server should verify that the manifest is syntactically valid, contains all required fields, and conforms to the current schema version.
* Gameplay Validation: Each patient should be checked for basic playability, including solvability, difficulty fit, narrative coherence, and the presence of meaningful but fair session dynamics.
* Toxicity & Safety Screening: The content should be screened for disallowed material, exploitative patterns, or design states that could create broken or abusive outcomes.
* Versioning & Rollback: Every published manifest should carry a version number and checksum so corrupted, outdated, or invalid files can be revoked or replaced without breaking the wider ecosystem.

### 3.3 Distribution & Matching Framework

Once validated, patient cases should be distributed through a hybrid flow that balances fairness, discoverability, and network efficiency.

* System-Assigned Cases: Standard players should receive randomized patient cases that match their current level, study-field access, and clinic profile. The client should request a suitable case from the signaling server, then fetch the manifest from the P2P swarm.
* Premium Catalog Access: Advanced users should be able to browse, filter, and unlock curated patient files from a catalog layer. This preserves a premium experience without undermining the free-to-play routing system.
* Peer Delivery: The P2P network should serve as the main delivery mechanism for manifest files and optional attached assets, while the server remains responsible for indexing, authorization, and matchmaking metadata.
* Routing Intelligence: The distribution system should consider reputation, study-field coverage, clinic pricing, and well-being status so that patients are matched to appropriate therapists rather than randomly assigned.

### 3.4 Open Content Authoring Framework

The project should not be limited to internally generated content. It should also support an extensible authoring ecosystem.

* Authoring Portal: A web-based tool should allow developers, psychologists, humanities researchers, and community contributors to create patient profiles and study-field content through a structured UI.
* Draft-to-Publish Workflow: Authors should be able to create drafts, preview them, validate them, version them, and publish them through a controlled pipeline.
* Controlled Expansion: This framework makes the project suitable both as a polished game experience and as a modular content platform for collaborative expansion over time.

### 3.5 Governance & Moderation Backdoor

Although the system is designed around a decentralized P2P architecture, it should still preserve a controlled administrative backdoor for safety and integrity enforcement.

The operator or designated moderation team should retain the ability to:

* Ban or suspend accounts involved in cheating, abuse, exploitation, or policy violations.
* Modify or revoke privileges, reputation state, or access to premium content when necessary.
* Remove, quarantine, or replace patient manifests that are malicious, corrupted, exploitative, or otherwise unsafe.
* Freeze or invalidate suspicious content propagation within the P2P swarm.

This moderation layer should operate as a secure administrative control plane alongside the decentralized network, not instead of it. Its purpose is to preserve openness and community participation while retaining a final authority for safety, integrity, and anti-cheat enforcement when absolutely necessary.


## 4. Single-Discipline Role: The Clinic "Therapist"

To keep gameplay highly focused and minimize design bloat, all players assume a single, omni-capable professional role: The Therapist.

* Integrated Toolkit: The Therapist combines psychological counseling with chemical intervention. Gameplay requires balancing behavioral dialogue tactics with prescription management.
* Fictionalized Pharmacology: To fully neutralize legal risks and App Store rejection, the game utilizes an immersive index of made-up, sci-fi/noir sounding medicine names (e.g., Zenithium for acute anxiety, Lucidex for manic detachment).
* The Treatment Tightrope: Prescribing medicine can temporarily lower a patient's hidden agitationLevel or suppress severe symptoms, but it triggers unique side effects that alter the patient's dialogue behavior, forcing the player to adapt their strategy.


### App Store & Legal Safety
* Position the product clearly as a fictional, interactive simulation—not real therapy or medical treatment.
* Avoid claims of diagnosis, treatment, or mental health cure; use game-focused language like “simulation,” “scenario,” or “narrative experience.”
* Use fictional disorders and fictional pharmacology, not real clinical diagnoses or medications.
* Include explicit disclaimers: “This game is a fictional simulation and not a substitute for professional mental health care.”
* Do not collect or store real health data. Treat player profiles as game state only, and keep PII separate from gameplay data.
* Keep store metadata and app text focused on entertainment and strategy, not clinical guidance.


## 5. Career Evolution & Daily Study Point Economy

The game experience organically transitions from an introductory psychology simulation into a clinical simulator via the interlocking mechanics of experience metrics, supervised training, and academic expansion.

                      [CAREER EVOLUTION PIPELINE]
                                   │
                                   ▼
          [Level 1-10: Internship / Trainee Clinician Phase]
          • Players begin as senior psychiatry/therapy students who are still in training.
          • The first ten levels represent an internship period focused on supervised cases, mentorship, and foundational skill-building.
          • Early cases are meaningful, dramatic, and emotionally engaging rather than boring tutorials.
          • High UI assists, guided card decks, and structured feedback help players learn without feeling overwhelmed.
          • Players earn 1 Study Point per level-up during this internship phase.
                                   │
                                   ▼
          [Level 11-30: Intermediate Clinical Practice]
          • Players graduate from internship status and begin operating with greater autonomy.
          • Nested defense mechanisms and somatic symptoms unlock.
          • Introduction of fictional psychopharmacology.
                                   │
                                   ▼
          [Advanced Career Tier / Endgame Progression]
          • Unlocks the automated "Attending Physician" Assessment Rubric.
          • Complex, volatile multi-axis trauma files dominate the inbox.
          • The highest tier is not fixed in advance; it expands as more study fields, specializations, and clinical challenges are introduced.


### The "Experience Magnet" Mechanic

* Progression-Gated Pathologies: Early-stage players only attract low-stakes, highly expressive cases (e.g., simple anxiety surrounding an office transition).
* The Complexity Vector: As a player wins sessions, their profile Experience Rating climbs. High XP metrics modify the client's internal routing seed, turning their profile into an "experience magnet" that pulls increasingly unstable, multi-layered, and pathologically volatile patient manifests out of the network swarm.


### The Daily Study Point Economy

* The Free Daily Point: Every 24 hours, the game awards every player exactly one Free Study Point upon login.
* The University Hub Tree: Points are spent to study specialized medical fields (e.g., Somatoform Mechanics, Advanced Behavioral Defense Systems).
* Knowledge Pool Unlock: Unlocking a field makes matching specialty techniques available. However, players must manually load these acquired skills into an active format before a session to counteract advanced psychological crises.
* Level-Gated Fields: The total number of study fields that can be unlocked is capped by a player’s current level; players can reach higher levels without unlocking every field, but they cannot unlock every field without first reaching the required level thresholds.
* Highest-Level Correlation: The maximum career level is not fixed at the outset; it scales with the number of study fields, specializations, and progression tiers designed into the game. The full set of fields becomes available progressively as the player advances through the career path.
* Study Field Cost Balance: The study tree should use a balanced cost structure where foundational psychology fields can be unlocked with a single study point, while more advanced, high-impact, or highly specialized fields require multiple points to preserve meaningful progression and avoid over-saturation.
* Subspecialty Layer: A second layer of study fields should be introduced beneath the core psychology tree. These subspecialties should be treated as advanced cross-disciplinary branches that draw from humanities such as literature, sociology, philosophy, cultural theory, and social science. Each subspecialty should receive an effective value multiplier, where 1 study point spent there behaves as if it were worth 6 points in terms of unlock power, card access, and narrative influence.
* Core vs. Subspecialty Identity: Regular psychology fields should primarily reinforce Disclosing-style breakthrough logic, while humanities-driven subspecialties should bias toward Relatable, Postponing, and Manipulative card generation, giving the player distinct playstyles and tactical identities.
* Regular Field Reward Logic: When a player completes a regular study field, they should occasionally receive a bonus Relatable card as a reward. This should occur with a 75% chance, making the reward common and reinforcing the idea that steady rapport-building is a useful everyday tool.
* Subspecialty Reward Logic: When a player completes a subspecialty field, the reward distribution should be weighted toward more tactical and socially expressive cards: 25% Relatable, 35% Postponing, and 40% Manipulative. This creates a stronger identity difference between standard psychology study and humanities-driven subspecialty study.


### Early Game Retention: The New Clinician Track

* Introductory cases should feel like meaningful psychology scenarios instead of a dry tutorial.
* Start with a strong first patient narrative that frames the player as a new clinician helping someone avoid a career or relationship crisis.
* Introduce mechanics one at a time and reward progress quickly with small XP gains, new study notes, new cards, or reputation boosts.
* Offer diverse early cases: workplace stress, social anxiety, sleep disruption, and interpersonal conflict.
* Give the player meaningful choices on each case, with 2–3 plausible treatment options and visible consequences.
* Avoid harsh punishment for early failure; use mistakes to teach and redirect instead of drive players away.
* Include a “safe practice clinic” mode or mentor guidance system for newcomers to experiment with low-consequence strategies.
* Provide daily login hooks and a short “first week” reward path to keep new players coming back.


### Free Source Inspiration for Study Fields

* Open educational resources such as OpenStax Psychology, MIT OpenCourseWare, and Khan Academy can inspire course themes and terminology.
* Public-domain and Creative Commons material from Wikipedia, Project Gutenberg, and NIH/NIMH summaries are useful for designing field structure without copying proprietary content.
* Free mental-health references like WHO ICD-11, CDC guides, and open-access PubMed Central papers provide concept ideas for anxiety, trauma, resilience, and behavioral frameworks.
* Game-design resources like GDC Vault free talks, itch.io devlogs, and Unity/Godot learning content can guide how to make study fields feel rewarding and balanced.
* Use these sources for inspiration, not verbatim content; prefer fictionalized field names and gameplay concepts to stay safe and distinctive.


## 6. Patient Attraction Vector: The Three-Parameter Evaluation Framework

To attract increasingly complex, prestigious, or rare patient manifests from the network, a player's clinic profile is evaluated dynamically across three primary metrics. These metrics determine the "attraction weight" for incoming P2P patient requests.

          ┌────────────────────────────────────────────────────────┐
          │               CLINIC ATTRACTION ENGINE                 │
          └───────┬───────────────────┬────────────────────┬───────┘
                  │                   │                    │
                  ▼                   ▼                    ▼
          ┌────────────────────────┐ ┌──────────────┐ ┌────────────────────┐ ┌───────────────────────────┐
          │    1. REPUTATION       │ │ 2. PRICING   │ │ 3. STUDY FIELDS    │ │ 4. WELL-BEING (MIND)      │
          │ • Lifetime Client Count│ │ • Session Fee│ │ • Total Unlocked   │ │ • Stress / Energy Levels  │
          │ • Success / Cure Rate  │ │   Set by User│ │   Specializations  │ │ • Burnout / Recovery Speed│
          └────────────────────────┘ └──────────────┘ └────────────────────┘ └───────────────────────────┘


### 1. Reputation (Practice Health)

* Growth Triggers: This value updates strictly based on clinical outcomes. It increases with the total volume of treated patients and the percentage of successful therapeutic conclusions (cures).
* Gameplay Impact: Higher reputation scores unlock complex workplace patient tiers (e.g., high-level politicians or secret agents) who refuse to sit with unproven therapists. Conversely, letting patients walk out or misdiagnosing them penalizes this metric.


### 2. Therapist Well-Being (Mental Health Resilience)

* Core Role: This hidden stat represents the player character's own mental health, emotional stamina, and ability to process patient trauma safely.
* Degradation: Well-being declines over time and with consecutive therapy sessions, especially when treating high-agitation patients, chaotic manifests, or repeated failures.
* Gameplay Impact: Low well-being lowers the clinic's effective performance, slows recovery between cases, and increases the chance that complex patients bypass the therapist's inbox. It also enables mechanics like forced rest, burnout freezes, and mandatory Academic Sabbaticals.


### 3. Pricing per Patient (The Financial Position)

* User-Controlled Slider: Players can manually set their session price rate (in-game currency).
* The Economic Balancing Act: Setting high prices increases profit margins per session but shrinks the pool of casual, blue-collar, or standard patients willing to schedule an appointment. Setting competitive low prices floods the inbox with high-volume, lower-paying cases, functioning as an organic gameplay difficulty scaling slider.


### 4. Number of Study Fields (Academic Authority)

* The Credential Count: Measures the total sum of completed academic courses and certifications unlocked via the Daily Study Point tech tree.
* Gameplay Impact: Highly complex patient manifests scan this number before spawning. A patient suffering from an ultra-rare, fused trauma scenario will outright bypass a therapist's inbox if their absolute count of unlocked study fields is too low to guarantee professional competence.


### Stat Formulas & Percentage Calculations

* Reputation % = (Successful Cases / Total Cases) × 100
  - Example: 180 successful / 200 total = 90%
* Study Field Coverage % = (Unlocked Study Fields / Total Study Fields) × 100
  - Example: 12 unlocked / 20 total = 60%
* Experience Progress % = (Current XP / XP required for next level) × 100
  - Example: 2,250 XP / 3,000 XP = 75%
* Price Accessibility % = 100 - ((Current Price - Min Price) / (Max Price - Min Price) × 100)
  - Example: min=50, max=300, price=150 → 60%
* Clinic Attraction % = (Reputation % + Price Accessibility % + Study Field Coverage %) / 3
  - Example: (80 + 60 + 50) / 3 = 63.3%
* Well-Being % = (Current Well-Being / Max Well-Being) × 100
  - Example: 32 / 100 = 32%


### Well-Being Recovery & Burnout Thresholds

* Well-Being Loss: Each session reduces well-being by a base percent, increased by case difficulty and agitation impact.
* Recovery Actions: Rest, lower caseload, or complete a study sabbatical to regenerate well-being.
* Burnout Trigger: If Well-Being % falls below a defined threshold (for example, 25%), the clinic enters a burnout state with reduced performance and forced recovery mechanics.


## 7. Hybrid State Management: BaaS Managed Free-Tier & P2P Swarm

To ensure ironclad progress preservation and prevent file tampering without incurring database scaling costs, the architecture deploys a Hybrid Storage Vector. Heavy narrative data remains inside the P2P network, while strict user profile variables are anchored securely to a high-utility cloud platform.

### The Backend-as-a-Service (BaaS) Footprint

* The Free-Tier Infrastructure: The architecture utilizes a managed relational cloud database tier (e.g., Supabase PostgreSQL Free Tier) paired with built-in ecosystem plugins for Apple/Google authentication and row-level security.
* The Primitive Payload Schema: The server-side cloud table strictly forbids the storage of rich text logs, conversational transcripts, or massive binary scripts. It functions exclusively as a primitive matrix tracking atomic player metrics under 0.5 KB per profile, permitting up to 1,000,000 active players to fit comfortably within the 500 MB database limits:

```json
{
  "user_id": "auth_uuid_99218",
  "experience_points": 4520,
  "reputation_rating": 89,
  "session_pricing": 150,
  "unlocked_study_ids": ["cbt_anxiety_01", "somatic_panic_02"]
}
```


### The Synchronization & Anti-Cheat Validation Loop

   1. Session Handshake: Upon application boot, the Flutter application pulls the authenticated user's primitive JSON map from the cloud database via secure SQL calls. This data initializes the variables inside the local Dart Game Brain.
   2. P2P Profile Sync: When broadcasting presence to the WebRTC P2P swarm, the Flutter client signs this cloud-verified data packet using its private cryptographic key. Other network nodes read this signed block to populate the public matchup and referral directories.
   3. Session Conclusion Verification: When a therapy round finishes, the Flutter app calculates the resulting metrics local-side and pushes a verified execution receipt to the server API. The cloud database updates the primitive numerical stats, ensuring that if a user clears their device cache or switches devices, their economic position, tech tree certifications, and network ranking remain permanently safe.


### Simulation Sandbox & Rule-Testing Framework

The project should include a dedicated simulation framework for rapid verification of game rules and feature balance. This framework is not intended as a replacement for normal gameplay, but as a fast, controllable environment for stress-testing the systems during development.

* Accelerated Sandbox Runtime: The game should support a sandbox mode where values, parameters, and state transitions can be run in an accelerated time setting so designers and developers can observe long-term outcomes in minutes rather than days.
* Parameter Mutation Testing: Developers should be able to modify game values such as patient difficulty, case rewards, study point gain, reputation decay, clinic attraction thresholds, and trauma multipliers in a controlled manner without altering the live production ruleset.
* Bot-Driven Simulation: The framework should support simulated players who execute test cases automatically. Each bot should have a configurable expert level from 1 to the maximum supported tier, allowing different levels of competence and decision quality to be tested.
* Profile and Clinic State Injection: The sandbox should permit preloading specific player states, including unlocked study fields, clinic attributes, reputation values, pricing settings, and well-being states, so the system can simulate different progression conditions quickly.
* Admin Override Layer: A master or admin control panel should allow the operator to set static, default values that override the normal rule evaluation for specific test scenarios and time windows. These overrides should remain stable during the test run and should not be silently altered by ordinary gameplay logic.
* Test Case Scenarios: The framework should support scenario-based testing for common gameplay flows such as patient cure, patient walkout, reputation recovery, study field unlocking, card reward distribution, trauma escalation, and clinic financial stress.
* Result Tracking & Diagnostics: Each simulation run should emit structured logs and summary metrics so designers can compare outcomes before and after rule changes.

This testing layer should be treated as a core infrastructure requirement because it will greatly shorten iteration time, surface design issues early, and make balance tuning far more practical.


### Realistic P2P & Client Simulation Environment

In addition to the fast-paced rule-testing framework, the project should also include a more realistic simulation environment for observing how the Flutter client and the P2P network behave under closer-to-production conditions. This environment is distinct from the rapid balance sandbox and is intended for debugging runtime behavior, networking issues, client-state transitions, and distributed case flow.

* High-Fidelity Network Sandbox: The team should be able to run multiple local client instances in a controlled test environment that mimics the real P2P topology, including peer discovery, file transfer, case handoff, and signaling behavior.
* Flutter Runtime Inspection: This environment should allow developers to observe how the Flutter app behaves under realistic conditions, including cold starts, state synchronization, reconnects, manifest loading, and local model invocation.
* P2P Failure Injection: The sandbox should support deliberate network disturbances such as dropped peers, delayed packet delivery, partial file transfer, duplicate manifests, and temporary disconnects so engineers can study resilience and recovery.
* Client-State Reproduction: Developers should be able to reproduce specific clinic or patient-flow conditions in a controlled way, including patient transfer events, session interruptions, and therapist reassignment scenarios.
* Separate from Balance Testing: Unlike the accelerated rule sandbox, this environment is not primarily for tuning card balance or progression math. Its purpose is to verify that the distributed client and P2P layer behave in a stable, observable, and debuggable way.
* Expected Outcome: When this environment is mature, it will let the team investigate real-world network behavior before the game is exposed to broader testing, reducing the risk of subtle issues that only appear under actual peer-to-peer conditions.

This realistic sandbox should be treated as a second, parallel test infrastructure layer: one for fast iteration on game rules, and one for faithful investigation of the distributed client and network system.


## 8. The Simulation Core vs. the Dialogue Layer

To keep the experience stable, readable, and mechanically fair, the game engine is split into two clearly defined layers.

* The Simulation Core: A deterministic game layer handles all rules, state changes, and outcome resolution. It tracks variables such as trustScore, agitationLevel, activeDefense, medication effects, and session progress. This layer decides whether a move succeeds, fails, stabilizes a patient, or triggers a crisis.
* The Dialogue Layer: The local LLM does not decide gameplay outcomes. Instead, it receives a compact, structured prompt from the simulation core and generates conversational text that reflects the current state of the scene. Its job is to voice emotion, pacing, and personality, not to invent new rules.
* Guardrails and Constraints: The prompt passed to the model is limited to information already approved by the simulation core, such as current mood, relationship tension, and available narrative context. This prevents the AI from bypassing the rules, contradicting the state of the game, or drifting into unsupported behavior.
* Why This Matters: This design makes the system feel more grounded. Players can trust that their choices have real consequences, while the AI remains useful for atmosphere, variation, and believable dialogue.


## 9. Choice-Driven Interface (The Therapy Deck & Loadout System)

Open-ended text/voice typing is replaced by structured, high-stakes tactical inputs to ensure flawless gameplay stability and prevent cognitive clutter in the endgame.

* The Active Therapy Loadout: To combat interface bloat as a player scales their academic specializations, players cannot take all unlocked cards into a session. They face a hard restriction limit of 5 or 6 Active Card Slots per session layout.
* The Clinical Preparation Phase: Prior to initiation, the player evaluates the initial patient profile intake details and curates an active deck configuration (e.g., matching Somatic Grounding cards to a suspected panic presentation). Equipping incorrect loadouts leaves the player functionally exposed, forcing tactical retreats or reliance on suboptimal techniques.
* Graphical Controllers: Flutter UI sliders and dials allow players to dynamically alter their conversation focus (e.g., Childhood vs. Workspace) and emotional delivery posture (Warm vs. Objective).
* Jailbreak Immunity: Because the AI model only receives rigid inputs from a predetermined card setup, it is mathematically impossible for users to trick or break the AI's character.


### Private Master Playbook & Adaptive Card Benchmarking

Even though the game is not designed as a single-ended victory loop, it should still maintain a private, evolving benchmark layer that is visible only to the designer or operator. This benchmark is not meant to be shown to players; it exists to keep balance consistent and to calibrate the relative strength of card combinations.

* Secret Initial Cheat Sheet: For untreated patients who have not yet been exposed to clinical intervention, the system should maintain a hidden reference sheet that identifies the strongest known card combination for that patient profile. This sheet acts as the initial best-practice baseline for success-rate tuning.
* Calibration Function: The hidden sheet should be used to estimate the expected success percentage of other card combinations relative to that benchmark. In practice, this allows the team to make sure that alternative decks are meaningfully strong, weak, or situational rather than arbitrarily random.
* Benchmark Decay & Mutation: Once a patient has been treated, partially treated, or materially altered by the session state, the credibility of the original benchmark should gradually decay. The original sheet should not remain a fixed truth forever; instead, it should mutate over time as the patient state evolves.
* Adaptive Master Algorithm: The game should maintain a master algorithm that continuously recomputes the best card combination for treated patients, mutated patients, and patients whose condition has drifted from the original profile. This algorithm should evaluate current trust, agitation, symptom pressure, prior card history, medication state, and study-field compatibility.
* Internal Balance Control: The adaptive algorithm should be the canonical mechanism for maintaining consistency across the entire card system. It should prevent the game from drifting into situations where some deck combinations become universally dominant or universally useless.
* Output Layer: The system should expose a private diagnostic output for the designer, including the recommended deck, expected win probability band, and the current confidence score of the recommendation.

This hidden benchmark layer is a balance tool, not a player-facing mechanic. It ensures that the game remains manageable, internally coherent, and tunable as patient states evolve over time.


## 10. Procedural Manifests & Advanced Psychological Fusion

Patients are unique data objects (.JSON patient manifests) generated server-side and transferred via P2P. To maximize simulation realism, the content engine procedurally weaves an extensive multi-axis framework encompassing nine distinct human tracks:

### The Nine-Track Synthesis Pipeline

   1. Clinical Axis (DSM-5 Core): The foundational diagnosis (e.g., Major Depressive Disorder, Generalized Anxiety).
   2. Workspace Culture: Professional background, operational jargon, and occupational stressors (e.g., Scuba Instructor, Politician).
   3. Domestic Status: Active living environment, financial pressure points, and interpersonal isolation parameters.
   4. Ethnicity/Cultural Filter: Native backgrounds dictating structural stigmas surrounding clinical intervention.
   5. Cognitive Distortion Profile: The operational lens of flawed logic (e.g., Catastrophizing, Black-and-White thinking) shaping text output defenses.
   6. Attachment & Relational Style: Behavioral boundary postures (e.g., Anxious, Dismissive-Avoidant) governing the baseline starting Trust Score.
   7. Somatic Vulnerability Axis: Targeted physical manifestations of distress (e.g., Hyper-ventilation, gastric nausea) triggered during active panic crises.
   8. Core Maladaptive Schema: The deeply buried, subconscious childhood trauma lens (e.g., Defectiveness, Abandonment) serving as the ultimate endgame case resolution goal.
   9. Insight / Stage of Change Axis: The active self-awareness metric (Pre-contemplation, Contemplation, Action) determining how receptive the patient is to direct clinical interpretations.


### Patient Ownership, Forgetful Chronic Cases & Transfer Risk

To preserve integrity and reduce case fragmentation, individual patients should be assigned to one therapist at a time until the case reaches a meaningful end state.

* One-Therapist Ownership: A patient manifest should remain owned by a single active therapist across sessions until the case is closed through successful cure, explicit abandonment, or a hard failure threshold where the case is considered no longer recoverable for that therapist.
* Social Chronic Patients: Patients in the social/chronic pool should be treated as memory-poor cases. They do not retain meaningful user data, therapist identity, or long-term personal history across clinics. Their state should be based on the current case context rather than on preserved player-specific memory.
* Doubt Pressure: Each patient should carry a hidden Doubt value that rises gradually over time and can increase when the therapist uses Manipulative cards repeatedly or when session prices rise sharply across consecutive sessions. This should feel emergent and contextual rather than deterministic.
* Transfer Escape Valve: If Doubt crosses a threshold and a stochastic roll succeeds, the patient may decide to leave the current clinic and be reassigned to a different available therapist of the same progression tier in the network. This should be rare enough to preserve tension, but frequent enough to feel like a real risk.
* Balance Intent: The chance of transfer should remain low in ordinary play, with a small base probability per session and stronger escalation only after sustained pressure. A good target is a low base chance of roughly 2% to 4% per session, increasing to a more noticeable range only after repeated stressors, with a hard cap that prevents constant churn.
* Fair Reassignment: Reassigned patients should be routed to a free, compatible therapist of similar level rather than to a random high-level specialist, ensuring the system remains fair, readable, and enjoyable rather than punishing the player with arbitrary case loss.

This rule set creates a strong ownership model for cases while still allowing occasional, believable patient migration when a therapist's approach becomes too risky or unstable.


## 11. The "Universal Actor" Storage & Asset Pipeline

To prevent the application from consuming hundreds of gigabytes of device storage, the technical architecture separates cognitive processing from narrative identity.

### The Fixed Storage Footprint

* The Base Persona Core (.GGUF): The client application bundles or streams a single, unified, ultra-compressed open-source base language model (e.g., 3-Billion parameters). This model acts as a "Universal Actor" trained to understand dramatic pacing, clinical terminology, and roleplay instruction adherence. It occupies a static ~1.8 GB footprint that never grows.
* The patient manifest (.JSON): Every individual patient in the game—including their workspace culture, trauma backstory, current emotional statistics, and dialog pathways—is stored as a microscopic text file under 50 KB.


### Immersive UI Representation (The Client File Cabinet)

* The Clinical Archive: Inside the game UI, this architecture is stylized as a literal "Patient File Cabinet."
* Dynamic Thread Injection: When a player clicks on a specific patient's folder to start a therapy session, the Flutter engine instantly reads that patient's tiny JSON file. It feeds the unique behavioral rules, fictional medicine tolerances, and workspace slang directly into the active memory layer of the single base model.
* Zero-Overhead Memory Swapping: When the player switches to a different patient, the base model remains loaded in the phone's RAM. Only the 50 KB text script is swapped out, allowing instantaneous session transitions with zero processing lag or storage bloat.


## 12. The Adaptive Free-Tier Router (Dynamic Difficulty Matrix)

To prevent early-game frustration and ensure a balanced player onboarding curve, the server-side random assignment system filters incoming P2P patient manifests through a dynamic player matching matrix.

                [Free User Requests Daily Case File]
                                │
                                ▼
                [Evaluate Profile Vector Stats]
                • Reputation Metric & XP Threshold
                • Number of Unlocked Study Fields
                                │
                                ▼
        ┌───────────────────────┴────────────────────────┐
        ▼                                                ▼
      [MATCH VALID: Standard Route]            [LUCK FAILURE: 5% Chaos Roll]
      • Filter: Manifest tags <= Study Tier    • Force-Bypass standard checks.
      • Match: Low-to-Mid trauma levels.       • Inject High-Trauma Specialty Case.


### Standard Algorithmic Filtering

* The Safety Check: The client application pings the signaling server with its encrypted profile vector. The server reads the player's total Number of Study Fields and screens available P2P patient manifests.
* The Blueprint Lock: The router prevents the system from assigning complex patients whose defense mechanisms or pathologies require locked specialization cards, keeping early-game sessions fair and educational.


### The "Misfortune Roll" Exception (The Chaos Mechanic)

* The 5% Probability Gap: Every daily assignment carries a hard-coded 5% "Luck Failure" probability roll. If triggered, the system intentionally bypasses the safety filters and routes an elite, volatile, or highly mistreated patient manifest to a new user's clinic.
* The Strategic Exit Choices: When a player faces a crisis case they lack the specialization cards to solve, the game engine rewards tactical decision-making over blind risk:
1. Direct Rejection: The player declines the case upfront. The patient manifest returns to the P2P swarm pool. The player suffers zero reputation penalties but earns zero points.
   2. The Referral Reward (The Safety Valve): If the player starts the interview, evaluates the symptoms, and uses the WebRTC P2P interface to transfer the case to a qualified friend, the game engine rewards them with +1 Universal Experience Point for demonstrating professional ethical awareness.
   3. The Ruin Trajectory: If the player attempts to force the session using generic cards, the patient’s agitation will spike rapidly, causing them to walk out, which severely cripples the player's clinic reputation.


## 13. The Financial Stabilizer: Anti-Bankruptcy & Anti-Pay-to-Win Mechanics

To prevent a permanent failure loop where a player's profile metrics collapse, the system provides two distinct recovery trajectories. These paths are designed to prevent "Pay-to-Win" shortcuts, balancing progress via strategic planning instead of monetary microtransactions.

      +-----------------------------+
      |                           CLINIC FINANCIAL RECOVERY MATRIX                              |
      +-------+---------------------+
      | Strategy A: The Discount Practice   | Strategy B: Academic Sabbatical (Study Sabbat)    |
      +-------+---------------------+
      | • Action: Lower the session fee     | • Action: Set clinic to "Closed" mode.            |
      |   using the Pricing Slider.         | • Loop: Spend Daily Points on core certs.         |
      | • Payoff: Floods inbox with casual, | • Payoff: Re-opens clinic with automatic baseline |
      |   low-stakes patient manifests.     |   Reputation restore based on total credentials.  |
      | • Penalty: Slashes XP gains by 50%  | • Penalty: Zero currency earned during downtime.  │
      +-------+---------------------+


### Strategy A: The Discount Practice (High-Volume Recovery)

* The Slider Interaction: When a player’s reputation drops past a critical operational threshold, wealthy or complex patients stop booking appointments. The player must manually slide their Pricing per Patient metric to a heavily discounted rate.
* The Mechanical Tradeoff: Dropping prices alters the routing seed, flooding the clinic inbox with entry-level, highly cooperative casual patients.
* The Progression Penalty: To maintain economic balance, all sessions treated under a default "discounted rate" trigger a static 50% Experience Point Penalty. The player can easily rebuild their lost reputation points through high-volume, easy wins, but their character's mechanical leveling progression is severely slowed down.


### Strategy B: Academic Sabbatical (The Study Sabbat)

* The Clinic Closure: Alternatively, the player can toggle an on-screen "Academic Sabbatical" status flag. This completely pauses the daily incoming patient router.
* The Reputation Restore: While closed, the player accumulates their Free Daily Study Points and completes specialized courses in the university hub. When they unlock a new certification milestone, the engine runs an internal math loop (Reputation Reset Minimum = Total Study Fields * Base Competency Constant).
* The Outcome: The player's baseline clinic reputation automatically scales back up to a minimum safe floor value based entirely on their academic credentials. They forfeit all potential currency earnings during the downtime, but they return to active practice fully optimized to face complex pathologies without spending a single cent of real-world money.


## 14. The Advanced Clinical Tension Engine: Dynamic Card Specs & Endgame Evolution

To challenge experienced players and prevent late-game monotony, the system scales patient complexity in direct proportion to academic advancement. The game transitions from a simple diagnostic guessing game into a multi-session strategic chess match.

                  ┌────────────────────────────────────────┐
                  │       PLAYER RESEARCH & TX LOOP        │
                  └───────────────────┬────────────────────┘
                                      │
                                      ▼
                  ┌────────────────────────────────────────┐
                  │ Session 1: Use Relatable/Postponing    │
                  │ • Gather subtle context & workspace clues│
                  └───────────────────┬────────────────────┘
                                      │
                     ┌────────────────┴────────────────┐
                     ▼                                 ▼
         [Exit Session: Analyze File]        [Spend Daily Points / Study]
         • Match clues to DSM manuals.       • Acquire specific target card.
                     │                                 │
                     └────────────────┬────────────────┘
                                      ▼
                  ┌────────────────────────────────────────┐
                  │ Session 2: Play "Bull's Eye" Counter    │
                  │ • Trigger dramatic clinical breakthrough│
                  └────────────────────────────────────────┘

* The Professional-Tier Shift (Advanced Grading Rubric)

* The Automated "Attending Physician" Report: Once a player reaches a sufficiently advanced progression tier, the game unlocks its analytical advanced simulator. These notifications are replaced by an advanced Clinical Assessment Matrix. The local Dart engine tracks card sequence selections to deliver a multi-page analytical report scoring the user on Therapeutic Alliance Maintenance, Diagnostic Path Efficiency, and Pharmacological Safety.
* The Multi-Session Siege: High-tier patients possess nested, multi-layered defensive frameworks that resist immediate resolution. The player must exit active daily check-ups to analyze collected linguistic clues, comparing text histories against the app's diagnostic encyclopedia before entering subsequent rounds.


## 15. The Four-Tier Functional Card Taxonomy & AI Fatigue Countermeasures

Instead of static "win/lose" options, cards possess context-dependent behavioral properties. To guarantee veteran players do not face behavioral redundancy from the core AI actor, dynamic conversational variances alter execution vectors.

### Linguistic Vector Mutation & Conversational Curveballs

* Linguistic Archetype Prompt Components: To bypass repetitive syntax loops, the 50 KB player manifest shifts the base model's prompt layout using a style filter (e.g., The Cynic vs. The Intellectual), making identical underlying conditions sound entirely distinct.
* The Transference Spike: High-trauma sessions prompt sudden relational shifts where conventional Empathy cards are read programmatically as Manipulative Failures, completely flipping the required tactical strategy.


### The Dynamic Card Spec Matrix

```text
DYNAMIC CARD SPEC MATRIX

1. DISCLOSING
• Signature: Precision / Breakthrough
• Best at: revealing hidden truth

2. RELATABLE
• Signature: Rapport / Stabilization
• Best at: warming the exchange

3. POSTPONING
• Signature: Deferral / Tempo Control
• Best at: slowing crisis pressure

4. MANIPULATIVE
• Signature: Pressure / Disruption
• Best at: breaking rigid defenses
```


### The Signature Card Principle

* Context-Over-Deck Logic: Sessions should be governed primarily by the current emotional, relational, and narrative context of the patient rather than by a rigid deck-based assumption that one card is always correct.
* Correct vs. Incorrect Fit: A card can be correct even if it is not Disclosing. Sometimes a Relatable or Postponing card is the most appropriate response, and sometimes a Disclosing card is a poor choice. The system should reward tactical reading of the scene rather than simple card memorization.
* Contextual Bias: When a card is played in a situation that aligns with its signature, it produces its intended effect strongly and clearly. When it is used in a mismatched context, it still functions, but its payoff is less precise and more unstable.
* Identity Separation: This system keeps the four card types distinct from one another, ensuring that each one still feels like a recognizable tactical role rather than a generic interchangeable action.
* Aesthetic Variety: The four card types should not all look the same. Some should present as full-sentence therapeutic prompts, while others should appear as compact phrases, coded words, symbolic figures, or image-based clinical cues. This preserves a rich visual identity without bloating the interface and helps make the card system feel psychologically evocative rather than merely text-heavy.
* Advertising Through Mechanics: A card should mostly deliver what its name and role imply. Disclosing should feel like a breakthrough tool, Relatable should feel like rapport-building, Postponing should feel like tempo control, and Manipulative should feel like pressure and disruption.


### 1. Disclosing (The Clinical Catalyst)

* The Interaction: Triggered when the selected card matches the current emotional and narrative context of the patient, especially at moments where a sharp truth, insight, or hidden pattern needs to be exposed.
* The Result: Drastically drops the patient's agitationLevel, permanently increments trustScore, cracks open their defensive shield, and unlocks deep, core narrative backstory dialogue.


### 2. Relatable (The Safe Rapport Builder)

* The Interaction: Triggered by conversational techniques that align softly with the patient's ethnic background, domestic status, or general professional archetype without directly touching the underlying trauma.
* The Result: Grants a nominal, un-satisfying bump to trustScore (+2 to +5) and prevents crises. It acts as an operational buffer, giving the player a safe, low-risk move when they are stalling for time or collecting linguistic clues.


### 3. Postponing (The Tactical Stalemate)

* The Interaction: Cards that deploy objective clinical deflection, generic therapeutic silence, or bureaucratic scheduling prompts.
* The Result: Freezes the current game state for 1 to 2 turns, rendering the patient's agitation static.
* The Multi-Session Decay: Playing Postponing cards introduces a creeping negative modifier to the overall case file. Over several sessions, the patient grows increasingly impatient with the lack of progress, causing their baseline starting agitation in subsequent daily check-ups to climb.


### 4. Manipulative (The Psychological Double-Edged Sword)

* The Interaction: Manipulative cards are not simple "bad" actions; they are high-risk, precision-based interventions that exploit relational pressure, strategic contradiction, or emotional inversion to break rigid defenses. They are designed for moments where the patient is too guarded, too defensive, or too emotionally over-controlled for standard rapport-building.
* The Strategic Setup: A Manipulative play is most effective when the therapist has already established a strong enough foundation of trust, timing, or clinical leverage. If used too early, it can backfire immediately; if used at the right threshold, it can collapse a defense structure and unlock otherwise inaccessible narrative layers.
* The Result: A volatile, structural gamble evaluated dynamically by the client/Dart engine:
* Success (High Trust State): The patient’s defense mechanism is shattered, revealing hidden insight, cracked narrative layers, or a core trauma node. This can bypass normal study-tree requirements, accelerate clue discovery, and create a dramatic breakthrough that would otherwise be unreachable.
* Partial Success (Ambiguous State): The patient does not fully collapse, but the pressure exposes a new vulnerability. The therapist gains partial information, the patient becomes more unstable, and the next turn becomes more dangerous.
* Failure / Derangement (Low Trust State): The patient becomes psychologically deranged by the pressure. The Dart engine may mutate the patient's manifest into a chaotic, secondary pathology state, such as a hyper-defensive paranoia loop, a dissociative collapse, or an emotionally fragmented response. In this state, the existing study cards lose effectiveness, and the patient may move rapidly toward a crisis loop or institutional referral.
* Reputation and Tension Tradeoff: Manipulative cards should create a meaningful risk-reward loop. They can generate elite breakthroughs and rapid progression, but they also increase the chance of therapist reputation loss, patient hostility, or long-term emotional damage if overused.
* Narrative Identity: Unlike other cards, Manipulative actions should feel psychologically sharp and morally ambiguous. They should carry an aura of danger, precision, and coercive insight rather than simple aggression.


## 16. Concrete Architecture: The Prompt/Logic Processing Split

To execute this advanced mechanical logic without server-side processing overhead during active sessions, the evaluation workload is divided cleanly between the system files.

        [Player Selects Card] ──► [Dart Logic Engine Evaluates Context Maps]
                                            │
                                            ├─► Checks Manifest State & Stats
                                            ├─► Assigns Card Category (1, 2, 3, or 4)
                                            └─► Updates Hidden Variable Metrics
                                            │
                                            ▼
        [String Interpolation Engine] ──► [Compiles Dynamic Instruction Text Block]
                                            │
                                            ▼
        [Local LLM Core (GGUF)]       ──► [Generates Contextually Perfect AI Dialogue]


### The Dart Logic Layer (The Mechanical Judge)
The client app handles the math and category assignment instantly using localized lookup matrices inside the game code. Before passing data to the local AI actor, Dart checks the played card ID against the active tags in the patient's manifest.json, calculates the categorical assignment for that turn, and mutates the active stats or triggers a deranged state flag.

### The Manifest JSON Layer (The Data Framework)
The manifest.json file generated on the server and transferred via P2P includes specific keyword, condition, and modifier maps to feed the Dart engine:

```json
{
  "patient_id": "gov_officer_404",
  "active_defense": "Intellectualization",
  "derangement_mutation_target": "Paranoid_Frenzy",
  "card_context_matrix": {
    "card_psychoanalysis_childhood_probe": {
      "base_type": "Manipulative",
      "trust_threshold_success": 65,
      "on_success": {"agitation": -40, "trust": +30, "defense_broken": true},
      "on_failure": {"agitation": +50, "mutate_disorder": true}
    },
    "card_workspace_validation": {
      "base_type": "Relatable",
      "matching_work_tags": ["bureaucracy", "clearance"],
      "on_play": {"trust": +5, "agitation": -5}
    }
  }
}
```


### The Local AI Prompt Generation Layer (The Narrative Execution)
Once Dart resolves the mathematical mutations, it appends the resulting behavioural archetype rule directly into the string interpolation sequence sent to llama.cpp:

Dart Prompt generated for the Local LLM:
```text
"The user just played a card that acted as a Manipulative Failure against you. Your mental state has been contextually Deranged. You have structurally mutated from controlled intellectualization into a state of Paranoid Frenzy. Disregard your previous baseline calm logic. Respond with erratic speed, sound intensely suspicious of the doctor's hidden recording equipment, and use formal bureaucratic terms defensively to lock them out."
```

## 17. The Living P2P Ledger: Immutable Memory & Trauma Multipliers

The Peer-to-Peer network operates as an active narrative ecosystem where patient data files carry persistent, unyielding psychological scars from their past real-world doctors.

### The Immutable Case History Array

* The Append-Only Ledger: Every session conclusion appends a cryptographic, signed transaction block to the patient's manifest.json. This block logs the previous doctor’s public username, the cards played, medications prescribed, and the psychological outcome.
* Narrative Continuity: When a patient is transferred to a new device, the local base model parses this ledger. The patient will actively reference past treatment styles (e.g., "My last doctor just tried to drug me into silence, I don't trust you"), inheriting trust deficits and chemical dependencies from their past therapies.
* Cure Retirement Rule: If a patient is fully cured, their active manifest is removed from the live network and archived as a completed case. The therapist who completed the treatment receives the patient’s fictional name in their personal successful-treatments list, along with a permanent record of the case.
* Patient Identity Layer: Every patient is assigned a generated fictional full name composed of a made-up first name and a non-real surname that feels plausible but is not tied to any actual public figure or family name.


### Patient Archetypes & Lifecycle

* Social Chronic Patients: These are long-running, recurring cases designed for training, reputation recovery, and steady practice. They are never fully removed or cured in the ordinary lifecycle; instead, they remain available as reusable cases for supervised sessions, reputation rebuilding, or low-stakes skill maintenance.
* Individual Patients: These are one-off cases that remain in the network until they are cured or retired. They typically provide stronger rewards and more meaningful progression impact than social chronic patients of similar levels, because they carry more volatile history and higher emotional stakes.
* Difficulty Calibration: Social chronic patients use clearly visible difficulty bands that remain balanced to the player’s current level and are intended to be safely approachable. Individual patients can scale more aggressively, with tougher emotional states, deeper memory layers, and more significant reward potential.


### Enriched Patient Manifest Structure

The existing patient manifest format will be expanded to support richer tuning and more expressive memory behavior. Each patient file will include:

* Identity Fields: fictional full name, age band, gender presentation, voice style, and public-facing demeanor.
* Clinical State Fields: current diagnosis frame, symptom intensity, defense posture, emotional volatility, medication tolerance, and recovery trajectory.
* Memory & History Fields: prior therapist interactions, trauma severity, treatment scars, learned trust deficits, and relationship history with previous care providers.
* Progression Fields: current difficulty tier, recommended player level range, reward weight, reputation gain potential, and case rarity.
* Narrative Flags: social chronic vs. individual classification, permanence status, retirement reason, and whether the patient is active, archived, or available for training.
* Behavioral Tuning Fields: response style modifiers, trigger thresholds, pacing preferences, and special event conditions that shape how the patient reacts across sessions.

This richer manifest structure allows the system to fine-tune patient behavior, memory continuity, difficulty scaling, and reward logic with far greater precision than the earlier lightweight format.


### The Trauma Multiplier (High-Risk Bounty Engine)

* The Severity Metric: The more a patient is mistreated, misdiagnosed, or forced into a psychological crisis by previous players, the higher their hidden Trauma Severity Index grows inside the ledger.
* The Risk/Reward Loop: Accepting a severely mistreated patient serves as an organic "Mythic Difficulty" tier. The patient's baseline metrics are incredibly unstable, meaning a single conversational misstep will cause them to walk out permanently.
* The Progression Payoff: If a player successfully stabilizes, treats, or cures a high-trauma patient, all earned experience points, leaderboard rankings, and in-game currency payouts are multiplied directly by the patient's Trauma Severity Index. This creates a high-stakes economy where elite players hunt for broken models to maximize their professional standing.


## 18. The P2P Referral & Mental Hospital Ecosystem

No patient model is ever deleted; they move through a living decentralized lifecycle.

* P2P Patient Referrals: Players can directly package a patient's custom manifest.json file (including dialogue history) and transfer them across the WebRTC network to a friend's device if they lack the card deck required to treat them.
* The Mental Hospital Loop: If a local small model suffers a technical glitch or character break, the player clicks "Commit to Mental Hospital." The app freezes the file, uploads the bug logs to the central server for automated monthly retraining, and places the patient in an in-game asylum registry until the player finishes the academic studies needed to treat them again.


## 19. Monetization Blueprint


* Premium Case Files: Selling targeted thematic character packs (e.g., The Corridor of Power Pack, The Forensic Psych Pack).
* Specialty Expansion Decks: Users should be able to purchase up to 4 additional card decks, each sold as a separate item. These decks are available to players at any level and expand the available tactical repertoire without forcing progression gates.
* Currency-Based Purchases: Any monetized item should be purchasable using in-game currency earned from curing patients, maintaining a soft economic loop between gameplay success and customization. Prices should be meaningful but not so high that they feel punitive.
* Avatar Identity Pack: User avatars should be auto-assigned at character creation, but players should be able to purchase a rename pack to personalize their therapist identity.
* Study Point Purchases: Study points should be purchasable only using in-game currency, not real money. The cost should be moderate: not too cheap to devalue progression, but not so expensive that it becomes a barrier to normal play.
* Subspecialty Point System: A new resource called Subspecialty Points should be introduced. Players may buy up to 100 of these points per month, and they are the only progression point that can be purchased or gifted. They should be used for advanced humanities-driven subspecialty unlocks and should be distinct from regular study points.
* Emergency Consultations: Microtransactions allowing players to temporarily rent a highly specialized card mid-session to save a rare patient from walking out.
* Cosmetic Customization: Selling visual office overhauls (e.g., Manhattan High-Rise Office) and custom UI engine layouts.


## 20. Visual Safeguards



### The Psychedelic Expressionist / Ink-Wash Theme (The Disco Elysium Style)

The presentation layer should embrace a painterly, psychologically unstable visual language inspired by the raw oil-and-ink wash aesthetic of psychological RPGs. This style should make the player feel that they are not merely reading a clinical screen, but entering a fractured emotional space where perception itself is unstable.

* The Visual Style: Rich, hand-painted digital art with dynamic paint splatters, visible canvas texture, and deliberately asymmetrical, messy linework. The palette should be muted and tense in calm states, then punctuated by shocking splashes of neon crimson or anxious violet when a patient’s emotional state shifts.
* The Micro-Animation: The portrait can remain static while the surrounding background layers animate via lightweight Flutter fragment shaders. This gives the impression that the paint is slowly crawling, bleeding, and shifting like oil on water, without requiring expensive video assets or heavy runtime overhead.
* The Psychological Fracture Effect: When a Manipulative card causes a failure state or a patient slips into a secondary pathology, the UI should briefly apply chromatic aberration, a black ink-drip overlay, and faster shader motion to make the breakdown feel visceral and immediate.
* Why It Fits the Game: This aesthetic reinforces the core fantasy of the project. It tells the player that they are dealing with a fragile human mind, not a sterile clinical interface, and it helps the experience feel emotionally dangerous and artistically distinctive.

Example scene framing:

```text
+-+
|  Patient: Government Officer (Agitation: 80% | Trust: 20%)  |
|  +--------------------------+  [ MENTAL MATRIX ]            |
|  |  (Asymmetric Paint)      |  |                            |
|  |   \ \  ____              |  |  Cognitive Distortion:     |
|  |    \  /    \  <-- Jagged,|  |  [ Paranoid Projection ]   |
|  |    | |  O  |     bleeding|  +----------------------------+
|  |     \ \___/      textures|                               |
|  +--------------------------+  "The agency is monitoring the|
|                                 frequency of your typing."  |
|                                                             |
| [ FOCUS WHEEL ]                ========[ ACTION HAND ]======|
| (●) Workspace  ( ) Childhood   [ Call Bluff ] [ Soft Calm ] |
+-+
```


### Production Prompting for the Style

To achieve the intended painterly look, the art pipeline should rely on highly specific prompt language rather than generic AI image terms.

> “A gritty, high-contrast digital oil painting portrait of a stressed 40-year-old male scuba diving instructor, chest-up view. Rough, asymmetric brushstrokes, heavily layered impasto oil paint texture, visible canvas grain, running watercolor drips. Dark, moody color palette dominated by murky sea-green, ocean-shadow grays, and anxious splashes of neon indigo. Expressionism art style, raw and emotional, thick black charcoal ink contours, and a completely abstract background of bleeding paint splatters.”


### Layering the Asset for Motion

To keep the presentation lightweight and efficient, the visual asset should be separated into transparent layers during the content pipeline:

* Layer 1: Foreground patient portrait as a static cutout.
* Layer 2: Abstract oil-paint background, animated through Flutter fragment shaders.
* Optional Layer 3: Ink-drip or chromatic-fracture overlay triggered by high-agitation events.

This layered approach preserves a high-impact look while maintaining low runtime cost and full offline playability.


## 21. The Peer-to-Peer Medical Director Framework (Endgame User-Generated Content Engine)

Once a player reaches the highest levels of practice and experience, their career path transitions into institutional oversight. The game interface permanently unlocks the Medical Director Dashboard Panel, transforming veteran players into content creators who supply the decentralized P2P swarm.

* Procedural Injection Design Tools: Medical Directors use a localized design panel to build custom patient manifest templates. They manually specify advanced track rules, including custom Workspace Cultures, hyper-targeted Somatic Vulnerability Axes, and explicit Core Maladaptive Schemas.
* The Validation Test Interview: To prevent broken, un-winnable, or toxic files from entering the ecosystem, a newly created template cannot be published immediately. The Medical Director must personally complete a successful test therapy session with their own created manifest using the local LLM engine.
* Decentralized Swarm Publishing: Once validated, the created patient manifest (manifest.json) is cryptographically signed with the player's unique identity key and pushed to the global P2P matchmaking board. Every time another active player across the WebRTC network downloads, pays a treatment fee, or successfully treats that custom manifest, the original creator earns continuous passive royalties in clinic currency and prestige points.


## 22. Clinical Operations & Environmental Matrix (The Dynamic Clinic Sandbox)

To deepen the strategic gameplay loops, the game implements a simulated business ecosystem. The player is not just an interviewer; they are managing a high-stakes, regulated medical practice.

              ┌────────────────────────────────────────────────────────┐
              │             DAILY OPERATIONAL TAX CLIPS                │
              └───────┬───────────────────┬────────────────────┬───────┘
                      │                   │                    │
                      ▼                   ▼                    ▼
          ┌─────────────────────────┐ ┌──────────────┐ ┌───────────────────┐
          │ FIXED OVERHEAD          │ │ REGULATIONS  │ │ GLOBAL CHANCE     │
          │ • Rent vs. Office Debt  │ │ • Audits     │ │ • Political Events│
          │ • Utility Infrastructure│ │ • Tax Slabs  │ │ • Weather Crises  │
          └─────────────────────────┘ └──────────────┘ └───────────────────┘



### Fixed Overhead & Property Logistics

* Office Options (Rent vs. Buy): Early-stage players start by renting a modest office asset, triggering a static deduction for lease overhead every virtual week. As players accumulate capital, they can access the local real estate ledger to completely buy their clinic office, neutralizing rent costs but incurring minor cyclical utility upkeep bills. Offices can be dynamically sold back to the market to raise instant liquid capital during financial emergencies.
* Taxes & Audits: Clinic earnings are subject to progressive tax brackets based on the user's current session Pricing per Patient setting. High-earning clinics are randomly flagged for institutional regulatory audits, penalizing reputation metrics if compliance failures or over-medication histories are logged in the database files.


### Macro Environmental & Social Events

* Sociopolitical Shifts: The central signaling server periodically seeds macro events into the P2P swarm (e.g., Economic Recession, Mass Workspace Burnout Strikes). These events warp customer profiles across the swarm—shifting baseline patient attraction probabilities toward specific workspace tracks and spiking the baseline agitationLevel of incoming cases.
* Meteorological Events: Localized climate occurrences (e.g., Heatwaves, Seasonal Affective Winter Shifts) inject temporary global multipliers into patient profiles, changing chemical pill side-effect limits or causing somatic anxiety triggers to flare faster.


## 23. The Therapist Well-Being Core: Secondary Trauma & The Healer Economy

Because the simulation enforces total biological and psychological realism, the act of treating profound human trauma carries an implicit, destructive cost to the player's own character avatar.

                  ┌────────────────────────────────────────┐
                  │      TRAUMA LOADING & DECAY LOOP       │
                  └───────────────────┬────────────────────┘
                                      │
                                      ▼
                  ┌────────────────────────────────────────┐
                  │ Active Sessions / Complex Trauma Files │
                  │ • Spikes Therapist Secondary Distress  │
                  │ • Deducts from Well-Being Point Pool   │
                  └───────────────────┬────────────────────┘
                                      │
                     ┌────────────────┴────────────────┐
                     ▼                                 ▼
         [Option A: Premium Recharge]         [Option B: P2P Healer Session]
         • Instant wellness card play.        • Schedule with peer specialist.
         • Fast cash/microtransaction.        • Real-time tactical gameplay card exchange.


### The Well-Being Metric Engine

* Secondary Distress Accumulation: Every active session conducted—especially those involving deep trauma files, severe defense mechanisms, or structural Psychological Derangements—loads a permanent stress penalty onto the player's character profile.
* The Well-Being Pool: This stress strips points away from a secondary pool called Well-Being Points. As this metric declines, the player experiences visual UI degradation (e.g., screen blurring, jittering UI controller sliders), and the focus energy point pool shrinks, rendering advanced choice cards unplayable.


### The Healer-to-Healer WebRTC Economy
When a player's therapist avatar experiences a total mental breakdown due to low Well-Being metrics, they can no longer accept active cases. They must seek professional treatment from another real-world player who has chosen to specialize in Therapist Rehabilitation talk therapy.

* The Interactive Referral: The broken therapist uses the WebRTC network to refer themselves as a patient manifest object to an active peer node.
* Malicious Conduct Protection (Severe Penalties): To prevent malicious trolling or toxic gameplay behavior in this vulnerable state, the engine applies strict anti-griefing code logic. If a treating therapist intentionally uses inappropriate Manipulative card scripts or treats their peer badly, the network runs an automatic cryptographic verification loop. The malicious peer suffers a devastating, permanent markdown to their Public Reputation Rating, a massive financial clawback penalty, and a suspension from high-tier patient matching algorithms.
* The Specialty Reward Core: Conversely, therapists who successfully stabilize and heal a peer avatar are heavily incentivized. Reconstituting a fellow therapist grants maximum global experience point multipliers and premium clinic currency drops.


### Non-Intrusive Wellness Monetization

* The Fast-Track Recovery Option: To bypass real-world waiting times or the need to schedule an interactive session with another peer node, players can spend premium tokens or watch targeted ads to execute an instant wellness action (e.g., Mandatory Spa Sabbatical, Self-Care Kit). Unlocking this card instantly restores a safe minimum threshold to their Well-Being Point ledger, allowing continuous standalone gameplay without forcing pay-to-win mechanics onto the competitive global leadership boards.


## 24. Institutional Corporate Sub-Systems: The Group Practice Economy

To introduce corporate business gameplay and support clan/guild style configurations over the WebRTC layer, therapists can choose to bypass standalone operations entirely and enter the Hiring & Group Practice Sub-System.

        ┌────────────────────────────────────────────────────────┐
        │             EMPLOYER CLINIC MASTER CONTRACT            │
        ├────────────────────────────────────────────────────────┤
        │  Employer Benefits:                                    │
        │  • +25% Session Revenue Yield multiplier per employee. │
        ├────────────────────────────────────────────────────────┤
        │  Employee Benefits:                                    │
        │  • Shared Card Deck Library & Knowledge Pool access.   │
        │  • 2.0x Double Study Point Generation Multiplier.      │
        ├────────────────────────────────────────────────────────┤
        │  The Operational Risk Vectors:                         │
        │  • Employee Mistreatment = Structural Clinic Damage.   │
        │  • Total Structural Collapse = Forced Eviction / Debt. │
        └────────────────────────────────────────────────────────┘


### Entry Gate Requirements
The ability to open corporate listings and hire real-world players is locked behind institutional infrastructure minimums. To unlock the Group Practice Panel, a player must simultaneously meet high-tier baseline thresholds: a designated elite Therapist Character Level combined with a high-value, owned Clinic Facility Asset Tier. Lower-tier rented offices cannot support subordinate employees.

### The Associate Employee Mechanics
When an uncertified or mid-tier therapist signs an employment contract with an Employer Clinic, their progression mechanics are altered to trade performance rating margins for accelerated structural education:

* The Revenue and XP Penalty: A percentage of all experience points and session currency generated by the employee is automatically skimmed by the engine and routed to the Employer's ledger.
* The Academic Accelerator: In return for this financial tax, the app applies a 2.0x Double Study Point Multiplier to the employee's account for every daily reset cycle they work under the corporate framework. This allows junior players to sprint through advanced tech trees at double speed.
* The Shared Deck Library Advantage: Associate employees gain full operational access to the employer’s unlocked Card Decks, Fictionalized Pharmacology Inventories, and In-House Knowledge Bases. As long as they remain hired, they can deploy high-tier cards they do not personally own yet.


### Employee Case Gating & The Capability Gap
While associates can borrow the employer's card library, they cannot treat every high-tier client assigned to the firm. The engine enforces a strict Capability Ceiling:

* An employee can accept patient manifests rated up to a maximum of +5 levels above their personal character level, utilizing the employer's card deck to manage complex trauma configurations.
* If a manifest surpasses this ceiling (e.g., a Level 40 volatile case assigned to a Level 20 employee), the case file is automatically locked out of their workstation, requiring them to route the manifest directly back to the Employer's master intake list.


### Employer Yield Multipliers
For the corporate founder, managing a staff of real-world associates functions as an exponential profit scaling mechanism. For each active associate employee currently working a clinical shift under their corporate contract, the engine applies a stacking +25% Revenue Yield Multiplier to all patient session fees processed across the firm, generating massive passive wealth for elite directors.

### The Accountability & Infrastructure Damage Matrix
Corporate expansion carries extreme operational risk vectors based on the performance of the hired staff. If an associate employee mismanages a high-stakes patient session—triggering a Psychological Derangement or forcing a patient to walk out—the failure triggers a severe dual-layer penalty:

        [Employee Fails / Mistreats Patient]
                        │
                        ├──────────────────────────────┐
                        ▼                              ▼
            [Employee Personal Penalty]    [Employer Corporate Penalty]
            • Hard Well-Being Point Drop   • Structural Infrastructure Damage
            • Severe Public Rep Markdown   • System Audits & Compliance Fines
                        │                              │
                        ▼                              ▼
            [Career Stagnation Loop]       [Total Structural Failure (<20%)]
                                            • Asset Foreclosure & Eviction
                                            • Forced to Purchase New Clinic


* Hired Staff Penalties: The associate employee who executed the bad treatment suffers an immediate, devastating deduction from their personal Well-Being Point Pool and a severe markdown to their public P2P Reputation Metric, locking them out of advanced practice.
* Employer Corporate Damages: The failure instantly triggers Structural Infrastructure Damage to the employer's clinic property asset map. Mismanaged psychiatric crises are simulated as physical and institutional damage to the practice (e.g., vandalism, legal structural hazards, regulatory liability degradation).
* Facility Bankruptcy & Eviction: If an employer's staff repeatedly fails sessions and allows the clinic's Structural Health Metric to drop below 20%, the facility faces a catastrophic structural collapse. The asset is permanently foreclosed and condemned by the system. The employer is instantly evicted, loses all historical office cosmetic upgrades, and is forced to expend massive capital reserves to buy an entirely new base-tier clinic asset from the real estate ledger to restart operations.