# Psychosims

> Project Blueprint: Hybrid Social Simulation & Strategy Platform

## 1. Core Concept & Role-Driven Progression Architecture

Psychosims is a fictional, game-inspired social simulation and strategy platform built around psychology, clinical language, institutional culture, and interpersonal drama. It is not a real mental-health treatment platform, nor is it intended for professional clinical use. The experience is designed to feel like a simulation and a social game at the same time: players manage cases, build reputations, operate clinics, and participate in a wider networked world of peers and institutions.

The product is not organized around a single-track progression path. Instead, it is structured around multiple overlapping roles and systems: the player may operate as an individual clinician, a medical director, an employer clinic founder, a peer-healer, or a corporate operator. This role diversity is intentional and should be treated as a core part of the experience rather than a later expansion.

## 2. Technical Architecture & Stack

The architecture is intentionally hybrid. The project uses a lightweight server layer for identity, moderation, matchmaking, and control-plane functions, while the bulk of gameplay, content distribution, and peer interaction runs through a decentralized P2P network.

          ┌────────────────────────────────────────────────────────┐
          │                 FLUTTER FRONTEND APP                   │
          └───────┬───────────────────┬────────────────────┬───────┘
                  │                   │                    │
          (HTTPS / WebSocket)  (WebRTC Data)       (FFI / C++)
                  │                   │                    │
                  ▼                   ▼                    ▼
      ┌───────────────────────┐ ┌──────────────┐ ┌────────────────────┐
      │  Minimal Control Plane│ │  P2P Swarm   │ │  Local Inference   │
      │ • Identity & Auth    │ │ • Content    │ │ • llama.cpp (GGUF) │
      │ • Matchmaking        │ │   Distribution│ │ • Session Prompt   │
      │ • Moderation & Policy│ │ • Peer Presence│ │   Assembly         │
      └───────────────────────┘ └──────────────┘ └────────────────────┘

* Frontend UI: Built with Flutter for cross-platform deployment across iOS, Android, Windows, Mac, and Linux.
* Local AI Execution: Uses llama.cpp via Flutter FFI for locally running small inference models on user hardware.
* Hybrid P2P Network: Uses WebRTC-based peer delivery for content, presence, and direct player-to-player interaction.
* Minimal Control Plane: The server layer remains small, inexpensive, and focused on the minimum necessary responsibilities: identity management, moderation, matchmaking metadata, and policy enforcement.

### Clear Boundary Between Decentralized and Administrative Control

The system should be explicit about what is decentralized and what is administratively controlled.

* Decentralized Layers: Player presence, content sharing, peer referrals, case handoff, and much of the social graph should operate through the P2P network.
* Administrative Layers: User account identity, policy enforcement, moderation actions, and restricted control functions remain on the server side.
* Progressive Distribution: User account information should eventually be spread across the P2P network as the active user base grows, and it should be removed from the central database entirely once a safe threshold is reached and the network can reliably distribute it.
* Purpose of the Boundary: This keeps the project hybrid rather than purely centralized, while still preserving a minimal and manageable control surface for safety, integrity, and moderation.

### Implementation Priority: Minimal Cross-Platform Runtime First

Before any large-scale networking, content distribution, or advanced economy systems are built, the first engineering milestone should be a minimal proof-of-concept that proves the core loop works inside Flutter on both an Android emulator and a Linux Ubuntu machine.

* Minimal Model First: The initial implementation should target the smallest practical local model that can run through llama.cpp via Flutter FFI and produce believable, structured session responses.
* Minimal Content Object First: The first playable content object should be a compact patient case definition with high-level fields for identity, tone, pressure state, and available interaction patterns.
* End-to-End Loop: The first build should connect the following path in a single flow: Flutter UI → load a case definition → compose a prompt from simulation state → run local inference → render the resulting dialogue back into the session view.
* Cross-Platform Validation: The same build path must be tested on both Android emulator and Linux desktop so the team can confirm asset loading, runtime execution, and UI behavior across environments.
* Success Criteria: If the minimal model and case definition can produce a coherent session result on both targets, the team has proven the foundational architecture. Only after that should the project expand into richer content, deeper social systems, and larger institutional gameplay.

This milestone should be treated as the true first implementation phase, because it validates the project's core promise: that a lightweight local model, a compact case definition, and a Flutter-based game loop can run effectively on real devices and desktop environments.

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
* Routing Intelligence: The distribution system should consider reputation, study-field coverage, clinic pricing, and current operational pressure so that patients are matched to appropriate therapists rather than randomly assigned.

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


## 4. Role Diversity and Institution Layers

The game is not centered on a single professional identity. Instead, it supports a layered set of roles that reflect the social and institutional nature of the experience.

* Clinical Practice Role: Players may begin as individual practitioners handling cases, managing dialogue, and building a reputation through successful sessions.
* Medical Director Role: Advanced players may oversee broader case flow, institutional standards, and high-level decisions that shape the clinic experience.
* Employer Clinic Role: Players can build or join employer clinics, coordinate staff, and manage a larger operational structure.
* Peer-Healer Role: Players may participate in peer-based support and recovery systems that reinforce the social platform side of the experience.
* Corporate Sub-System Role: At higher levels, players can engage with group-practice mechanics, institutional growth, and organizational management.

* Fictionalized Pharmacology: To fully neutralize legal risks and App Store rejection, the game utilizes an immersive index of made-up, sci-fi/noir sounding medicine names (e.g., Zenithium for acute anxiety, Lucidex for manic detachment).
* The Treatment Tightrope: Prescribing medicine can temporarily alter case pressure, symptom intensity, and dialogue behavior, forcing the player to adapt their strategy.


### App Store & Legal Safety
* Position the product clearly as a fictional, interactive simulation—not real therapy or medical treatment.
* Avoid claims of diagnosis, treatment, or mental health cure; use game-focused language like “simulation,” “scenario,” or “narrative experience.”
* Use fictional disorders and fictional pharmacology, not real clinical diagnoses or medications.
* Include explicit disclaimers: “This game is a fictional simulation and not a substitute for professional mental health care.”
* Do not collect or store real health data. Treat player profiles as game state only, and keep PII separate from gameplay data.
* Keep store metadata and app text focused on entertainment and strategy, not clinical guidance.


## 5. Career Evolution, Study Systems, and Social Progression

The game experience organically transitions from an introductory simulation into a larger social and institutional platform through a layered progression system. Players are not limited to a single career identity; they can evolve into clinicians, medical directors, employer-clinic founders, peer-healers, and corporate operators.

                      [CAREER EVOLUTION PIPELINE]
                                   │
                                   ▼
          [Level 1-10: Foundational Practice]
          • Players begin as early-career practitioners handling meaningful but manageable cases.
          • Early sessions are designed to teach the basics of case reading, pacing, and treatment planning without feeling like a dry tutorial.
          • Guided interfaces, structured feedback, and accessible case design support fast onboarding.
                                   │
                                   ▼
          [Level 11-30: Institutional Expansion]
          • Players gain access to more complex cases, richer dialogue systems, and broader strategic options.
          • New specializations and institutional roles become available.
          • The player can begin building a clinic identity, hiring support, or participating in peer-based healing networks.
                                   │
                                   ▼
          [Advanced Career Tier / Endgame Progression]
          • Players can operate as Medical Directors, manage employer clinics, and influence the wider social ecosystem.
          • Complex, volatile cases and institution-level systems dominate the late game.
          • The highest tier expands as more fields, systems, and social roles are introduced.

### Progression Resources

* Study Points: Earned through play, daily activity, and milestone completion. They are spent to train core fields and unlock new capabilities.
* Subspeciality Points: Earned through higher-level play and specialized achievements. They are used to train advanced, cross-disciplinary fields that expand tactical identity and narrative influence.
* Experience Points: Increase as the player spends time in the game, completes sessions, achieves meaningful results, and reaches milestones.
* Reputation Points: Dynamic and responsive. They rise or fall based on outcomes, case handling, institutional behavior, and public trust.

### Field Training Logic

* The training tree should use a balanced cost structure where foundational fields require modest investment and advanced fields require more substantial commitment.
* Core fields should reinforce the standard clinical simulation loop, while subspecialities should support more specialized, institution-aware, and socially expressive playstyles.
* Players should be able to build distinct identities by choosing how to allocate study and subspeciality points.

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


## 6. Patient Attraction Vector: The Core Evaluation Framework

To attract increasingly complex, prestigious, or rare patient cases from the network, a player's clinic profile is evaluated dynamically across a compact set of public metrics. These metrics determine the attraction weight for incoming P2P case requests.

          ┌────────────────────────────────────────────────────────┐
          │               CLINIC ATTRACTION ENGINE                 │
          └───────┬───────────────────┬────────────────────┬───────┘
                  │                   │                    │
                  ▼                   ▼                    ▼
          ┌────────────────────────┐ ┌──────────────┐ ┌────────────────────┐
          │    1. REPUTATION       │ │ 2. PRICING   │ │ 3. STUDY FIELDS    │
          │ • Lifetime Client Count│ │ • Session Fee│ │ • Total Unlocked   │
          │ • Success / Cure Rate  │ │   Set by User│ │   Specializations  │
          └────────────────────────┘ └──────────────┘ └────────────────────┘

### 1. Reputation (Practice Health)

* Growth Triggers: Reputation rises or falls based on case outcomes, patient trust, institutional behavior, and public perception.
* Gameplay Impact: Higher reputation unlocks more prestigious cases and stronger network access. Repeated failures or poor conduct reduce the clinic's reach.

### 2. Pricing per Patient (The Financial Position)

* User-Controlled Slider: Players can manually set their session price rate in-game.
* The Economic Balancing Act: High prices increase profit margins but reduce the pool of casual or lower-budget cases. Competitive prices increase volume and can attract a different class of patient.

### 3. Number of Study Fields (Academic Authority)

* The Credential Count: Measures the total sum of completed academic fields and certifications unlocked through the training tree.
* Gameplay Impact: More advanced, institution-level cases require stronger field coverage. Players with limited training are filtered out of more demanding matches.

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

No hidden therapist well-being stat is used. Instead, the game will rely on visible operational pressure, case load, recovery windows, and clinic capacity as play-facing states.

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
* Profile and Clinic State Injection: The sandbox should permit preloading specific player states, including unlocked study fields, clinic attributes, reputation values, pricing settings, and recovery status, so the system can simulate different progression conditions quickly.
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
* The Dialogue Layer: The local LLM does not decide gameplay outcomes. It receives a compact, structured prompt from the simulation core and generates conversational text that reflects the current state of the scene. Its job is to voice emotion, pacing, and personality, not to invent new rules or bypass the simulation.
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

To execute this advanced mechanical logic without server-side processing overhead during active sessions, the evaluation workload is divided cleanly between the simulation core and the dialogue layer.

        [Player Selects Card] ──► [Simulation Core Evaluates Context]
                                            │
                                            ├─► Applies deterministic rules
                                            ├─► Updates state and outcome flags
                                            └─► Produces approved narrative context
                                            │
                                            ▼
        [Prompt Assembly Layer] ──► [Local LLM Core (GGUF)]
                                            │
                                            ▼
        [Generates Dialogue and Tone Only]

### The Simulation Core Layer
The client app handles deterministic outcome resolution using localized game logic. Before passing data to the local AI actor, the simulation core evaluates the current state, the selected action, and any relevant context rules. It decides what the outcome should be, but it does not delegate gameplay authority to the model.

### The Patient Manifest Layer
The patient manifest will be defined later through a structured schema designed for gameplay clarity and content iteration. At this stage, the important requirement is that the manifest supports high-level case identity, pressure states, narrative context, and compatibility rules without locking the project into a premature technical format.

### The Local AI Prompt Generation Layer
Once the simulation core resolves the turn, it assembles a compact prompt containing only approved narrative context, tone guidance, and dialogue constraints. The local model is responsible for generating dialogue and voice, not for changing rules, outcomes, or hidden state.

## 17. The Living P2P Ledger: Immutable Memory & Trauma Multipliers

The Peer-to-Peer network operates as an active narrative ecosystem where patient data files carry persistent, unyielding psychological scars from their past real-world doctors.

### The Immutable Case History Array

* The Append-Only Ledger: Every session conclusion appends a cryptographic, signed transaction block to the patient's case history. This block logs the previous doctor’s public username, the cards played, medications prescribed, and the psychological outcome.
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

* P2P Patient Referrals: Players can directly package a patient's custom case manifest (including dialogue history) and transfer it across the WebRTC network to a friend's device if they lack the card deck required to treat them.
* The Mental Hospital Loop: If a local small model suffers a technical glitch or character break, the player clicks "Commit to Mental Hospital." The app freezes the file, uploads the bug logs to the central server for automated monthly retraining, and places the patient in an in-game asylum registry until the player finishes the academic studies needed to treat them again.


## 19. Monetization Blueprint

The monetization model should support the game’s identity as a long-term clinical simulation while preserving a fair, non-punitive progression loop. It should be designed so that purchases feel like optional convenience, customization, or strategic acceleration rather than a requirement for meaningful play.

### Core Monetization Principles

* Non-Pay-to-Win Structure: Premium content should never replace core progression, core card access, or essential treatment outcomes. It should enhance expression, convenience, and personalization rather than gate fundamental gameplay.
* Currency Loop Integrity: In-game currency should remain the main economic driver for optional progression purchases. The player should feel that curing patients, managing a clinic, and surviving difficult cases create value that can be spent meaningfully.
* Progression Respect: Any paid shortcut should be limited in impact so that it never invalidates the player’s normal growth through study, casework, and clinic management.
* Cosmetic and Strategic Separation: Cosmetic items should be clearly cosmetic, while strategic convenience items should stay bounded so they do not overpower competitive or narrative progression.

### Core Revenue Streams

* Premium Case Files: Sell targeted thematic patient packs such as The Corridor of Power Pack or The Forensic Psych Pack. These should provide aesthetic variety, new narrative flavor, and occasionally new challenge profiles without replacing the standard case pool.
* Specialty Expansion Decks: Allow players to purchase up to 4 additional card decks, each sold as a separate item. These decks should expand tactical options and create new playstyles without forcing the player to pay to participate in core gameplay.
* Currency-Based Purchases: Any monetized item should be purchasable using in-game currency earned from curing patients, maintaining a soft loop between gameplay success and customization. Prices should be meaningful but not so high that they feel punitive.
* Avatar Identity Pack: User avatars should be auto-assigned at character creation, but players should be able to purchase rename packs, portrait variants, and identity customization options to personalize their therapist identity.
* Study Point Purchases: Study points should be purchasable only using in-game currency, not real money. Their cost should be moderate so they feel like earned utility rather than a shortcut to total domination.
* Subspecialty Point System: Introduce a separate progression resource called Subspecialty Points. Players should be able to earn a small amount through play and optionally purchase a capped amount over time. These points should be used for advanced humanities-driven subspecialty unlocks and should remain distinct from regular study points.
* Emergency Consultations: Offer limited-use, mid-session consultations that let the player temporarily rent a highly specialized card or tactical support to recover a difficult patient from walking out. These should feel like a clutch tool, not a standard replacement for good play.
* Cosmetic Customization: Sell visual office overhauls, clinic themes, UI skins, and environmental styling options that reinforce player identity and long-term engagement.

### Retention-Oriented Monetization

* Daily and Weekly Offers: Offer rotating bundles tied to current case themes, new study fields, or seasonal clinical events. These should create a reason to return without being required for progress.
* Time-Limited Cosmetic Drops: Introduce exclusive visual themes or office makeovers that appear for a limited window, encouraging return visits and reinforcing the feeling of an evolving clinic.
* Premium Practice Modes: Add optional challenge or sandbox access that is unlocked through premium progression or currency-based purchase for players who want deeper replayability and experimentation.
* Legacy Unlocks: Let players purchase permanent content unlocks that preserve their achievements in a way that feels rewarding rather than transactional.

### Economic Balance Constraints

* Soft Cap on Premium Advantage: Paid items should never provide a massive edge in cure rate, case access, or patient attraction beyond a narrowly bounded threshold.
* Fairness Guardrails: High-impact purchases should be carefully priced so they remain optional and do not invalidate the value of good play, discipline, and study.
* Optional Recovery Tools: Any premium recovery or rescue mechanic should be framed as emergency assistance, not as a substitute for the core treatment loop.

### Monetization Tone

The tone should feel like a mature clinic economy rather than a shallow loot shop. Players should feel that they are investing in their practice, identity, and long-term clinic brand, not just buying random power-ups.


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
* Decentralized Swarm Publishing: Once validated, the created patient case manifest is cryptographically signed with the player's unique identity key and pushed to the global P2P matchmaking board. Every time another active player across the WebRTC network downloads, pays a treatment fee, or successfully treats that custom manifest, the original creator earns continuous passive royalties in clinic currency and prestige points.


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


## 23. Clinical Recovery & Resilience Systems

The game should not rely on a hidden therapist well-being stat. Instead, it should use visible systems such as operational pressure, recovery windows, and clinic capacity to represent the cost of sustained high-stress work.

                  ┌────────────────────────────────────────┐
                  │      RECOVERY & PRESSURE LOOP         │
                  └───────────────────┬────────────────────┘
                                      │
                                      ▼
                  ┌────────────────────────────────────────┐
                  │ Active Sessions / Complex Trauma Files │
                  │ • Increase operational pressure        │
                  │ • Trigger recovery windows             │
                  └───────────────────┬────────────────────┘
                                      │
                     ┌────────────────┴────────────────┐
                     ▼                                 ▼
         [Option A: Recovery Break]       [Option B: P2P Healer Session]
         • Rest and stabilize clinic.    • Coordinate with peer specialist.
         • Rebuild capacity.            • Exchange tactical support.

### The Recovery Model

* Pressure Accumulation: Every active session involving difficult cases increases operational pressure and can reduce the clinic's effective throughput.
* Visible Recovery States: Recovery is represented through clear UI states, cooldowns, and capacity limits rather than a hidden internal health value.
* Peer Recovery Mechanics: Players may use the P2P network to coordinate peer-healer sessions, share support, or recover from severe case pressure.

### The Healer-to-Healer WebRTC Economy
When a clinic is overloaded, a player can choose to recover through a peer-based support interaction rather than forcing the system to continue under stress.

* The Interactive Referral: The player uses the WebRTC network to coordinate a support session with another active peer node.
* Conduct Protection: If a player intentionally misuses the recovery system or harms another participant, the network can apply penalties to reputation, access, and institutional trust.
* The Specialty Reward Core: Successful recovery and support interactions can provide reputation gains, institution affinity, and access to more demanding cases.

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
            • Hard Reputation Shock        • Structural Infrastructure Damage
            • Severe Public Rep Markdown   • System Audits & Compliance Fines
                        │                              │
                        ▼                              ▼
            [Career Stagnation Loop]       [Total Structural Failure (<20%)]
                                            • Asset Foreclosure & Eviction
                                            • Forced to Purchase New Clinic


* Hired Staff Penalties: The associate employee who executed the bad treatment suffers an immediate, severe markdown to their public P2P Reputation Metric and a meaningful loss of institutional access, locking them out of advanced practice.
* Employer Corporate Damages: The failure instantly triggers Structural Infrastructure Damage to the employer's clinic property asset map. Mismanaged psychiatric crises are simulated as physical and institutional damage to the practice (e.g., vandalism, legal structural hazards, regulatory liability degradation).
* Facility Bankruptcy & Eviction: If an employer's staff repeatedly fails sessions and allows the clinic's Structural Health Metric to drop below 20%, the facility faces a catastrophic structural collapse. The asset is permanently foreclosed and condemned by the system. The employer is instantly evicted, loses all historical office cosmetic upgrades, and is forced to expend massive capital reserves to buy an entirely new base-tier clinic asset from the real estate ledger to restart operations.