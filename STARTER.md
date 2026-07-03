## Project Blueprint: Decentralized AI Psychiatric Simulator

## 1. Core Concept & Single-Track Progression Architecture
The game is a choice-driven, strategic "psychological detective" simulator where players diagnose and treat patients over daily sessions.
Instead of separating the product into distinct commercial and institutional applications, the game deploys a Unified Single-Track System. Every player begins their career as an entry-level counselor dealing with straightforward behavioral anomalies. As the player invests time, logs successful clinical outcomes, and expands their academic credentials, the entire game engine—including the UI, the depth of the AI simulation, and the grading complexity—organically evolves into a rigorous, professional-tier medical simulator.
------------------------------
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

------------------------------
## 3. Server-Side Patient Generation & Distribution Frame
To maintain high-quality simulation, patient models are created, verified, and distributed through a trusted server framework.
### Automated Generation & Training Pipeline (Server-Side)

* The Content Engine: The central server runs an automated generation engine that creates unique patient narratives by procedurally fusing nine independent clinical and biographical data tracks.
* Model Fine-Tuning: The server converts these fused blueprints into synthetic clinical transcripts and utilizes high-efficiency LoRA scripts (via Unsloth/Axolotl) to fine-tune compact base open-source models.
* patient manifest Seeding: Once a narrative is procedurally generated and verified for consistency on the server, it is compiled into a lightweight profile package and seeded into the P2P swarm.

### Player Distribution Framework

* Free-to-Play Mechanics (System Assigned): Standard players do not choose their cases. The client app pings the signaling server to request a randomized patient seed matching their exact profile tier. The asset is then dynamically fetched directly from nearby peer nodes in the P2P swarm.
* Premium Catalog Access (On-Demand Selection): Players can purchase access to the global medical registry archive. This allows them to manually search, filter, and bypass random generation to select specific clinical profiles, career workspaces, or complex pathologies for dedicated study and practice.

------------------------------
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

------------------------------
## 5. Career Evolution & Daily Study Point Economy
The game experience organically transitions from an introductory psychological simulation into a clinical simulator via the interlocking mechanics of experience metrics and academic expansion.

                      [CAREER EVOLUTION PIPELINE]
                                   │
                                   ▼
          [Level 1-10: Introductory Clinical Simulation / Basic Tech Tree]
          • Straightforward workplace burnout cases.
          • High UI assists, basic card decks.
                                   │
                                   ▼
          [Level 11-30: Intermediate Clinical Practice]
          • Nested defense mechanisms and somatic symptoms unlock.
          • Introduction of fictional psychopharmacology.
                                   │
                                   ▼
          [Level 31+: Professional Practitioner (Endgame)]
          • Unlocks the automated "Attending Physician" Assessment Rubric.
          • Complex, volatile multi-axis trauma files dominate the inbox.

### The "Experience Magnet" Mechanic

* Progression-Gated Pathologies: Early-stage players only attract low-stakes, highly expressive cases (e.g., simple anxiety surrounding an office transition).
* The Complexity Vector: As a player wins sessions, their profile Experience Rating climbs. High XP metrics modify the client's internal routing seed, turning their profile into an "experience magnet" that pulls increasingly unstable, multi-layered, and pathologically volatile patient manifests out of the network swarm.

### The Daily Study Point Economy

* The Free Daily Point: Every 24 hours, the game awards every player exactly one Free Study Point upon login.
* The University Hub Tree: Points are spent to study specialized medical fields (e.g., Somatoform Mechanics, Advanced Behavioral Defense Systems).
* Knowledge Pool Unlock: Unlocking a field makes matching specialty techniques available. However, players must manually load these acquired skills into an active format before a session to counteract advanced psychological crises.
* Level-Gated Fields: The total number of study fields that can be unlocked is capped by a player’s current level; players can reach higher levels without unlocking every field, but they cannot unlock every field without first reaching the required level thresholds.
* Highest-Level Correlation: Maximum career level is directly correlated with the number of study fields designed into the game. The full set of fields becomes available only as the player rises through the career tiers.

### Free Source Inspiration for Study Fields

* Open educational resources such as OpenStax Psychology, MIT OpenCourseWare, and Khan Academy can inspire course themes and terminology.
* Public-domain and Creative Commons material from Wikipedia, Project Gutenberg, and NIH/NIMH summaries are useful for designing field structure without copying proprietary content.
* Free mental-health references like WHO ICD-11, CDC guides, and open-access PubMed Central papers provide concept ideas for anxiety, trauma, resilience, and behavioral frameworks.
* Game-design resources like GDC Vault free talks, itch.io devlogs, and Unity/Godot learning content can guide how to make study fields feel rewarding and balanced.
* Use these sources for inspiration, not verbatim content; prefer fictionalized field names and gameplay concepts to stay safe and distinctive.

------------------------------
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

------------------------------
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

------------------------------
## 8. The "Brain vs. Mouth" Mechanics
To prevent small local models from hallucinating or breaking rules, the game engine is split into two strict layers.

* The Dart Engine (The Brain): Tracks all mathematical mechanics behind the scenes (e.g., trustScore, agitationLevel, activeDefense). It updates these stats when a player clicks a gameplay option.
* The Local LLM (The Mouth): Never manages game logic. It simply reads a real-time system prompt generated by Dart string interpolation (e.g., "Your trust is low, act defensive using scuba slang") and acts as a realistic conversational translator.

------------------------------
## 9. Choice-Driven Interface (The Therapy Deck & Loadout System)
Open-ended text/voice typing is replaced by structured, high-stakes tactical inputs to ensure flawless gameplay stability and prevent cognitive clutter in the endgame.

* The Active Therapy Loadout: To combat interface bloat as a player scales their academic specializations, players cannot take all unlocked cards into a session. They face a hard restriction limit of 5 or 6 Active Card Slots per session layout.
* The Clinical Preparation Phase: Prior to initiation, the player evaluates the initial patient profile intake details and curates an active deck configuration (e.g., matching Somatic Grounding cards to a suspected panic presentation). Equipping incorrect loadouts leaves the player functionally exposed, forcing tactical retreats or reliance on suboptimal techniques.
* Graphical Controllers: Flutter UI sliders and dials allow players to dynamically alter their conversation focus (e.g., Childhood vs. Workspace) and emotional delivery posture (Warm vs. Objective).
* Jailbreak Immunity: Because the AI model only receives rigid inputs from a predetermined card setup, it is mathematically impossible for users to trick or break the AI's character.

------------------------------
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

------------------------------
## 11. The "Universal Actor" Storage & Asset Pipeline
To prevent the application from consuming hundreds of gigabytes of device storage, the technical architecture separates cognitive processing from narrative identity.
### The Fixed Storage Footprint

* The Base Persona Core (.GGUF): The client application bundles or streams a single, unified, ultra-compressed open-source base language model (e.g., 3-Billion parameters). This model acts as a "Universal Actor" trained to understand dramatic pacing, clinical terminology, and roleplay instruction adherence. It occupies a static ~1.8 GB footprint that never grows.
* The patient manifest (.JSON): Every individual patient in the game—including their workspace culture, trauma backstory, current emotional statistics, and dialog pathways—is stored as a microscopic text file under 50 KB.

### Immersive UI Representation (The Client File Cabinet)

* The Clinical Archive: Inside the game UI, this architecture is stylized as a literal "Patient File Cabinet."
* Dynamic Thread Injection: When a player clicks on a specific patient's folder to start a therapy session, the Flutter engine instantly reads that patient's tiny JSON file. It feeds the unique behavioral rules, fictional medicine tolerances, and workspace slang directly into the active memory layer of the single base model.
* Zero-Overhead Memory Swapping: When the player switches to a different patient, the base model remains loaded in the phone's RAM. Only the 50 KB text script is swapped out, allowing instantaneous session transitions with zero processing lag or storage bloat.

------------------------------
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
       ┌────────────────────────┴────────────────────────┐
       ▼                                                 ▼
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

------------------------------
## 13. The Financial Stabilizer: Anti-Bankruptcy & Anti-Pay-to-Win Mechanics
To prevent a permanent failure loop where a player's profile metrics collapse, the system provides two distinct recovery trajectories. These paths are designed to prevent "Pay-to-Win" shortcuts, balancing progress via strategic planning instead of monetary microtransactions.

+---------------------------------------------------------------------------------------+

|                           CLINIC FINANCIAL RECOVERY MATRIX                            |
+------------------------------------+--------------------------------------------------+

| Strategy A: The Discount Practice  | Strategy B: Academic Sabbatical (Study Sabbat)   |
+------------------------------------+--------------------------------------------------+

| • Action: Lower the session fee    | • Action: Set clinic to "Closed" mode.           |
|   using the Pricing Slider.        | • Loop: Spend Daily Points on core certs.        |
| • Payoff: Floods inbox with casual, | • Payoff: Re-opens clinic with automatic baseline|
|   low-stakes patient manifests.        |   Reputation restore based on total credentials.  |
| • Penalty: Slashes XP gains by 50% | • Penalty: Zero currency earned during downtime. │
+------------------------------------+--------------------------------------------------+

### Strategy A: The Discount Practice (High-Volume Recovery)

* The Slider Interaction: When a player’s reputation drops past a critical operational threshold, wealthy or complex patients stop booking appointments. The player must manually slide their Pricing per Patient metric to a heavily discounted rate.
* The Mechanical Tradeoff: Dropping prices alters the routing seed, flooding the clinic inbox with entry-level, highly cooperative casual patients.
* The Progression Penalty: To maintain economic balance, all sessions treated under a default "discounted rate" trigger a static 50% Experience Point Penalty. The player can easily rebuild their lost reputation points through high-volume, easy wins, but their character's mechanical leveling progression is severely slowed down.

### Strategy B: Academic Sabbatical (The Study Sabbat)

* The Clinic Closure: Alternatively, the player can toggle an on-screen "Academic Sabbatical" status flag. This completely pauses the daily incoming patient router.
* The Reputation Restore: While closed, the player accumulates their Free Daily Study Points and completes specialized courses in the university hub. When they unlock a new certification milestone, the engine runs an internal math loop (Reputation Reset Minimum = Total Study Fields * Base Competency Constant).
* The Outcome: The player's baseline clinic reputation automatically scales back up to a minimum safe floor value based entirely on their academic credentials. They forfeit all potential currency earnings during the downtime, but they return to active practice fully optimized to face complex pathologies without spending a single cent of real-world money.

------------------------------
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

### The Professional-Tier Shift (Endgame Grading Rubric)

* The Automated "Attending Physician" Report: Once a player crosses a high-tier Experience threshold (e.g., Level 30+), the game unlocks its analytical endgame simulator. Simple win/loss notifications are replaced by an advanced Clinical Assessment Matrix. The local Dart engine tracks card sequence selections to deliver a multi-page analytical report scoring the user on Therapeutic Alliance Maintenance, Diagnostic Path Efficiency, and Pharmacological Safety.
* The Multi-Session Siege: High-tier patients possess nested, multi-layered defensive frameworks that resist immediate resolution. The player must exit active daily check-ups to analyze collected linguistic clues, comparing text histories against the app's diagnostic encyclopedia before entering subsequent rounds.

------------------------------
## 15. The Four-Tier Functional Card Taxonomy & AI Fatigue Countermeasures
Instead of static "win/lose" options, cards possess context-dependent behavioral properties. To guarantee veteran players do not face behavioral redundancy from the core AI actor, dynamic conversational variances alter execution vectors.
### Linguistic Vector Mutation & Conversational Curveballs

* Linguistic Archetype Prompt Components: To bypass repetitive syntax loops, the 50 KB player manifest shifts the base model's prompt layout using a style filter (e.g., The Cynic vs. The Intellectual), making identical underlying conditions sound entirely distinct.
* The Transference Spike: High-trauma sessions prompt sudden relational shifts where conventional Empathy cards are read programmatically as Manipulative Failures, completely flipping the required tactical strategy.

### The Dynamic Card Spec Matrix

       ┌────────────────────────────────────────────────────────┐
       │               DYNAMIC CARD SPEC MATRIX                 │
       └───────┬───────────────────┬────────────────────┬───────┘
               │                   │                    │
               ▼                   ▼                    ▼
   ┌───────────────────────┐ ┌──────────────┐ ┌────────────────────┐
   │ 1. BULL'S EYE         │ │ 2. RELATABLE │ │ 3. POSTPONING      │
   │ • Perfect Context     │ │ • Soft Comfort │ │ • Tactical Delay   │
   │ • Triggers Break-thru │ │ • Minor Rapport│ │ • Freezes Crisis   │
   └───────────────────────┘ └──────────────┘ └────────────────────┘
                                       │
                                       ▼
                           ┌───────────────────────┐
                           │ 4. MANIPULATIVE       │
                           │ • High-Stakes Gamble  │
                           │ • Risk Psych Derange  │
                           └───────────────────────┐

### 1. Bull's Eye (The Clinical Catalyst)

* The Interaction: Triggered only when the selected card matches the exact intersection of the patient's current active trauma node, insight level, and workspace culture.
* The Result: Drastically drops the patient's agitationLevel, permanently increments trustScore, cracks open their defensive shield, and unlocks deep, core narrative backstory dialogue.

### 2. Relatable (The Safe Rapport Builder)

* The Interaction: Triggered by conversational techniques that align softly with the patient's ethnic background, domestic status, or general professional archetype without directly touching the underlying trauma.
* The Result: Grants a nominal, un-satisfying bump to trustScore (+2 to +5) and prevents crises. It acts as an operational buffer, giving the player a safe, low-risk move when they are stalling for time or collecting linguistic clues.

### 3. Postponing (The Tactical Stalemate)

* The Interaction: Cards that deploy objective clinical deflection, generic therapeutic silence, or bureaucratic scheduling prompts.
* The Result: Freezes the current game state for 1 to 2 turns, rendering the patient's agitation static.
* The Multi-Session Decay: Playing Postponing cards introduces a creeping negative modifier to the overall case file. Over several sessions, the patient grows increasingly impatient with the lack of progress, causing their baseline starting agitation in subsequent daily check-ups to climb.

### 4. Manipulative (The Psychological Double-Edged Sword)

* The Interaction: High-risk, assertive interventions such as gaslighting, reverse psychology, or intense emotional provocation designed to bypass a rigid defensive shield.
* The Result: A volatile, structural gamble evaluated dynamically by the client/Dart engine:
* Success (High Trust State): Instantly shatters the patient's defense mechanism, bypassing normal study tree requirements and dropping massive clue drops.
   * Failure / Derangement (Low Trust State): Psychologically deranges the patient layout. The Dart engine permanently breaks the patient's patient manifest, mutating their baseline condition into a chaotic, unmapped secondary pathology (e.g., turning a manageable Anxiety state into an erratic, hyper-defensive Paranoia state). The existing study cards the player owns lose their effectiveness, rapidly accelerating the patient's trajectory toward the Mental Hospital loop.

------------------------------
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
------------------------------
## 17. The Living P2P Ledger: Immutable Memory & Trauma Multipliers
The Peer-to-Peer network operates as an active narrative ecosystem where patient data files carry persistent, unyielding psychological scars from their past real-world doctors.
### The Immutable Case History Array

* The Append-Only Ledger: Every session conclusion appends a cryptographic, signed transaction block to the patient's manifest.json. This block logs the previous doctor’s public username, the cards played, medications prescribed, and the psychological outcome.
* Narrative Continuity: When a patient is transferred to a new device, the local base model parses this ledger. The patient will actively reference past treatment styles (e.g., "My last doctor just tried to drug me into silence, I don't trust you"), inheriting trust deficits and chemical dependencies from their past therapies.

### The Trauma Multiplier (High-Risk Bounty Engine)

* The Severity Metric: The more a patient is mistreated, misdiagnosed, or forced into a psychological crisis by previous players, the higher their hidden Trauma Severity Index grows inside the ledger.
* The Risk/Reward Loop: Accepting a severely mistreated patient serves as an organic "Mythic Difficulty" tier. The patient's baseline metrics are incredibly unstable, meaning a single conversational misstep will cause them to walk out permanently.
* The Progression Payoff: If a player successfully stabilizes, treats, or cures a high-trauma patient, all earned experience points, leaderboard rankings, and in-game currency payouts are multiplied directly by the patient's Trauma Severity Index. This creates a high-stakes economy where elite players hunt for broken models to maximize their professional standing.

------------------------------
## 18. The P2P Referral & Mental Hospital Ecosystem
No patient model is ever deleted; they move through a living decentralized lifecycle.

* P2P Patient Referrals: Players can directly package a patient's custom manifest.json file (including dialogue history) and transfer them across the WebRTC network to a friend's device if they lack the card deck required to treat them.
* The Mental Hospital Loop: If a local small model suffers a technical glitch or character break, the player clicks "Commit to Mental Hospital." The app freezes the file, uploads the bug logs to the central server for automated monthly retraining, and places the patient in an in-game asylum registry until the player finishes the academic studies needed to treat them again.

------------------------------
## 19. Monetization Blueprint

* Premium Case Files: Selling targeted thematic character packs (e.g., The Corridor of Power Pack, The Forensic Psych Pack).
* Specialty Expansion Decks: Selling advanced card mechanics or immediate access to university study modules, bypassing real-world cooldown timers.
* Emergency Consultations: Microtransactions allowing players to temporarily rent a highly specialized card mid-session to save a rare patient from walking out.
* Cosmetic Customization: Selling visual office overhauls (e.g., Manhattan High-Rise Office) and custom UI engine layouts.

------------------------------
## 20. Visual Safeguards

* Low-Cost / High-Impact Art Styles: The visuals will leverage moody graphic-novel silhouettes, clean clinical vectors, or dynamic Rorschach inkblots. This bypasses expensive 3D face animation and lip-syncing entirely, while subtle looping environmental filters (e.g., moving rain shadows, pulsing EKG vitals lines) keep the screen feeling alive.

------------------------------
## 21. The Peer-to-Peer Medical Director Framework (Endgame User-Generated Content Engine)
Once a player reaches the highest levels of practice and experience, their career path transitions into institutional oversight. The game interface permanently unlocks the Medical Director Dashboard Panel, transforming veteran players into content creators who supply the decentralized P2P swarm.

* Procedural Injection Design Tools: Medical Directors use a localized design panel to build custom patient manifest templates. They manually specify advanced track rules, including custom Workspace Cultures, hyper-targeted Somatic Vulnerability Axes, and explicit Core Maladaptive Schemas.
* The Validation Test Interview: To prevent broken, un-winnable, or toxic files from entering the ecosystem, a newly created template cannot be published immediately. The Medical Director must personally complete a successful test therapy session with their own created manifest using the local LLM engine.
* Decentralized Swarm Publishing: Once validated, the created patient manifest (manifest.json) is cryptographically signed with the player's unique identity key and pushed to the global P2P matchmaking board. Every time another active player across the WebRTC network downloads, pays a treatment fee, or successfully treats that custom manifest, the original creator earns continuous passive royalties in clinic currency and prestige points.

------------------------------
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

------------------------------
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

------------------------------
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

------------------------------
## 25. High-Level Game State Machine Loop (Client Execution Script)
The baseline operational turn flow loop for individual standalone clients or employed corporate associates during an active session behaves according to this runtime state flow:

             +-------------------------------------------------+

             |              START CLINICAL TURNS               |
             +------------------------┬------------------------+
                                      │
                                      ▼
             +-------------------------------------------------+

             |      Local Dart Reads patient manifest        |
             | • Loads Biographical, Relational Variables      |
             | • Injects Workspace & Custom Slang Strings      |
             +------------------------┬------------------------+
                                      │
                                      ▼
             +-------------------------------------------------+

             |       User Pulls Local Card Deck UI             |
             | • Displays 5-6 Equipped Active Cards            |
             +------------------------┬------------------------+
                                      │
                                      ▼
             +-------------------------------------------------+

             |       Player Deploys Action Choice Card         |
             | • Adjusts Sliders: Focus & Posture Tone         |
             +------------------------┬------------------------+
                                      │
                                      ▼
             +-------------------------------------------------+

             |         Dart Core Calculates Mutation           |
             | • Runs Index Check: Matches Card to Manifest   |
             | • Outputs Enum: 1, 2, 3, or 4 Card Category     |
             +------------------------┬------------------------+
                                      │
                                      ▼
             +-------------------------------------------------+

             |    Background Isolate Compiles Prompter Text    |
             | • Mutates live metrics: Trust & Agitation Scores|
             | • Appends dynamic behavior constraint payload   |
             +------------------------┬------------------------+
                                      │
                                      ▼
             +-------------------------------------------------+

             |     Local GGUF Core LLM Executes Inference       |
             | • Generates contextually accurate dialogue       |
             +------------------------┬------------------------+
                                      │
                                      ▼
             +-------------------------------------------------+

             |             Check Win / Loss State              |
             +------------------------┬------------------------+
                                      │
             ┌────────────────────────┴────────────────────────┐
             ▼                                                 ▼
     [Session Continues]                                [Session Concludes]
     • Loop to next turn state.                         • Appends transaction log string.
                                                        • Cryptographically signs file.
                                                        • Pushes payload to Supabase tables.

------------------------------