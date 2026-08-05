# Lumo: Earn Your Scroll — Research Dossier

**Prepared:** 2026-08-05
**Scope:** (A) Unrot content-strategy teardown · (B) Independent scientific verification · (C) Competitive/market analysis · (D) Evidence-backed design principles

> **Status: complete.** ~24,000 words. All six Unrot pages read in full; ~120 primary sources verified (many extracted from the papers themselves); ~4,000 App Store reviews sampled across 14 competitors plus a full App Store category sweep and the Apple Developer Forums.
>
> **The six things to act on first:**
> 1. **Rename.** "Earn Your Scroll" is Unrot's own App Store opening line; *Luma: Earn Screen Time* shipped 2026-07-26; six live apps are already called Lumo.
> 2. **Submit the Family Controls entitlement request today.** No SLA, waits of 1 week to 5 months, needed for *every* bundle ID — and **it gates TestFlight**, so you cannot beta-test without it.
> 3. **Ship a real free tier.** ~30–39% of recent reviews on paywalled competitors are 1★, almost entirely about the paywall — and Guideline **4.10** names Screen Time APIs as something you may not monetize.
> 4. **Price coins off each user's measured baseline** (response deprivation, not Premack). Nobody does this, and it is the strongest theory available.
> 5. **Never punish a miss.** Best of 53 interventions on 61,293 people was a bonus for coming *back* — and Duolingo's 2026 streak-restore campaign was "one of the most consistent requests" they hear. Make forgiveness free.
> 6. **Build a token-rotation self-heal.** iOS silently reissues `ApplicationToken`s (FB14082790); ScreenZen, Jomo and Opal all report it. It is the root cause of the "it stopped blocking" reviews burying every competitor — and fixing it is defensible differentiation.

---

# TASK A — Unrot Content Teardown

Six pages read. Unrot's blog is a **content-marketing funnel**, not a science publication: every article follows the identical arc *validate → alarm → mechanism → protocol → "but willpower fails" → Unrot as the system*. That arc is itself the most reusable asset here.

## A.0 The Unrot product (assembled from all six pages + homepage)

| Element | Detail |
|---|---|
| Positioning | "Replace doomscrolling with healthy habits" / "Earn your screen time" |
| Explicit anti-positioning | "Unrot isn't another blocker or shaming tool. It's a brain companion." — repeated on 4 of 6 pages |
| Currency | "Brain credits" / "brain points" |
| Earning | 25+ task database + custom tasks. Named: short walk, reading, homework, meditating, journaling, breathing, gratitude, workouts, meals |
| Proof | **Photo-based habit logging** ("log proof") |
| Spending | Credits unlock TikTok / Instagram / YouTube |
| Mascot | Evolving **brain mascot** with a **chat interface**; reflects "focus and discipline" |
| Focus tools | Timers + soundscapes |
| Retention | Streaks & milestones, framed as "discipline – not shame" |
| Side product | **Dopamine Menu Builder** — free 5-step web tool, lead magnet, "Takes 2 minutes • Free" |
| Privacy | On-device, no cloud storage — used as a marketing claim |
| Monetization | Hard paywall after long onboarding; **no free trial** — this is their single biggest review complaint |

## A.1 "Your Phone Isn't Evil – But It's Hijacking Your Brain"

**Thesis:** The phone is not the villain; the engineered reward schedule is. You are not addicted to your phone, you are "addicted to avoiding discomfort." Therefore blocking is the wrong intervention — you need "structure, feedback, and incentives."

**Mechanism claims:**
- Phones run an **intermittent reward schedule**, "the same behavioral loop as slot machines and stimulants like cocaine."
- Anticipatory dopamine: pings/scrolls become conditioned cues.
- "Over time your brain stops producing its own motivation."
- **Dopamine deficit / baseline rewiring:** heavy use lowers striatal dopamine synthesis.

**Named citations:** Mangot et al. (phantom vibration 60% / phantom ringing 42%); He et al. (SNS addiction brain anatomy); Westbrook et al. 2021 (striatal dopamine synthesis); "23 minutes to refocus"; "100+ phone checks/day"; "$200B/yr Big Tech engagement spend"; "Big Tech hired casino designers."

**Protocol (the author's personal stack):** sunlight within 30 min of waking · breathing + walking before phone · no caffeine for 90 min · no phone 90 min before sleep · weightlifting "to strengthen the prefrontal cortex" · "intentional dopamine recalibration" · reframe stress instead of numbing.

**→ Product features implied:** morning-routine gating (phone locked until a morning action logged); sunlight/outdoor detection; pre-sleep wind-down lock; caffeine/sleep logging; a named "recalibration" program; and critically — **incentives, not blocks**.

## A.2 "Rebuilding Your Attention Span: 5 Proven Habits Backed by Neuroscience"

**Thesis:** "You're not broken. The system is." Attention is a *trainable skill*, but training requires reinforcement, not willpower. Unrot is explicitly framed here as "not a screen time blocker – it's a **rebalancer**."

**The five habits, with the mechanism each is sold on:**
1. **Deep breathing, 5 min** → "activates the prefrontal cortex."
2. **Screen-free walking, 15 min** → "soft fascination," Attention Restoration Theory.
3. **Journaling (handwritten better)** → "trains your reticular activating system," meta-cognition.
4. **Focus soundscapes + timer** → a "focus container," sustained attention.
5. **Morning dopamine discipline (first 30–60 min)** → avoid TikTok/IG first thing or you "blunt dopamine sensitivity."

**Named citations:** UC Irvine / Gloria Mark, Gudith & Klocke; Gazzaley & Rosen *The Distracted Mind*; Stephen Kaplan (ART); Xiao Ma et al. (diaphragmatic breathing); Nisbet & Zelenski; Mueller & Oppenheimer (longhand notes); plus soft sources (Psychology Today, HBR, LifeHack).

**→ Product features implied:** these five are literally the **launch task taxonomy**. Each maps to a distinct earn-action with a distinct verification method: breathing (in-app guided timer), walk (HealthKit steps + GPS), journal (text entry / handwriting photo), focus session (in-app timer + soundscape library), morning discipline (a time-windowed bonus multiplier).

## A.3 "Dopamine Detox Doesn't Work – Unless You Do This"

**Thesis — the sharpest strategic article of the six.** It *attacks* the dopamine-detox trend to differentiate: detoxes fail because (1) too extreme, (2) they don't change the system, (3) they rely on finite willpower. "The key is not to avoid dopamine – but to earn it intentionally."

**Notably accurate points:** it correctly says dopamine is not depleted, is released *in anticipation* of reward, and that Sepah's 2019 framing was "a behavioral tool to reduce impulsivity – not a literal reset of brain chemicals."

**Named citations:** Dr. Cameron Sepah ("Dopamine Fasting 2.0"); Harvard Health; Psychology Today; APA. No statistics.

**→ Product features implied:** the **effortful-vs-instant reward taxonomy** is a design primitive — tasks should be priced by effort, not duration. Explicit feature callouts: earn credits → spend to unlock; photo-proof logging + streaks; brain mascot as real-time state feedback.

## A.4 "What Is Brainrot? The Science Behind Why You Can't Focus Anymore"

**Thesis:** "Brainrot" is a real experiential syndrome (explicitly conceded as "not a clinical diagnosis") caused by reward-system hijack, attentional fatigue, and DMN overactivation. This is the **SEO cornerstone** — it owns the term.

**Mechanism claims:** mesolimbic hijack; dopamine as *wanting* not *liking* (correct, and the most scientifically literate claim on the whole site); "intermittent variable rewards"; attentional fatigue via ART (Kaplan 1995); **default mode network** hyperactivation linked to rumination/anxiety; altered neuroplasticity.

**Symptom checklist (a conversion device, not a diagnostic):** shortened attention span · mental fatigue after brief cognitive work · low baseline dopamine · mood volatility (numb ↔ anxious) · decreased motivation for effortful tasks.

**Named citations:** Kaplan 1995; Woolley & Sharif (HBR); Yeshurun, Nguyen & Hasson (DMN, *Nature Rev Neuro*); Steward, Looi & Chib (cognitive fatigue); Sheline (mood disorder neuroimaging); Csíkszentmihályi (flow).

**→ Product features implied:** an onboarding **"brainrot score" quiz** built from that symptom list (this is the highest-leverage borrowable asset — it's a self-diagnosis funnel that creates a baseline the app can then show improving); "credit-based dopamine detox" as a named program; flow-aligned timers/soundscapes; mascot as non-punitive mirror.

## A.5 "Why Your Brain Feels Broken and What You Can Do About It"

The thinnest article — pure mid-funnel conversion copy, no citations at all beyond "100 times a day."

**Section headings:** "What's stealing your focus?" → "Unrot helps you take control – gently" → "Rewire, don't restrict."

**Key positioning lines to note:** *"Not because they want to – but because they've been trained to."* · *"Unrot isn't another blocker or shaming tool. It's a brain companion."* · *"Most apps just punish you for using your phone. Unrot rewards you for caring for your brain."*

**Features named:** Brain Credits · **Smart Blockers** ("gentle nudges replacing hard restrictions") · **Clarity Tracking**.

**→ Product features implied:** "Smart Blockers" is the interesting one — a *soft* interstitial/nudge layer distinct from hard Screen Time blocking. And "Clarity Tracking" implies a composite longitudinal score, i.e. a retention surface.

## A.6 The Dopamine Menu (`/dopaminemenu` + `/dopaminemenu/build`)

**Concept:** *"A personalized list of mood-boosting activities. When you're depleted, don't decide—just pick from your menu."* This is a **decision-fatigue** intervention, and it is the single best product idea on the entire site.

**Five categories (restaurant metaphor):**
| Category | Framing | Timing |
|---|---|---|
| 🥗 Appetizers | "Quick wins" | 5–15 min |
| 🍝 Mains | "Real satisfaction" | 30+ min |
| 🥬 Sides | "Task stacking" — pair with boring tasks | — |
| 🍰 Desserts | "Guilty pleasures. In moderation." | — |
| ⭐ Specials | "Anticipation" — worth the wait | — |

**Actual builder content (step 1 of 5, Appetizers), verbatim:**
- *Movement:* 5-min walk · Stretch · Dance to a song · Jumping jacks
- *Sensory:* Cold water on face · Step outside · Deep breaths · Open a window
- *Small wins:* Make tea/coffee · Favorite song · Text someone · Tidy one thing
- Plus "+ Add your own" and a running "N selected" counter.

**Lead capture:** "Start Building," "Takes 2 minutes • Free" → 5-step wizard. No email gate observed on step 1.

**→ Product features implied — and this is important for Lumo:**
- **"Sides" is literally temptation bundling** (pair a reward with a boring task) and **"Desserts" is literally the Premack contingency**. Unrot built the right conceptual frame and then did *not* wire it to the coin economy. That is an exploitable gap.
- The menu should be Lumo's **onboarding personalization step**, not a detached web toy: what a user picks in the menu becomes their earn-task list, pre-committed and self-authored (autonomy support — see §B).
- Build it as a free, shareable, no-signup web tool for acquisition, exactly as Unrot did.

## A.7 Fact-check of Unrot's science claims

I verified the specific claims because you'll want to know which are safe to reuse.

| Claim | Verdict |
|---|---|
| Phantom vibration 60% / ringing 42% | ✅ **Accurate.** Mangot et al. (2018), *Indian J Psychol Med*, N=93 medical interns, India. PV 60%, PR 42%. Also supports: Rothberg et al. (2010) *BMJ* found 68% (95% CI 61–75%) among 169 medical staff. |
| "Greater social app use correlates with reduced dopamine synthesis in the striatum" | ⚠️ **Technically accurate, badly framed.** Westbrook et al. (2021), *iScience*, [18F]-DOPA PET. **N = 22.** β = −1.5×10⁻³ min⁻¹, t(18) = −4.8, p = 1.3×10⁻⁴, R² = 0.55 in bilateral posterior putamen. **BUT** the authors' own interpretation runs the *other* direction — that "smartphone-based social behavior **indexes** striatal dopamine function," i.e. dopamine function may predict phone use. They explicitly disclaim causality and call for replication. Unrot's "heavy screen use... rewires your baseline" is a causal overreach on a cross-sectional N=22 study. **Do not repeat this framing.** |
| "23 minutes to return to full focus" | ⚠️ Traceable to Gloria Mark's work but routinely over-stated — see §B. |
| "$200 billion/year to keep you scrolling" | ❌ Unsourced. Appears to be ad-revenue conflated with "spend to keep you hooked." Do not reuse. |
| "Big Tech hired casino designers" | ⚠️ Rhetorical. The defensible version is Schüll's *Addiction by Design* + Ramsay Brown/Dopamine Labs press coverage. |
| Dopamine = "wanting not liking" | ✅ Correct (Berridge & Robinson). Their best claim. |
| "Journaling trains your reticular activating system" | ❌ **Pseudoscience.** The RAS is a brainstem arousal system; "RAS filters what deserves attention" is self-help folklore, not neuroscience. Do not reuse. |
| "Weightlifting strengthens the prefrontal cortex" | ⚠️ Over-claimed. Exercise→executive function evidence exists but is modest and not resistance-training-specific. |
| "Willpower is a finite resource" | ⚠️ **Ego depletion has largely failed to replicate.** Avoid. |

**Strategic read:** Unrot's content is ~60% defensible, ~25% over-claimed, ~15% wrong. Lumo can win on rigor — being the app that *cites correctly* is a genuine differentiator in this category, and it protects you from App Store health-claim scrutiny.

## A.8 The reusable content-strategy skeleton

Every Unrot post: **(1)** absolve the reader ("You're not broken/lazy") → **(2)** name the enemy as design, not the user → **(3)** one neuroscience mechanism with a memorable name → **(4)** a symptom checklist the reader self-identifies with → **(5)** a free protocol → **(6)** "but willpower alone fails, you need a *system*" → **(7)** Unrot as the system, with 3–5 named features → **(8)** App Store CTA, twice.

Step 6 is the hinge: it is what converts an educational reader into a purchaser, and it is why the "rebalancer, not blocker" positioning exists.

---

# TASK B — Independent Scientific Verification

> **Global calibration warning, read first.** DellaVigna & Linos (2022, *Econometrica* 90(1), 81–116) compared 126 RCTs across 23 million people run by two large government nudge units against the published academic literature: **academic papers average +8.7pp (+33.4% over control); the nudge units' own trials average +1.4pp (+8.0%)**, with ~70% of the gap attributed to selective publication. Separately, Milkman et al. (2021, *Nature*) found expert forecasters were **9.1× too optimistic**, with a prediction–outcome correlation of **r = 0.02, p = 0.89**. **Divide every effect size in this section by roughly 6 before forecasting Lumo's results.**

## B.1 Dopamine, reinforcement schedules, and persuasive design

### The claims that survive scrutiny

**Reward prediction error.** Schultz, Dayan & Montague (1997), *Science* 275(5306), 1593–1599 — dopamine neurons signal the *difference between received and predicted reward*, not pleasure. The design-critical line from Schultz (2016), *Dialogues Clin Neurosci* 18(1), 23–32: **"The response to the reward itself disappears when the reward is predicted."** This — not "dopamine hits" — is the real reason predictable rewards stop motivating.

**Uncertainty maximizes anticipatory dopamine.** Fiorillo, Tobler & Schultz (2003), *Science* 299(5614), 1898–1902 — a sustained ramp in dopamine activity that is **maximal at p = 0.5**. This is the single best citation for "variable reward." ⚠️ Contested: Niv, Duff & Dayan (2005), *Behav Brain Funct* 1:6 argue the ramp may be an averaging artifact of temporal-difference errors. Also: monkey single-unit recordings.

**Wanting ≠ liking.** Berridge & Robinson (1998), *Brain Res Rev* 28(3), 309–369 (rats depleted of accumbens dopamine by up to 99%); and Berridge & Robinson (2016), *American Psychologist* 71(8), 670–679: *"Incentive salience or 'wanting'... is generated by large and robust neural systems that include mesolimbic dopamine. By comparison, 'liking'... is mediated by smaller and fragile neural systems, and is not dependent on dopamine."* **This is the most useful citation in the entire dossier for Lumo's marketing** — it is the rigorous mechanism for "I scroll for two hours and don't enjoy any of it."

**Opponent process.** Solomon & Corbit (1974), *Psychological Review* 81(2), 119–145: opponent b-processes are **"strengthened by use and weakened by disuse."** This is the real, 50-year-old, well-replicated backbone of everything Lembke says. Cite Solomon & Corbit, not the gremlins.

**Social media really is reward learning — but not the way people say.** Lindström et al. (2021), *Nature Communications* 12:1311. **1,046,857 posts from 4,168 users across 4 platforms.** RL model beat null for ~70% of users (Instagram mean AIC weight 0.70, *t*(2038) = 23.1, p < .0001). Reward rate → posting latency: Instagram β = −0.18, SE = 0.003, t = −54.59. Causal experiment (N = 176, 2,206 posts): **β = 0.109, z = 2.47, p = .013 — a 10.9% latency shift.**
⚠️ **Three honesty points:** (1) The winning model is **average reward-rate maximization** (matching law / marginal value theorem), **not** a variable-ratio account. (2) The causal effect is modest. (3) **Zero neurobiological data** — anyone citing this as "social media hijacks your dopamine" is misciting it.

**Commitment devices work and people pay for them.** Ashraf, Karlan & Yin (2006), *QJE* 121(2), 635–672 — SEED accounts in the Philippines; **28.4% (202/710) accepted a strictly dominated product** with no compensating return.

**Deactivation works.** Allcott, Braghieri, Eichmeyer & Gentzkow (2020), *AER* 110(3), 629–676 — 4-week randomized Facebook deactivation increased subjective wellbeing, increased offline socializing, and produced "a large persistent reduction in post-experiment Facebook use."

**The most directly relevant paper to Lumo.** Allcott, Gentzkow & Song (2021/2022), "Digital Addiction," NBER w28936 / *AER*: *"Temporary incentives to reduce social media use have persistent effects, suggesting social media are habit forming. **Allowing people to set limits on their future screen time substantially reduces use**, suggesting self-control problems... **self-control problems cause 31 percent of social media use.**"* — This is your market-sizing citation *and* your product-thesis citation in one.

### The claims that do NOT survive scrutiny

| Popular claim | Verdict |
|---|---|
| "Skinner proved variable-ratio is the most extinction-resistant schedule; that's why apps are addictive" | **Overstated.** The robust finding is the Partial Reinforcement Extinction Effect (any intermittent schedule > continuous), which predates Ferster & Skinner (Humphreys 1939). Among intermittent schedules VR is *not* reliably most persistent when reinforcement rates are equated; Nevin's behavioral-momentum work reframes persistence as a function of reinforcement rate in context. Ferster & Skinner (1957) is a **descriptive catalogue of cumulative records in pigeons**, not an extinction experiment. |
| "Apps use variable-ratio schedules" | **Analogy, never measured.** No published study instruments a real consumer app, shows its reward delivery conforms to VR, and shows VR *specifically* drives overuse. |
| "Dopamine detox" | The **name is neurochemically incoherent**; the underlying technique is legitimate. See B.2. |
| "Zuckerman / sensation seeking" | **Wrong lineage.** Zuckerman created the Sensation Seeking Scale; he is not part of the reinforcement-scheduling or persuasive-design literature. The construct usually paired with dopamine in addiction work is Cloninger's Novelty Seeking, and even the DRD4-VNTR link **largely failed to replicate**. Drop him. |
| "Ludic loop" (attributed to Schüll) | **Could not verify as a defined term in the book.** She writes about "the zone." Attribute loosely or avoid. |
| Fogg's Tiny Habits | **No independent RCT found.** Practitioner framework, not evidence-based intervention. Also, its "emotion creates habits, not repetition" claim sits in tension with Lally et al. (2010). |

### Frameworks worth using (as frameworks, not evidence)

- **Schüll (2012), *Addiction by Design*** — the transferable concept is **"time on device" (TOD)**, the gambling industry's own objective function, identical to "engagement." And the counterintuitive core observation: **players in the zone are not playing to win, they are playing to keep playing.** Winning is an interruption.
- **Fogg (2009), Persuasive '09, ACM, https://doi.org/10.1145/1541948.1541999** — B = MAP (Motivation, Ability, Prompt; originally MAT with "Trigger"). Six *Ability* factors: time, money, physical effort, **brain cycles**, social deviance, non-routine. Three prompt types: Spark, Facilitator, Signal. Concept of ***kairos*** — the opportune moment.
- **Eyal (2014), *Hooked*** — Trigger → Action → Variable Reward → Investment. Eyal's own words: *"Variable schedules of reward are one of the most powerful tools that companies use to hook users."* But note his later reversal in *Indistractable*: *"The correct term for what most people experience when overusing tech is much less scary — it is not an addiction, but a distraction."* He has a conflict of interest in both directions.

## B.2 Is "dopamine detox" scientifically valid?

**What Sepah actually said.** Sepah, C. (2019), "The Definitive Guide to Dopamine Fasting 2.0," LinkedIn/Medium. His definition: *"an evidence-based technique to manage addictive behaviors, by restricting them to specific periods of time... in order to regain behavioral flexibility."* His explicit disclaimer, verbatim: ***"We ARE NOT fasting from dopamine itself, but from impulsive behaviors reinforced by it."*** He lists "reducing dopamine" under what it is **not**. Six target behaviors: emotional eating, internet/gaming, gambling/shopping, porn, thrill/novelty seeking, recreational drugs. Mechanisms invoked: **stimulus control**, **exposure and response prevention**, classical conditioning, habituation. He has publicly criticized the viral dark-room/no-eye-contact misreading.

**Sepah is largely right. The pop version is not his.** The name is the failure — "dopamine fasting" is marketing for *stimulus control + cue exposure*.

**The critiques.**
- Grinspoon, P. (2020), *Harvard Health Blog*: *"Dopamine does rise in response to rewards... [but] it doesn't actually decrease when you avoid overstimulating activities, so a dopamine 'fast' doesn't actually lower your dopamine levels."* And: *"The dopamine fasters are depriving themselves of healthy things, for no reason, based on faulty science."*
- Joshua Berke (UCSF): dopamine is not a "pleasure juice" with a depletable level.
- David Nutt (Imperial), *Guardian* 2019: *"Monks have been doing it for thousands of years. Whether that has anything to do with dopamine is unclear."*
- Peer-reviewed: Fei et al. (2022), *Lifestyle Medicine* 3(1), e54 — separates correct from incorrect interpretations, and flags that the **self-guided** nature could pose physical and emotional harm.
- ⚠️ **Nicole Prause** — I found **no** Prause critique of dopamine fasting specifically. Do not attribute one.

**⚠️ THE MOST IMPORTANT CORRECTION IN THIS DOSSIER.** Conklin & Tiffany (2002), *Addiction* 97(2), 155–167 — meta-analysis of 9 cue-exposure addiction treatment outcome studies. **Overall effect size d = 0.087, non-significant.** Their conclusion: *"there is no consistent evidence for the efficacy of cue-exposure treatment as currently implemented."* Since cue exposure is the mechanism Sepah invokes, this is a load-bearing weakness in the "evidence-based" claim. Caveats: 2002, only 9 studies, clinician-delivered substance-addiction ERP — and it does **not** evaluate stimulus control, which is separately and better supported.

**Net:** stimulus control = supported. Cue exposure as standalone treatment = meta-analytically ~zero. "Resetting dopamine" = not a thing.

## B.3 What Anna Lembke actually argues

*Dopamine Nation* (2021, Dutton). The pleasure–pain balance; "gremlins" hopping onto the pain side; neuroadaptation producing a "dopamine deficit state"; *"The smartphone is the modern-day hypodermic needle, delivering digital dopamine 24/7."*

- **The real science underneath is Solomon & Corbit (1974)** — cite that directly.
- **D2 downregulation:** genuine PET evidence exists — striatal D2 binding reduced **~15–20%** in chronic cocaine users (one [11C]raclopride study: 15.2% limbic, 15.0% associative, 17.1% sensorimotor). ⚠️ These figures came via secondary summaries of Martinez et al./Volkow et al.; verify before citing. **Critically: these are cocaine/meth/alcohol findings. There is no comparable evidence of striatal D2 downregulation from smartphone use.** Lembke's move from stimulant neuroimaging to "digital dopamine" is an analogy, not a finding.
- **The 30-day fast:** appears to be **clinical experience, not an empirical constant.** No study establishes a 30-day dopamine-receptor recovery timeline in humans for behavioral targets; where receptor-recovery data exist (meth, cocaine) timelines are **months**. The number is also suspiciously congruent with Dry January and the 28-day rehab model (itself an insurance artifact).
- **Critiques:** rigorous peer-reviewed neuroscientific critique is **thin** — the one academic review located (Raheemullah 2022, *Camb Q Healthc Ethics* 31(4)) is *favorable*. The substantive critique is journalistic (Meadows 2023, *Sluggish*), marshalling Nutt et al. (2015), *Nat Rev Neurosci* 16(5), 305–312 (*"Findings from studies investigating only stimulants… were often discussed as though they applied to all addictions, even though there was no evidence for such an assumption"*; alcohol, cannabis and ketamine do not reliably trigger dopamine release), Salamone, Peele, and Hart. **Lembke herself conceded in the NYT that attributing addiction solely to dopamine is an oversimplification.**

**Self-binding taxonomy (genuinely useful for product):** **physical** (space — barriers/distance), **chronological** (time — restrict to windows), **categorical** (meaning — bright-line rules about subtypes). Categorical is the interesting one for Lumo: bright-line rules ("no short-form video, long-form is fine") are easier to sustain than graded quotas because they eliminate negotiation with oneself.

## B.4 Attention research — with the real numbers, and three myths to stop repeating

**Attention residue.** Leroy, S. (2009), *OBHDP* 109(2), 168–181. Her own definition: *"the persistence of cognitive activity about a Task A even though one stopped working on Task A and currently performs a Task B."* Two lab experiments crossing **completion status** × **time pressure**. Findings: residue is higher when Task A is **unfinished**; **merely completing Task A was not sufficient** to eliminate residue; completing it **under time pressure** did reduce residue. The mechanism is **psychological closure, not literal completion.**
⚠️ Exact effect sizes are paywalled (Elsevier 403, no OA copy, abstract elided on S2/OpenAlex). Direction verified; **magnitudes not** — needs library access.

**⚠️ Citation correction: the "ready-to-resume" paper is Leroy & Glomb (2018), *Organization Science* 29(3), 380–397** — not Leroy/Schmidt/Madjar. Core mechanism: it is not the interruption per se, it is **anticipated time pressure on resumption**. Four studies (field survey N = 202; labs N = 66 and N = 44). The intervention is **~one minute** spent writing down where you left off and your planned next steps → significantly **reduced attention residue** and **preserved performance on the interrupting task**. ⚠️ They did **not** test whether it improves performance on the *original* task on return, and the lab Ns are small.

Also: Leroy & Schmidt (2016), *OBHDP* 137, 218–235 — residue is worse under a **prevention focus**, and diminishes when the interrupting task shares the same motivational frame (**frame mismatch is what hurts**). Leroy, Schmidt & Madjar (2020), *Academy of Management Annals* 14(2), 661–694 is the definitive review; (2021), *J Applied Psychology* 106(10), 1448–1465 (N = 249) found **a dedicated unshared workspace predicted fewer nonwork interruptions.**

⚠️ **The Zeigarnik foundation is shakier than assumed.** Ghibellini & Meier (2025), *Humanities and Social Sciences Communications*: *"We found **no memory advantage for unfinished tasks**… the **Zeigarnik effect lacks universal validity**."* The *resumption urge* (Ovsiankina) survives; the "unfinished tasks stay active in memory" folk story does not.

**Task-switching costs — the actual magnitudes.** Rubinstein, Meyer & Evans (2001), *JEP:HPP* 27(4), 763–797, four experiments:

| Measure | Value |
|---|---|
| Exp 1 mean switching-time cost (pattern classification) | **975 ms** |
| Exp 2 (arithmetic) | **653 ms** |
| Exp 3 | **614 ms** (SE 237), *t*(18) = 2.59, *p* < .05 |
| Exp 4 by condition | 502 / 675 / 492 / 769 / 1,430 / **1,733 ms** |
| Rule-complexity effect on switch cost (Exp 1) | high − low = **972 ms** (SE 51), *p* < .0001 |
| Task-cuing benefit | **−467 ms** (SE 278) |
| Complexity × cuing interaction | 45 ms → **additive** (separate goal-shifting and rule-activation stages) |

Costs are greater switching **familiar → unfamiliar**.

**Fragmentation and attention duration — the verified figures.**
- González & Mark (2004), CHI '04 (N = 14, 477 hours): ~3 min/event; **2 min 11 s** per device/paper; PC **2 min 52 s**; **working sphere segment 11 min 28 s**; 12.81 working spheres/person.
- Mark, González & Harris (2005), CHI '05 (N = 24, 2,246 segments): **11 min 4 s** (SD 18 min 9 s) in a working sphere before switching/interruption; **57.1% of segments were interrupted** (central 60.3% vs peripheral 41.7%, χ²(1) = 44.91, *p* < .001). Irony: interrupted segments lasted **longer** (12:40 vs 8:58, *F* = 26.14, *p* < .001).
- Mark, Iqbal, Czerwinski, Johns & Sano (2016), CHI '16 (N = 40, 2 weeks, objective Windows logging): **all computer usage mean 47.0 s, SD 21.4, median 40.2 s.** Email 61.8 s; productivity software 64.0 s; **272.7 daily switches between apps.** Neuroticism → shorter focus; **shorter focus → lower self-assessed productivity.**

**Interruption makes you faster and more stressed.** Mark, Gudith & Klocke (2008), CHI '08. N = 48, 3×2 (baseline / same-context / different-context × phone vs IM), interruptions every 2 minutes.

| Measure | Baseline | Same-context | Different-context | Test |
|---|---|---|---|---|
| **Time to perform task (min)** | **22.77** | **20.31** | **20.60** | *F*(2, 77.98) = 3.36, *p* < .05 |
| Errors | 1.94 | 1.93 | 1.84 | n.s. (*p* = .19) |
| **Stress (NASA-TLX)** | **6.92** | **9.46** | **9.13** | *F*(2,92) = **12.15, *p* < .001** |
| Frustration | 4.73 | 6.63 | 6.48 | *F* = 5.21, *p* < .007 |
| Effort | 9.50 | 11.04 | 11.52 | *F* = 8.50, *p* < .001 |

**Interruption *context* did not matter, and media did not matter. Any discontinuity costs the same.**
→ **Design implication: interrupted people don't lose time — they compress. Your throughput metrics will not show the harm. It shows up as stress and shortened output.**

**Physiological evidence.** Mark, Voida & Cardello (2012), CHI '12 — 5 days with **email cut off**. **HRV was higher (= less stress) without email**; longer window durations, fewer switches. ⚠️ **N = 13**, no order randomization, obvious expectancy confound. **There is no cortisol measure in Mark's published work** — if you see a cortisol claim attributed to her, it likely isn't hers.

### ⚠️⚠️ The finding that should most change Lumo's design

**Mark, Czerwinski & Iqbal (2018), CHI '18, Paper 92 — "Effects of Individual Differences in Blocking Workplace Distractions."** One week of software-blocked distractions (Freedom, 22 sites):
- ✅ Higher self-assessed **focused immersion** and productivity; **biggest benefit for those *less* in control of their work** (lower conscientiousness, "lack of perseverance").
- ❌ **Significantly lower enjoyment in work.**
- ❌ Significantly less **temporal dissociation** (less flow-like time distortion).
- ❌ **Users already high in self-control experienced HIGHER workload when distractions were blocked.**
- ❌ **They worked longer stretches without physical breaks — with consequently higher stress.**

**Blocking is not uniformly good. It backfires for high-self-control users and costs enjoyment for everyone. Distraction-blocking must be paired with enforced break prompts, and ideally targeted at low-self-control users.**

### The three numbers to stop repeating

1. **❌ "Task switching costs up to 40% of productive time."** **Not in Rubinstein et al. (2001).** Full-text search finds no "40%" and no productive-time claim anywhere in the paper. The source is **APA (2006, March 20), "Multitasking: Switching costs," apa.org**, attributed to **David Meyer** with **no cited study**, five years after publication. The same APA page also says costs may be "just a few tenths of a second per switch" — which contradicts its own headline. At 975 ms/switch you'd need ~1,500 switches in an 8-hour day to reach 40%. *If you need a defensible productivity number, use Buser & Peter (2012), Experimental Economics 15, 641–655 — randomized; forced multitaskers performed significantly worse, and so did subjects free to organize their own schedule.*
2. **❌ "23 minutes 15 seconds to refocus."** Traces to **Robison, J. (2006), Gallup Business Journal** — an *interview* with Mark, not a paper. The published figure (Mark, González & Harris 2005) is **25 min 26 s, SD 54 min 48 s, 77.2% resumed same day.** **And it measures elapsed time until you *return to the task*, not time to *recover focus*** — in between, people complete **2.26 other working spheres**. The SD is more than double the mean. The popular framing is a misreading.
3. **❌ "Willpower is a finite resource" (ego depletion).** Largely failed to replicate. Unrot leans on this. Do not.

**The 47-second trajectory.** 2016–2021 = **47.0 s, verified** (Mark et al. 2016, Table 1). **2004 ≈ 150 s is Mark's retrospective rounding** — the published 2004 figures are 2:52 (PC/event) and 2:11 (any device). **2012 ≈ 75 s is not in any published paper** — the fall-2012 dataset appears as CHI 2014 and CSCW 2015, neither of which reports an overall mean focus duration. **Cite the 2023 book *Attention Span* for the trajectory, and the 2016 CHI paper for the 47 seconds.**

## B.5 "Brain rot" — the honest verdict

**The term.** Oxford University Press **2024 Word of the Year**, **37,000+ public votes**, **+230% usage 2023→2024**. Shortlist: brain rot, demure, dynamic pricing, lore, romantasy, slop. Official definition: *"The **supposed** deterioration of a person's mental or intellectual state, especially viewed as the result of overconsumption of material (now particularly online content) considered to be trivial or unchallenging."* **The word "supposed" is Oxford's — OUP declined to assert the phenomenon is real.** Origin: **Thoreau, *Walden* (1854)**: *"While England endeavours to cure the potato-rot, will not any endeavour to cure the brain-rot, which prevails so much more widely and fatally?"* — a cultural critique, not a neurological claim. The 170-year continuity is itself evidence of a recurring moral-panic template.

### The headline meta-analysis, and why it's weaker than it looks

**Nguyen et al. (2025), *Psychological Bulletin* 151(9), 1125–1146** — k = 71, **N = 98,299**: cognition **r = −.34**; **attention r = −.38**; **inhibitory control r = −.41**; mental health r = −.21; body image and self-esteem **n.s.**

⚠️ The input studies are overwhelmingly **cross-sectional self-report**. An r of −.38 between "how addicted do you feel to TikTok" and "how distractible do you feel" is a correlation **between two self-perceptions**, not measured impairment.

Corroborating: Tang et al. (2026), *JMIR* 28, e82503 (k = 58, N = 96,676) — depression r = 0.24, anxiety r = 0.26; **key moderator: "problematic use" drove associations; routine usage showed minimal significant associations.** Counterweight: Zerrouk et al. (2026), *BMC Psychology* 14(1), 673 — problematic social media use × academic performance, pooled **r = −0.114, non-significant.**

### What the actual experiments show

- **Prospective memory is the one replicated experimental effect.** Chiossi et al. (2023), CHI '23 — N = 60 (**n = 15/cell**), 10-min interruption. TikTok cell PM accuracy **80.00% → 49.02%** (chance), drift rate 1.46 → 0.000. **Lexical-decision accuracy: all null.** ⚠️ A drop to chance from one 10-minute session at n = 15 with a fitted drift rate of *exactly zero* is a textbook small-sample inflation profile; no preregistration. Replicated by Barton & Smyth (2025), *Memory* 33(7) (N = 45) and Zhai et al. (2026), *Behavioral Sciences* 16(6), 904 — total across all four samples ≈ **275 participants**.
- **Fragmented vs continuous learning.** Wei et al. (2026), *npj Science of Learning* 11(1), 15 — N = 57 fMRI, duration- and content-matched. Short-video → poorer recall; reduced **claustrum, caudate, middle temporal gyrus** activity. ⚠️ **Not DMN, not dlPFC** — if you see a "TikTok shrinks your prefrontal cortex" claim, ask for the DOI; no such study exists.
- **The methodological high-water mark is about boredom, not cognition.** Tam & Inzlicht (2024), *JEP: General* 153(10), 2409–2426 — **seven preregistered experiments, N = 1,223**, the only preregistered work in this literature. Bidirectional: boredom prompts switching, and **switching then intensifies rather than relieves boredom**, reducing satisfaction, attention and meaning. ⚠️ Outcomes are self-reported affect — frequently miscited as showing attention damage.
- **⚠️ The null nobody cites.** Lin et al. (2024), CHI EA '24, "Understanding the Effects of Short-Form Videos on Sustained Attention" — **experimentally changing daily SFV duration did NOT significantly affect most sustained-attention tests**, even though their own survey reproduced the usual correlation.

**What does NOT exist** (searched explicitly): no randomized experiment measuring **sustained attention** (SART/CPT/vigilance) after SFV exposure; no experiment with a behavioral **delay-discounting** task; no experiment with **reading comprehension**; no DMN/dlPFC fMRI finding; **no longitudinal study measuring cognition with behavioral tasks** (all longitudinal work is two waves of questionnaires); essentially **no preregistration** outside Tam & Inzlicht.

**"TikTok brain" is not a scientific term.** It is journalistic (attributed to a WSJ piece by Julie Jargon, ~April 2022; ⚠️ exact citation unverified). Exactly **two** peer-reviewed papers use it as a formal construct, both cross-sectional Chinese student surveys — and in Ye et al. (2025) the construct is operationalized as **perceived mood enhancement** (sample item: *"I often need to watch short videos to make me feel happier"*), while the attention item reads *"**Since using short video apps**, I often get distracted…"* — **the predictor is embedded in the outcome item stem.**

### The skeptical counter-literature

- **Nikkelen et al. (2014), *Developmental Psychology* 50(9)** — 45 studies, media use × ADHD-related behaviors: pooled **r+ = .12** (~1.4% of variance).
- **Ra et al. (2018), *JAMA* 320(3), 255–263** — longitudinal, N = 2,587, 24 months. Per additional high-frequency digital activity **adjusted OR = 1.10 (95% CI 1.05–1.15)**; absolute rates 0 activities **4.6%** → 7 activities **9.5%** → 14 activities **10.5%** (n = 51 in that last cell). ⚠️ ADHD symptoms **self-rated**. Authors' own word: **"modest."**
- **Orben & Przybylski (2019), *Nature Human Behaviour* 3, 173–182** — specification curve across **N = 355,358**, "over 600 million possible ways to analyse the data." Technology use explains **at most 0.4% of variance** in wellbeing (β ≈ −0.04). Comparable to **eating potatoes**; **wearing corrective lenses is worse**; marijuana **2.7×** and bullying **4.3×** more negative; sleep and breakfast much stronger.
- **Orben & Przybylski (2019), *Psychological Science* 30(5)** — N = 17,247, **time-use diaries** rather than self-report: "little evidence for substantial negative associations," including before bedtime.
- **Przybylski & Weinstein (2017), *Psychological Science* 28(2)** — **preregistered**, n = 120,115: relationships are **quadratic**; "moderate use of digital technology is not intrinsically harmful."
- **Orben (2020), *Soc Psychiatry Psychiatr Epidemiol* 55** — review of 80+ reviews: *"the research field is dominated by **cross-sectional work that is generally of a low quality standard**"*; the association is *"on average—negative but very small"*; *"the direction of the link… is still unclear."*

### The pattern that settles it

| Measurement type | Typical effect |
|---|---|
| Self-report use × self-report attention | **r ≈ −.34 to −.41** |
| Self-report use × **behavioral** task | r ≈ −.28 to −.31 (digit span); one EEG index r = −.395 **with behavioral ANT outcomes null** |
| Meta-analytic screen time × ADHD behaviors | **r+ = .12** |
| Longitudinal, self-reported symptoms | **OR = 1.10** |
| Specification curve, wellbeing | **β ≈ −0.04, ≤0.4% variance** |
| **Randomized, behavioral** | only prospective memory, **n = 15/cell** |

**The effect shrinks by roughly an order of magnitude as measurement quality improves. That is the signature of a construct largely composed of self-perception and shared method variance.**

### Blunt verdict for Lumo

The causal evidence that short-form video damages attention is **weak to nonexistent** by the standard of randomized behavioral designs. What *is* defensible, and is enough:
1. **Rapid context-switching acutely impairs prospective memory** — remembering to execute a planned intention. Note this is **attention residue wearing different clothes**: the strongest SFV finding is not "TikTok shortens your attention span," it is *"rapid context-switching degrades your ability to hold an intention across an interruption."* That is far better supported and far more actionable — **and it is precisely the thing Lumo's core loop is designed to fix.**
2. **Fragmented video produces worse recall than matched continuous video** (one fMRI experiment, N = 57).
3. **Switching between videos increases rather than relieves boredom** (7 preregistered experiments, N = 1,223) — which is exactly the felt experience users describe.

**This is a strategic asset.** Unrot's funnel rests on causal claims it cannot support. Lumo can market to the *felt experience* — "you scroll for two hours and feel worse, not better" — which is rigorously explained by **wanting-vs-liking (Berridge & Robinson 2016)**, **opponent process (Solomon & Corbit 1974)**, and **Tam & Inzlicht's boredom spiral** — with **no** unsupportable brain-damage claims. More honest, more defensible under App Store health-claim scrutiny, and it describes what the user actually experiences.

## B.6 Premack — and why you should build Response Deprivation instead

**The original.** Premack (1959), *Psychological Review* 66(4), 219–233; Premack (1962), *Science* 136(3512), 255–257. Any behavior A reinforces behavior B if A's free-operant baseline rate exceeds B's. The 1962 paper already concedes the crack: probability ordering is **manufactured by deprivation** — depriving rats of running made running reinforce drinking, reversing the relation.

**The supersession.** Timberlake & Allison (1974), *Psychological Review* 81(2), 146–164; see Klatt & Morris (2001), *The Behavior Analyst* 24(2), 173–180. The **Response Deprivation Hypothesis**: reinforcement occurs **only when the contingency restricts access to the contingent response below its free baseline.** Probability ranking is irrelevant except as a proxy. A *lower*-probability behavior can reinforce a *higher*-probability one. **RDH subsumes Premack.**

**The formula you should literally implement.** Jacobs, Morford, King & Hayes (2017), *Behavior Analysis in Practice* 10(2), 195–208 — the disequilibrium model:

> **Reinforcement iff I / C > Oᵢ / O𝒸**  ·  **Punishment iff I / C < Oᵢ / O𝒸**
> where **I** = instrumental behavior required, **C** = contingent behavior granted, **Oᵢ** = free baseline of the instrumental behavior, **O𝒸** = free baseline of the contingent behavior.

Worked example from the paper: baseline 1.4 min reading (Oᵢ), 16.3 min math (O𝒸) → baseline ratio 0.086. Schedule chosen: 3 min reading → 2 min math (ratio 1.5), comfortably above baseline. **Their explicit warning:** they rejected an 8-minute reading requirement as "almost six times higher than his 1.4 min bout... which may result in Sam's behavior... coming to a stop just prior to accessing the contingent activity." That is **ratio strain**. Their heuristic: pick a ratio letting the reinforcer be earned **~4 times per 20-minute session**.

**And the consequence nobody builds for: setting I/C *below* the baseline ratio makes your contingency a *punisher*. A pricing table that is too generous is not merely weak — it actively suppresses the target behavior.**

**Applied evidence is thin.** Herrod et al. (2023), *Behavior Modification* 47(1), 219–246 — systematic review, ~24 studies, mostly small-N single-case; the review specifically assessed whether researchers implemented the theory correctly (most never measured free-operant baselines). **There is no meta-analysis of the Premack principle and no pooled effect size. Any "Premack effect size" in a competitor's deck is fabricated.**

## B.7 Contingency Management — the closest proven analogue to Lumo

**Founding trials.** Higgins et al. (1991), *Am J Psychiatry* 148(9), 1218–1224: retention 85% vs 42%; ≥8 wks abstinence 46% vs **0%**. Higgins et al. (1994), *Arch Gen Psychiatry* 51(7), 568–576 — the clean isolation of the voucher component (both arms got identical therapy): **75% vs 40% completed 24 weeks (p = .03); mean continuous abstinence 11.7 ± 2.0 vs 6.0 ± 1.5 weeks (p = .03).**

**Meta-analyses — report the range, not the best number.**

| Meta-analysis | k | Effect |
|---|---|---|
| Lussier et al. (2006), *Addiction* 101(2) — voucher, abstinence | 30 | **r = 0.32** (95% CI 0.26–0.38) ≈ g ≈ 0.60 |
| Prendergast et al. (2006), *Addiction* 101(11) — all CM | 47 | **d = 0.42** |
| Dutra et al. (2008), *Am J Psychiatry* 165(2) — CM subset | 14 | **g = 0.58** (largest of all psychosocial modalities) |
| Benishek et al. (2014), *Addiction* 109(9) — prize-based | 19 | **d = 0.46** end of treatment |
| NIDA EPT re-analysis | 42 | **g = 0.21** |

**Quote g ≈ 0.2–0.6, not 0.58.**

**The four parameters that determine efficacy** (Lussier moderator analyses, Griffith et al. 2000, SAMHSA):
1. **Immediacy** — "more immediate voucher delivery associated with larger effect sizes." Delay is the most reliably destructive parameter.
2. **Magnitude** — greater value → larger effect, *but with sharply diminishing returns* (see B.8).
3. **Frequency of monitoring/reinforcement opportunity.**
4. **Escalating schedules with a reset contingency** — voucher value escalates with each consecutive clean sample, milestone bonuses, reset on a miss, with a rule for re-earning the prior tier after N clean samples. **This is the empirically validated version of a streak.**

**⚠️ Durability — do not gloss this.** Benishek: end of treatment **d = 0.46** → ≤3-month follow-up **d = 0.33** → **6-month follow-up d = −0.09 (95% CI −0.28 to 0.10) — no detectable effect.** Ginley et al. (2021), *J Consult Clin Psychol* 89(1), 58–71 (23 RCTs, up to 1 year post): long-term abstinence **OR = 1.22 (95% CI 1.01–1.44)** — significant but barely. **Of 18 moderators tested, only one predicted durability: longer duration of active treatment.**

**Implication: retention is not just a business metric — it is the only empirically supported route to lasting change.**

## B.8 Temptation bundling, and what the megastudy really found

**Milkman, Minson & Volpp (2014), *Management Science* 60(2), 283–299.** N = 226, 9 weeks. Full treatment = addictive audio novels **physically stored at the gym** (hard commitment); intermediate = same novels on own device with encouragement (soft); control = $25 gift card.
- Week 1: full **+0.48 gym visits** (p < 0.01, ~51% over a 0.75 control baseline); intermediate +0.27.
- Weeks 1–7 mean visits: full **7.8** vs intermediate 6.5 vs control 6.1.
- **Durability: both effects decreased significantly over time and essentially vanished after Thanksgiving** — the authors attribute the collapse to holiday routine disruption.
- ~60% expressed positive willingness to pay at endline. ⚠️ verified only via secondary summary.

**The scale-up.** Kirgios et al. (2020), *OBHDP* 161(S), 20–35. **N = 6,792.** Audiobook + bundling encouragement raised weekly-workout likelihood **10–14%** and average weekly workouts **10–12%**, sustained up to **17 weeks post-intervention**. **But** relative to audiobooks alone, the bundling *instruction* had only a "modest positive effect" — most of the effect is the audiobook. And Kirgios tested the **soft** version. **The hard-commitment arm — the one Lumo actually implements — has never been replicated at scale. This is the single largest evidentiary gap for your design.**

**The megastudy.** Milkman et al. (2021), *Nature* 600(7889), 478–483. **N = 61,293**, 54 conditions, 4-week interventions, 10-week follow-up.

| Rank | Intervention | Effect |
|---|---|---|
| **1** | **Bonus for returning after a missed workout (125 pts ≈ $0.09)** | **+0.40 weekly visits (+27%)** |
| 2 | Higher incentives (490 pts ≈ **$1.75**/visit) | +0.37 (+25%) |
| 3 | Exercise social norms ("high and increasing") | +0.35 (+24%) |
| 4 | Bonus for returning after a miss (225 pts ≈ $0.16) | +0.34 (+23%) |
| 5 | Choice of gain/loss-framed micro-incentives | +0.28 (+19%) |

**The uncomfortable parts:** only **45%** of the 53 experimental conditions produced a significant increase during the intervention; **only 8% produced significant increases during weeks 5–14** (vs 2.5% expected by chance).

**Two gifts hiding in that table: (a) the single best intervention out of 53 was a bonus for coming back after a miss — recovery beats streak-maintenance; (b) it cost $0.09 and beat the $1.75 condition — magnitude saturates almost immediately.**

**Fresh start effect.** Dai, Milkman & Riis (2014), *Management Science* 60(10), 2563–2582 — aspirational behavior spikes after temporal landmarks (new week/month/year/semester/birthday). Use for **win-back**, not acquisition.

## B.9 Implementation intentions — and the deflation of d = 0.65

- Gollwitzer (1999), *American Psychologist* 54(7), 493–503.
- **Gollwitzer & Sheeran (2006), *Adv Exp Soc Psychol* 38, 69–119 — d = 0.65 across 94 independent tests, N > 8,000.** (The widely-cited exact N of 8,461 is **unverified**; cite "N > 8,000.")
- **⚠️ Lead with this one instead:** Sheeran, Listrom & Gollwitzer (2024), *Eur Rev Soc Psychol* 36(1). **642 independent tests including unpublished studies.** Effects **0.27 ≤ d ≤ 0.66**. From Gollwitzer's own co-authored paper: *"despite locating 642 tests of implementation intention effects including unpublished studies, **publication bias was substantial**."* A separate implementation-intentions meta-analysis saw the pooled effect drop from **0.36 to 0.15** after robust bias correction.

**Moderators — these are your UI spec.** Effects are larger when plans use a **contingent if-then format**, when participants are **already highly motivated**, and when plans are **rehearsed**.

**Budget d ≈ 0.2–0.35, not 0.65.** And note moderator #2: implementation intentions convert intention into action — **they do not create motivation.** Lumo must solve motivation separately.

## B.10 Habit formation — what "66 days" actually means

**Lally, van Jaarsveld, Potts & Wardle (2010), *Eur J Soc Psychol* 40(6), 998–1009.** 84 days of daily self-report (Self-Report Habit Index automaticity subscale).

**The attrition cascade is the story:** recruited **96** → 14 dropped out → **82** analyzable → 62 curve-fittable → **only 39 with acceptable/good fits.** Of the 62: 12 unfittable, **8 showed a flat line (no increase in automaticity at all)**, 16 poor fits, 7 implausible asymptotes.

- **Median to 95% of asymptote: 66 days. Range: 18–254 days.**
- **Exercise specifically: median 91 days** — ~1.5× longer, and **extrapolated beyond the 84-day observation window.**
- Curve is **asymptotic** — early repetitions buy disproportionate automaticity.
- **Missing a single day reduced automaticity by less than half a point and recovered quickly.**

**Never say "66 days."** It is the median of the **48% who fit the model**, on self-report, from N = 39, in a small young UK postgrad sample. Honest framing: *"for most people this takes two to eight months; for exercise, longer."*

**Wendy Wood's program.**
- Wood, Quinn & Kashy (2002), *JPSP* 83(6), 1281–1297 — experience sampling; **Study 1: 35% of behaviors habitual; Study 2: 43%.** Cite as *"roughly a third to a half."* The bare "43%" is Study 2 only.
- Wood & Neal (2007), *Psychological Review* 114(4), 843–863 — habits are **context-cued response dispositions** that accrue slowly and **do not shift appreciably with current goal states.** Habit change is about self-regulating **cuing**, not willpower.
- **Neal, Wood & Drolet (2013), *JPSP* 104(6), 959–975 — the strategic insight.** Because habit impetus is outsourced to contextual cues, habit performance doesn't consume self-control resources. When those resources are depleted, people **become locked into repeating their habits — depletion *increases* habit performance** — and **the cuing mechanism is blind to whether the habit is good or bad.** This is precisely the mechanism of 11pm doomscrolling, and it is the honest argument for why a pre-committed structural block beats a motivational nudge.

**Habit discontinuity — your best acquisition window.** Verplanken & Roy (2016), *J Environ Psychol* 45, 127–134 — a sustainability intervention was significantly more effective among households that had **recently relocated** vs matched non-movers. Context change (moving, new job, new school, new baby, retirement) breaks cue–response links and opens a deliberation window. ⚠️ Thomas, Poortinga & Sautkina (2016) find the window **narrows fast**.

## B.11 Commitment devices — including when they backfire

- **Ariely & Wertenbroch (2002), *Psychological Science* 13(3), 219–224.** People **will** self-impose costly deadlines; self-imposed deadlines **do** improve performance; but people set them **suboptimally** (externally imposed evenly-spaced deadlines beat self-imposed, which beat a single end-deadline). ⚠️ Could not retrieve the numeric tables — **do not quote specific numbers from this study.**
- **Giné, Karlan & Zinman (2010), *AEJ: Applied* 2(4), 213–235 — the best durability result in the whole dossier.** CARES smoking-cessation deposit contract. **Take-up 11%.** Effect at 6 months: **+3.3 to +5.8 pp** (ITT). Effect at **12 months, six months after the contract ended: +3.4 to +5.7 pp — persisting at full strength.** The distinguishing feature versus decaying CM effects is plausibly that the user's **own money** was at stake.
- **Schwartz et al. (2014), *Psychological Science* 25(2), 538–546.** Households staked an **existing 25% healthy-food discount** on a pledge to raise healthy purchases by 5pp/month. **Take-up 36% — 3× CARES** — plausibly because the stake was an *accrued benefit* rather than new money. Effect **+3.5pp**, sustained across all 6 months. Note: **people pledged 5pp and delivered 3.5pp — systematic over-commitment.**
- **Beshears et al. (2015), NBER w21474** — with equal interest rates, the **most illiquid** commitment account attracted the most money. Demand for hard commitment is real.

### ⚠️ When commitment devices backfire — the product-safety section

- **Bryan, Karlan & Nelson (2010), *Annual Review of Economics* 2, 671–698.** Only **sophisticated** present-biased agents pay to tie their hands. **Naïve** agents — who wrongly expect to resist — see no reason to. Since naïveté correlates with severity of the self-control problem, **the people who most need commitment devices are systematically least likely to adopt them.**
- **John, A. (2020), *Management Science* 66(2), 503–529.** N = 913, Philippines, self-designed installment-savings commitment with self-chosen penalties. **While the average effect on savings was large, 55% of clients defaulted and incurred monetary losses.** Her conclusion: commitment helps *fully* sophisticated agents but **likely harms partially sophisticated agents** — any naïveté leads people to select into contracts violating their own incentive constraints. **A majority chose a harmful contract.**
- **Carrera, Royer, Stehr, Sydnor & Taubinsky (2022), *Review of Economic Studies* 89(3), 1205–1244.** Gym commitment contracts. Take-up was high and exercise **did** increase. But: **~half of those who accepted a contract for *increased* attendance also accepted one for *decreased* attendance**; take-up showed **little association with actual or perceived time inconsistency**; and the structural welfare analysis found that offering the contracts **lowered consumer surplus** and was less efficient than a simple linear subsidy producing the same behavior change. **An intervention that demonstrably increased the target behavior still reduced welfare.**

## B.12 Self-Determination Theory and the overjustification effect — Lumo's biggest scientific risk

**Deci, Koestner & Ryan (1999), *Psychological Bulletin* 125(6), 627–668** — 128 studies. Exact numbers from the paper:

| Reward type | Free-choice intrinsic motivation | Self-reported interest |
|---|---|---|
| **Engagement-contingent** | **d = −0.40** | **d = −0.15** |
| **Completion-contingent** | **d = −0.36** | **d = −0.17** |
| **Performance-contingent** | **d = −0.28** | n.s. |
| All expected tangible rewards | **d = −0.25 to −0.28** | n.s. / small + |
| **All tangible rewards (composite)** | **d = −0.24** (CI −0.29, −0.19) | d = 0.04 (n.s.) |
| Unexpected tangible rewards | **d = 0.01** (n.s.) — no undermining | — |
| **Verbal praise / positive feedback** | **d = +0.33** (CI 0.18–0.43) | **d = +0.31** |
| Positive feedback, composite | **d = +0.36** (CI 0.25–0.48) | — |

**Read the pattern carefully — it is the entire design brief:**
1. **Tangible, expected, contingent rewards undermine intrinsic motivation. Lumo's coins are tangible, expected, and contingent. This is precisely the harmful cell.**
2. **Unexpected tangible rewards do not undermine (d = 0.01).**
3. **Verbal praise / positive informational feedback *enhances* (d ≈ +0.33).**
4. Undermining is **strongest for engagement-contingent** (paid just to participate) and **weakest for performance-contingent** (paid for a standard of excellence).

**The opposing camp and the resolution.** Cameron & Pierce (1994), *Rev Educ Res*, and Eisenberger & Cameron (1996), *American Psychologist* ("Detrimental effects of reward: Reality or myth?") argued the effect was largely an artifact. DKR 1999 was written explicitly as the rebuttal — that the Cameron & Pierce meta-analysis "was seriously flawed and its conclusions were incorrect." Current synthesis: **Cerasoli, Nicklin & Ford (2014), *Psychological Bulletin* 140, 980–1008** — a 40-year meta-analysis finding intrinsic motivation and extrinsic incentives **jointly** predict performance, with the key moderator being whether incentives are **directly salient** (tied tightly to the behavior — these crowd out intrinsic motivation and predict *quantity*) vs **indirectly salient** (loosely tied — these coexist with intrinsic motivation and predict *quality*).

**When extrinsic rewards HELP rather than harm** — the conditions Lumo must engineer for:
- The task is **initially uninteresting / intrinsic motivation is low** (true for cleaning, dishes, homework — *not* true for a hobby the user already loves).
- Feedback is **informational** rather than **controlling** in its framing.
- The context is **autonomy-supportive** — the user chose the goal, the task list, and the price.
- Rewards attach to **effort and process**, or to a **standard of excellence** (performance-contingent, d = −0.28, the least harmful tangible cell), rather than to mere participation (engagement-contingent, d = −0.40, the most harmful).
- Rewards are sometimes **unexpected** (d = 0.01 — no undermining).
- **Competence feedback** accompanies the reward.

**Reward fading.** The ABA token-economy literature and CM maintenance literature both support gradual thinning of reinforcement schedules — but recall Benishek's **d = −0.09 at 6 months**. Fading is a real technique; "the habit will carry itself afterwards" is not an evidence-backed promise.

## B.13 Gamification — what works, with numbers

### 🔴 The high-rigor subsplit — the single most important table in this dossier

**Sailer & Homner (2020), *Educational Psychology Review* 32(1), 77–112** (CC-BY):

| Outcome | All studies | 95% CI | k | **High methodological rigor only** |
|---|---|---|---|---|
| Cognitive | **g = .49** | [0.30, 0.69] | 19 | **g = .42, p < .01**, [0.14, 0.68], k = 9 — **holds** |
| **Motivational** | g = .36 | [0.18, 0.54] | 16 | **g = .22, p = .20**, [−0.11, 0.56], k = 7 — **NULL** |
| **Behavioral** | g = .25 | [0.04, 0.46] | 9 | **g = .27, p = .22**, [−0.16, 0.70], k = 5 — **NULL** |

Heterogeneity is large throughout (I² = 72.2% / 75.1% / 63.8%).

**Restrict to methodologically rigorous studies and the motivational and behavioral effects of gamification disappear. Those are exactly the two outcomes Lumo exists to move.**

**The moderators should determine your feature list outright:**

| Moderator (behavioral outcomes) | Result |
|---|---|
| **Game fiction / narrative** | Q(1) = 5.45, p < .05. **With fiction g = .49** [0.26, 0.73], k = 6 · **Without fiction g = .02** [−0.27, 0.30], k = 4 |
| **Social interaction** | Q(2) = 12.80, p < .01. **Competition alone g = .17** [−0.08, 0.42] **(n.s.)** · **Competition + collaboration g = .52** [0.23, 0.81] · **No social layer g = −.05** [−0.34, 0.25] |
| **Duration** (motivational) | Q(1) = 4.93, p < .05. **≤1 day g = .10 (n.s.)** · **up to half a year g = .58** [0.25, 0.91] |

**Naked competition is non-significant. No social layer is below zero. Only competition combined with collaboration works — and only where the design carries narrative.**

### 🔴 The health-gamification flagship does not survive its own bias correction

**Mazeas, Duclos, Pereira & Chalabaev (2022), *JMIR* 24(1), e26779** — 16 RCTs, N = 2,407:
- Headline after sensitivity exclusions: **g = 0.42** (0.14–0.69), I² = 74%. Unadjusted all-outcomes **g = 0.43 (0.03–0.82)**, I² = 86% — barely clears zero.
- **Steps specifically: g = 0.53 (−0.09 to 1.15), I² = 89% — NOT significant.** (The mean difference **+1,420.57 steps/day**, 435–2,406, *is* significant.)
- 🔴 **Excluding high/unclear risk-of-bias studies: g = 0.33 (−0.16 to 0.81) — not significant.**
- 🔴 **Trim-and-fill imputed 3 missing studies → bias-corrected g = 0.24 (−0.24 to 0.73) — NULL.**
- Median power **63%**; 7 studies under 45%; **4 under 18%**.
- Long-term (avg 14 wks post): **g = 0.15 (0.07–0.23)** — real but very small.
- 🔴 **vs. ACTIVE control (a non-gamified PA intervention): g = 0.23 (0.05–0.41), I² = 37%. This is the honest number for "what does the game layer add on top of a plain tracker" — and a plain tracker is Lumo's real comparator.**
- **Number of game mechanics: b = .01 (−0.17 to 0.19), P = .91.** Age, gender, BMI, duration all null too.

**Bai, Hew & Huang (2020), *Educational Research Review* 30:100322** — **g = 0.504 (0.284–0.723)**, 30 interventions, N = 3,202. **No significant moderation by game element type, number of elements, or research design.** *(Note: not "Educational Research and Reviews" — Semantic Scholar mislabels it.)*

**Two independent meta-analyses agree: piling on more mechanics predicts nothing.**

### The vote-count and quality reviews

**Hamari, Koivisto & Sarsa (2014), HICSS-47, 3025–3034** — 24 papers. Table 4, verified verbatim:

| Result | Papers |
|---|---|
| All tests positive | **2** |
| Part of tests positive | **13** |
| All tests not significant | **0** |
| Only descriptive statistics | **7** |

Of 22 quantitative studies, **only 2 found uniformly positive results and 7 reported no inferential statistics at all. Exactly one study in the review used validated psychometric measures.** Their own caveats are a checklist of what to avoid: tiny samples (~N = 20), no control groups, no isolation of individual mechanics, and *"experiment timeframes were in most cases very short (novelty might have skewed the test subjects' experiences in a significant way)."* And, critically for Lumo: 🔴 *"removing gamification might have detrimental effects to those users who are still engaged by gamification, possibly due to loss aversion from losing e.g. earned badges and points."*

**Dichev & Dicheva (2017), *IJETHE* 14:9** — the bluntest assessment in the field. Of 41 empirical studies, **only 15 present conclusive evidence** (12 positive, 3 negative); 🔴 *"the vast majority of the empirical works (25 studies) report inconclusive outcomes, which means that there is no basis for confidence in the reported results."*

**Johnson et al. (2016), *Internet Interventions* 6, 89–106** — 37 health/wellbeing assessments: 22 positive (59%), 15 mixed/neutral (41%), 0 negative. But **cognition was 8 positive vs 9 mixed — a coin flip**, and **user experience produced 2 outright negative (16%)**. Study quality: 42% weaker / 16% moderate / 42% stronger.

### 🔵 The novelty trough — plan your retention curve around this

**Rodrigues et al. (2022), *IJETHE* 19:13 — N = 756, 14 weeks, 7 measurement points.** The one good longitudinal test. The curve is **U-shaped**: *"the gamification's effect started to decrease after four weeks, decrease that lasted between two to six weeks... the gamification's impact shifted to an uptrend between six and 10 weeks, partially recovering."*

**Expect a trough beginning ~week 4, lasting 2–6 weeks, with partial natural recovery by weeks 6–10. Do not validate retention on a two-week pilot, and do not panic at week 5 — build a re-engagement moment there instead.**

### 🔴 Leaderboards actively harm

**Hanus & Fox (2015), *Computers & Education* 80, 152–161.** Two intact university course sections, 16 weeks, 4 survey waves. N = 80 (n = 71 completed all four). ⚠️ Quasi-experimental, not randomized — but baseline equivalence checked on 7 variables (all p > .05).

| Outcome | Result |
|---|---|
| **Intrinsic motivation** | Time × condition **F(1.89, 123.04) = 5.30, p = .007, partial η² = .08.** Control's motivation *rose*; the **leaderboard group's dropped and stayed significantly below control** |
| **Satisfaction** | **F(1.88, 124.07) = 6.74, p = .002, η² = .09** — leaderboard group dropped (4.10 → 3.51 → 3.57) |
| **Learner empowerment** | **F(1.71, 110.82) = 5.60, p = .007, η² = .08** |
| Effort | n.s., F(2,132) = 1.36, p = .27 |

**Mediation (PROCESS, 10,000 bootstraps): course type → intrinsic motivation a = −.30 [−.60, −.01]; motivation → final exam b = 4.59 [.41, 8.77]; indirect effect ab = −1.38, 95% CI [−4.38, −.05] — significant.** Authors: *"some common mechanics used in classroom gamification (i.e., competitive context, badges, and leaderboards) may harm some educational outcomes."*

Corroborating: **Kwon & Özpolat (2021)**, *INFORMS Trans. Education* 21(2) — gamified assessment produced *"significantly lower content knowledge, satisfaction, and course experience."* **Kirsch & Spreckelsen (2023)**, *BMC Medical Education* 23:268 — randomized cross-over, n = 48, **no learning effect**; *"the majority disapproved the competitive concept"*; recommends *"complex and collaborative programmes over simple and competitive ones."* **Thom, Millen & DiMicco (2012)**, CSCW '12 — removing IBM's internal point system *"did reduce overall participation"* (the empirical basis for the loss-aversion-on-removal warning).

**Element decomposition** — the two available studies agree on the key point:
- **Sailer et al. (2017)**, *CHB* 69, 371–380: badges/leaderboards/performance graphs → **competence**; avatars/story/teammates → **relatedness**; 🔴 *"Perceived decision freedom, however, could not be affected as intended"* — **no element supported autonomy.** ⚠️ Exact F/η² unverified.
- **Mekler et al. (2017)**, *CHB* 71, 525–534: points, levels and leaderboards increased **performance quantity but not intrinsic motivation or competence** — *"functioned as extrinsic incentives, effective only for promoting performance quantity."* ⚠️ Statistics unverified.

**Best RCT precedent for a Lumo-like design: Patel et al. (2019) STEP UP, *JAMA Internal Medicine* 179(12), 1624–1632.** N = 602, 24-week gamification + 12-week follow-up. During: competition **+920 steps** (513–1,328, P < .001), support +689, collaboration +637. **After the game stopped: competition +569 (142–996, P = .009) still significant; support +428 (P = .04); collaboration +126 (P = .49) — gone.**

### Loss framing — smaller than the textbook, but one design persisted

**⚠️ The magnitude is inflated in popular use.** **λ = 2.25** comes from Tversky & Kahneman (1992), *J Risk & Uncertainty* 5(4), 297–323 — and the Method section reads, verbatim: *"we recruited **25 graduate students** from Berkeley and Stanford (12 men and 13 women) with no special training in decision theory."* **The most-cited constant in behavioral economics is a median from 25 grad students on hypothetical choices.** The modern estimate: **Brown, Imai, Vieider & Camerer (2024), *Journal of Economic Literature* 62(2), 485–516 — 607 estimates from 150 articles, λ = 1.955, 95% probability interval [1.820, 2.102]. That interval excludes 2.25.** And Gal & Rucker (2018), *JCP* 28(3): *"current evidence does not support that losses, on balance, tend to be any more impactful than gains."*
**For coins — low-stakes, non-monetary, in-app — assume the multiplier is well under 2, possibly near 1.**

**Patel et al. (2016), *Annals of Internal Medicine* — N = 281, 7,000 steps/day, all three arms at identical expected value (~$1.40/day):**

| Arm | n | Goal-days achieved | Follow-up |
|---|---|---|---|
| Control | 70 | 0.30 (0.22–0.37) | 0.24 |
| Gain | 69 | 0.35 (0.28–0.42) | 0.25 |
| Lottery | 70 | 0.36 (0.29–0.43) | 0.23 |
| **Loss** | 70 | **0.45 (0.38–0.52)** | 0.30 |

Adjusted vs. control: gain +0.06 (P = 0.25); lottery +0.06 (P = 0.156); **loss +0.16 (0.06–0.26), P = 0.001.**
⚠️ **Steps: cite Table 4, not the abstract.** The published abstract prints an impossible CI (24 to 1,746 alongside P = 0.056). **Table 4 reports loss = 861 (−20 to 1,743), P = 0.056.** **All effects were gone at follow-up.** No differential attrition (≥95% completed; missing-data days: control 15%, gain 10%, lottery 18%, loss 13%).

### 🟢 ACTIVE REWARD (Chokshi et al. 2018) — the closest published analogue to Lumo, and its effect PERSISTED

*JAHA* 7(12):e009173. Mechanic: **"Each week, $14 was allocated to a virtual account; $2 could be lost per day for not achieving step goals"** — paired with **personalized goals ramping +15%/week from the user's own baseline**, capped at 10,000.

| Phase | Adjusted difference vs. control |
|---|---|
| Ramp-up | **+1,061 steps** (386–1,736), P < .01 |
| Maintenance | **+1,368 steps** (571–2,164), P < .001 |
| 🟢 **Follow-up, 8 weeks after incentives stopped** | **+1,154 steps** (282–2,027), **P < .01 — SUSTAINED** |

**Contrast with Patel 2016 (fixed 7,000-step goal → effects gone) and STEP UP (mostly gone). The two differentiating features are (a) a weekly house-funded virtual account with daily deductions and (b) personalized goals ramped from each individual's own baseline. That is a directly copyable spec — and note how exactly it converges with the response-deprivation logic in B.6.**

### The take-up wall, and the two evidenced ways around it

**Halpern et al. (2015), *NEJM* 372(22), 2108–2117.** N = 2,538.
- **Acceptance: reward-based 90.0% vs. deposit-based 13.7%, P < 0.001**
- ITT 6-month abstinence: **rewards 15.7% vs. deposits 10.2%, P < 0.001** (rewards win on ITT)
- **Per-protocol among acceptors: deposits 52.3% vs. rewards 17.1%, P < 0.001**
- **CATE vs. usual care: rewards +10.7 pp (6.8–14.7); deposits +30.8 pp (11.0–50.6)**

**Deposits are ~3× as efficacious per accepter and ~6.6× less likely to be accepted.**

**🟢 Escape hatch #1 — house money.** Halpern et al. (2018), ***NEJM*** 378(24), 2302–2310, N = 6,006. One arm used **"$600 in redeemable funds, deposited in a separate account for each participant, with money removed from the account if cessation milestones were not met"** — a loss frame where the participant risks nothing of their own. **Redeemable deposits 2.9% vs. rewards 2.0% vs. free cessation aids 0.5% vs. usual care 0.1% — best result in the trial, with no take-up penalty.**

**🟢 Escape hatch #2 — stake an already-granted benefit.** Schwartz et al. (2014), *Psychological Science* 25(2) — **36% acceptance** vs. 13.7% (Halpern) and 11% (Giné) for own-money deposits.

**⚠️ Psychological cost of loss framing is an open risk, not a finding.** A systematic search returned **zero** studies measuring stress/anxiety as a function of loss-framed incentive design. The dominant *measured* cost is **selection at the door** (13.7% vs 90.0%) — which in app terms surfaces as onboarding drop-off, not mid-stream churn. Claims that loss framing causes psychological harm are unsupported by direct evidence, which is not the same as false. One relevant null: **Chang et al. (2023), *DIGITAL HEALTH* 9 — adding financial incentives plus loss-aversion techniques to a mental-health app vs. the app alone (28 days): "no differences between treatment groups on app engagement or the change in the mental health/wellness outcome measures."**

**Goal-gradient and progress.** Kivetz, Urminsky & Zheng (2006), *Journal of Marketing Research* 43(1), 39–58:
- Café loyalty card: **interpurchase times decrease by 20% (0.7 days)** as customers approach the reward.
- **Illusory progress works:** customers given a **12-stamp card with 2 pre-filled "bonus" stamps completed the 10 required purchases faster** than customers given a plain 10-stamp card (this is Nunes & Drèze's endowed progress effect, *J Consumer Research* 32(4), 504–512, replicated here). Ruled out as sunk cost.
- **Tendency to accelerate toward the first reward predicts greater retention and faster re-engagement.**
- **⚠️ Post-reward reset:** "purchase and effort rates **reset (to a lower level) after the first reward is earned** and then reaccelerate toward the second goal." Expect a slump immediately after every milestone.

**Streaks — Duolingo's own A/B numbers, which are far smaller than the folklore suggests.**

| Change | Measured effect | Source |
|---|---|---|
| **Decoupling the streak from the daily XP goal** (streak = one lesson/day) | **+3.3% D14 retention, +1% DAU**; share of daily learners holding a streak rose from ~⅓ to **>50%** | blog.duolingo.com/improving-the-streak/ |
| New streak animations | **+1.7% D7 retention** (new learners) | Duolingo |
| Raising equipped Streak Freeze cap 1 → 2 | **+0.38% relative DAU** | Duolingo |
| **Friend Streak** (shared streaks, up to 5 pairs) | Users with ≥1 shared streak are **22% more likely to complete their daily lesson**; **57%** of users have an in-app friend; **⅓ of all DAU** have a Friend Streak | blog.duolingo.com/product-lessons-friend-streak/ |

**Read the magnitudes.** Duolingo's streak system — the most famous in software — is the product of **many sub-1% compounding wins**, not one transformative mechanic. Do not expect a streak to save your retention.

**⚠️ Two frequently conflated Duolingo statistics — cite them separately:** *"2.4× more likely to continue using Duolingo the next day"* (learners reaching a 7-day streak; **next-day retention**, the original 2020 figure) vs. *"3.6× more likely to complete their course"* (**course completion**). Different denominators, different claims.

**Mechanics as actually implemented:** Streak Freeze costs **200 gems / 10 lingots**, must be equipped *before* the miss, and is capped at **2 standard + 3 bonus at a 100-day streak = 5 max**. **Super and Max subscribers do NOT get unlimited or auto-equipped freezes** — a widespread misconception. Streak Repair costs **200 gems**.

**🎯 The single best validation of P1-7 in this entire dossier:** in **June 2026 Duolingo ran a win-back campaign letting anyone who had ever held a 30+ day streak restore it by completing 3 lessons in one sitting** — and called it *"one of the most consistent requests"* they hear from users. *(The Verge, 2026-06-01.)* **The market is telling you, loudly, that people want their streak back, not their streak protected.**

**⚠️ Two statistics circulating publicly are fabricated — do not use them:** the *"28% of gamified app users experience streak anxiety"* figure (traced to a content farm, no real source) and a *"5 million streak holders"* figure attached to Duolingo's Q3 2025 press release (the actual release contains no streak statistics; this is an AI-summarization artifact).

**Streak anxiety — the peer-reviewed citation.** **Hadi Mogavi et al. (2022), "When Gamification Spoils Your Learning: A Qualitative Case Study of Gamification Misuse in a Language-Learning App," ACM Learning@Scale 2022** — content analysis of **30,618 comments across 357 posts** plus 15 interviews. Full text: [arxiv.org/pdf/2203.16175](https://arxiv.org/pdf/2203.16175). It independently coins **"dark nudges of gamification"** and **"compulsion."** Participant quotes:
> *"I felt guilty about my abuse, and it wasn't just a normal sadness… This mood was killing my motivation for learning and [left me] paralyzed for weeks, eating me up from within."*
> *"My brother lost his 110-day streak, and now [he] is an abandoned account."*
> *"There are more rewards for 'playing' the app, rather than learning a language."*

And Duolingo's CEO says the quiet part aloud — **Luis von Ahn, TED2023: *"Some of the reminders are guilt-tripping, and it just turns out this works."*** and *"we've used the same psychological techniques that apps like Instagram, TikTok, or mobile games use to keep people engaged… we've made the broccoli taste like dessert."* ⚠️ Note: no major outlet has run a flagship "Duolingo dark patterns" investigation — the critique is real and academically documented but distributed. Don't claim an exposé exists.

**⚠️ The counter-argument that should shape your design.** In community discussions, streak-protection items are actively **defended by chronically ill and disabled users as accessibility features** — the same mechanic critics call exploitative is, for some users, the only thing that makes a streak survivable. **The lesson is not "no streaks." It is that forgiveness mechanics must be free and generous, not sold at 200 gems each.**

- **Snapstreaks:** Hristova, Jovicic, Göbl, de Freitas & Slunecko (2022), *Computers in Human Behavior Reports* 5, 100172 — praxeological interviews with N = 25 pupils aged 14–18; documents obligation and metacommunication around streaks.
- **The what-the-hell effect / abstinence violation effect** (Cochran & Tesser 1996; Marlatt & Gordon's AVE in relapse prevention): failing a goal or breaking a streak triggers guilt, then **doubling down on overindulging because "why the hell not."** This is the mechanism by which a harsh streak reset produces a binge, not a comeback.

## B.14 Behavioral Activation — "do the thing, then scroll" is BA

- **Ekers et al. (2014), *PLoS ONE* — BA for depression meta-analysis:** vs controls **SMD = −0.74 (95% CI −0.91 to −0.56), k = 25, N = 1,088, NNT 2.5**; vs medication **SMD = −0.42 (−0.83 to −0.00), k = 4, N = 283, NNT 4.27**.
  ⚠️ **Citation conflict, unresolved.** One extraction attributes a **BA-vs-CBT SMD = −0.35 (−0.59 to −0.11), k = 8, N = 273** to Ekers 2014; a second, independent check asserts **Ekers 2014 reports no BA-vs-CBT comparison at all**, and that the relevant figure is **Ekers et al. (2008), SMD = 0.08, n.s.** **Do not cite a BA-vs-CBT number until you have the PDF.** Note the two candidate values tell opposite stories (BA superior vs. BA equivalent) — and the *equivalence* reading is the one corroborated by Cuijpers 2007 (BA vs cognitive therapy = **0.02**) and by COBRA's non-inferiority design.
- **Cuijpers, van Straten & Warmerdam (2007), *Clinical Psychology Review*** — 16 studies, 780 subjects. Notably, **BA vs cognitive therapy = 0.02** (i.e., no difference), and vs other psychological treatments **0.13**. The simple behavioral component does essentially all the work.
- **COBRA trial:** Richards et al. (2016), *The Lancet* — large non-inferiority RCT; **BA delivered by junior, low-cost mental health workers was non-inferior to CBT delivered by experienced therapists**, and cheaper.

**Core BA components map directly to Lumo:** activity monitoring (habit log), activity scheduling (if-then plans + reminders), graded task assignment (start tiny, escalate), **values-based activity selection** (the Dopamine Menu, self-authored), and avoidance reduction (the whole point).

**This is Lumo's strongest and safest clinical framing** — far stronger than anything in the dopamine literature. "Do the thing, then scroll" is activity scheduling with a contingent reinforcer. BA has SMD ≈ −0.74 vs control and is non-inferior to CBT.

## B.15 Digital self-control tools — why screen-time apps fail

**Lyngs et al. (2019), CHI, "Self-Control in Cyberspace."** Reviewed **367 apps/extensions** (86 Google Play, 58 App Store, 223 Chrome), narrowed from 4,890 initial results. Framework: dual systems + **Expected Value of Control** (Reward × Expectancy × Delay).

Feature taxonomy — **note how lopsided it is:**

| Category | Share | Notable sub-features |
|---|---|---|
| **Block / removal** | **74%** | complete blocking 36%, remove UI elements 38%, friction to remove blocks 14%, time limits 6%, **loading delays 1%** |
| **Self-tracking** | 38% | usage history 29%, visualizations 20%, timers 20% |
| **Goal advancement** | 35% | goal setting 16%, concrete reminders 16%, goal-performance comparison 4% |
| **Reward / punishment** | **22%** | **points/streaks 11%**, leaderboards/social 7%, achievements 6%, **virtual creature 5%**, real-world reward/punishment 3% |
| Customization | 35% | user-defined "distraction" categories |

**Their identified gaps — this is Lumo's whitespace:**
1. **Habit scaffolding: only 18%.** *"The least frequently targeted cognitive component relates to scaffolding of new, desirable unconscious habits"* rather than merely blocking unwanted ones.
2. **Delay manipulation: 23% (4% excluding timers).** The authors call this *"surprising from a theoretical perspective, because the effects on behaviour of sensitivity to delay are strong, reliable"* — yet unexploited.
3. **Expectancy / self-efficacy: barely addressed at all.**

**Overall assessment: tools overwhelmingly prevent unwanted behavior (~73%) via blocking, leaving long-term habit change and confidence-building unaddressed.**

**Lyngs et al. (2020), CHI, "I Just Want to Hack Myself to Not Get Distracted."** N = 58 students, 6 weeks (baseline → intervention → post), Facebook.
- **Goal reminders** (Cgoal): daily time 27m14s → **15m5s** (p = .01, r = 0.63); daily visits 29.4 → **10.6** (p = .01, r = 0.63); scrolling **−42%** (p = .03, d = 0.62)
- **Removed newsfeed** (Cno-feed): visit duration 1m12s → 56s (p = .01, d = 0.75); scrolling **−73%** (p = .001, d = 1.11)
- **⚠️ The crucial dissociation: removing the newsfeed was the MOST effective and the LEAST liked** (caused fear of missing out); goal reminders were preferred initially but "often experienced as annoying." **What works and what users want are different things.**

**Monge Roffarello & De Russis (2019), CHI, "The Race Towards Digital Wellbeing."** Three-part study: review of 42 digital wellbeing apps + thematic analysis of **1,128 user reviews** + a **3-week in-the-wild study of Socialize with 38 participants.** Verdict: digital wellbeing apps *"are appreciated and useful for some specific situations, however, they do not promote the formation of new habits and they are perceived as not restrictive enough, thus not effectively helping users to change their behavior with smartphones."*

**Monge Roffarello & De Russis (2023), *TOCHI* 30(4), Article 53, "Achieving Digital Wellbeing Through Digital Self-Control Tools: A Systematic Review and Meta-Analysis"** (DOI 10.1145/3571810; 114 citations). Their meta-analysis found **a significant effect in only 7 of the analyzed papers**, and those were **short-term reductions in device usage time**. ⚠️ The exact pooled Hedges' g was behind the ACM paywall and could not be extracted — **obtain the PDF before quoting a pooled number.**

**⚠️ Lyngs et al. (2022), *IJHCS*, "The Goldilocks Level of Support"** (DOI 10.1016/j.ijhcs.2022.102869) — **334 DSCTs, 53,978 reviews scraped, 1,529 thematically analyzed.** The most useful commercial-signal paper in the field:
- **Tools combining ≥2 design-pattern types (e.g. blocking + goal reminders) received higher ratings than single-pattern tools.**
- Users want support that is **"just enough" to change behavior without being coerced** — the Goldilocks principle. Punishment that reads as failure backfires: *"I hate the fact that we get a destroyed building… I feel like it is too punishing and almost says 'you've failed'"* (SleepTown). **Note how directly this indicts Unrot's energy-draining buddy and Forest's dying tree.**
- Self-tracking alone is insufficient: *"It does not stop me spending 10 hours on Facebook but it does inform me."*
- **Starting a session is itself too high-effort** — one reviewer asked that focus sessions *begin with a break* before enforcement kicks in, to lower activation energy.
- 5% of reviewers had cycled through multiple tools.
- **iOS-specific:** at the March 2019 scrape, Apple's restrictive permissions meant **Apple Screen Time was the only option on iOS that could properly block apps**; third-party tools were limited to Safari websites, and users left angry reviews not realizing this (*"I thought the app would be linked to the apps on my phone I intended to block. So disappointed"*). Some tools resorted to telling users to set a random password on their social accounts and log out.

**Monge Roffarello, Lukoff & De Russis (2023), CHI, "Attention Capture Deceptive Designs"** (DOI 10.1145/3544548.3580729) — review of 43 papers, proposing a typology of **11 attention-capture damaging patterns (ACDPs)**. **This is your intervention target list** — an app that only counts minutes is fighting the symptom:

| | Pattern | | Pattern |
|---|---|---|---|
| P1 | Infinite Scroll | P7 | Playing by Appointment |
| P2 | Casino Pull-to-refresh | P8 | Grinding |
| P3 | Neverending Autoplay | P9 | **Attentional Roach Motel** (easy in, hard to leave) |
| P4 | Guilty Pleasure Recommendations | P10 | **Time Fog** (reduced time awareness) |
| P5 | Disguised Ads/Recommendations | P11 | Fake Social Notifications |
| P6 | Recapture Notifications | | |

Their proposed countermeasures are directly buildable: **surface estimated time investment** for new content (Medium's read-time) as the antidote to Time Fog; and **save-for-later** to defuse the urge to consume now.

**Grüning, Riedel & Lorenz-Spreen (2023), *PNAS* 120(8), e2213114120 — "Directing smartphone use through the self-nudge app one sec."** 719 iOS users recruited; **N = 280 completed 6 weeks**; plus a preregistered online experiment (N = 500).

Intervention = a full-screen pop-up combining (a) friction — a waiting time with a breathing animation (**~10 seconds, not one second**, despite the app's name), (b) a deliberation message, (c) an option to dismiss.

- **36%** — the **dismissal rate**: "in 36% of all attempts to open the target app, one sec leads to users closing this app again" (CI [0.35, 0.36], p < .001). *Conditional on an attempt already being made.*
- **37%** — the **reduction in attempts**: 166 attempts in W1 → 105 in W6 (p < .001). *A within-person trend.*
- **57%** — the **product of the two**. ⚠️ **This is not a causal treatment effect** — it is two uncontrolled within-subject trends multiplied together.
- Self-report: daily consumption **−77 min** (d = −0.56); perceived problematic consumption d = −0.70; happiness with own consumption **d = +0.81**.
- **⚠️ Decay:** dismissal rate W1 **43%** → W2 36% → W3 33% → W4–6 **32–34%**. The authors read this benignly (users triage the easy cases early); it is observationally indistinguishable from habituation.
- **⚠️ 61% attrition (719 → 280), and dropouts were systematically different** — they rated their use as less problematic and spent **27 more minutes/day** on target apps. The completers are the compliant, motivated tail.
- **⚠️ No control group in the field study.** The authors themselves call for a randomized controlled field trial.
- **Component decomposition (N = 500, preregistered):** overall d = 0.72 (video skipping), d = 0.68 (consumption time). **The option to dismiss was strongest — matching or exceeding the full intervention. Friction alone worked (d = 0.44). The deliberation message alone did NOT work. And the full three-feature condition UNDERPERFORMED dismiss-only** — the authors attribute this to cognitive overload and argue for "simplicity of the intervention."

### Friction: the dose-response evidence

- **Kim, Park, Lee, Ko & Lee (2019), CHI, "LocknType"** (DOI 10.1145/3290605.3300927) — N = 40, 3-week in-situ. A lockout task fires on target-app launch:

| Lockout task | App launches abandoned |
|---|---|
| **Pause only** (press one button) | **13.1%** |
| 10-digit number entry | *(intermediate)* |
| **30-digit number entry** | **47.5%** |

  **A clean dose-response. Even a trivial button press with zero cognitive load killed 13% of launches.** This is the most direct support for Lyngs's "delay is underexploited" finding.

- **Lu, Zheng, Zhang, Xu & Guo (2024), CHI, "InteractOut"** (DOI 10.1145/3613904.3642317) — N = 42, 5-week within-subject. **Implicit input manipulation** (subtly dampening swipes/gestures) vs. a traditional **timed lockout** baseline: **−15.6% additional usage time, −16.5% opening frequency, and +25.3% user acceptance** with less frustration. **Implicit friction beat explicit lockouts on efficacy AND acceptance simultaneously** — rare, since those usually trade off (cf. Lyngs 2020). Friction users *feel* provokes reactance; friction they merely *experience* does not.

- **Grayscale — the duration/frequency dissociation.** Holte & Ferraro (2020), *The Social Science Journal* (DOI 10.1080/03623319.2020.1737461), N = 161, 8–10 days: **−37.9 min/day** total screen time; social and browsing fell, **video did not**; **no effect on anxiety or depression**. Dekker & Baumgartner (2023), *Mobile Media & Communication* (DOI 10.1177/20501579231212062), N = 84: **−20 min/day**, improved perceived control and reduced stress — **but the number of unlocks did NOT change**, attributed to "deep-rooted checking habits." **Aesthetic friction shortens sessions; it does nothing to the checking impulse. Pick your metric to match your mechanism.**

- **⚠️ Notification batching — the most important "don't just block it" result.** Fitz, Kushlev, Jagannathan, Lewis, Paliwal & Ariely (2019), *Computers in Human Behavior* 101, 84–94 (DOI 10.1016/j.chb.2019.07.016). Randomized field experiment, **n = 237**, three arms: notifications as usual / **batched 3×/day** / **never**. Batched won on attentiveness, mood, sense of control, lower stress and fewer interruptions. **Notifications OFF "reaped few of those benefits, but experienced higher levels of anxiety and fear of missing out."** → **Total removal is worse than scheduled delivery. Any mute feature should default to a batched digest.**

### ⚠️⚠️ The most important negative result for Lumo

**Zhang, Lukoff, Rao, Baughan & Hiniker (2022), CHI, "Monitoring Screen Time or Redesigning It?"** (DOI 10.1145/3491102.3517722; open PDF at kailukoff.com). They built **Chirp**, a full Twitter client, and ran a **4-week within-subjects deployment, N = 31**, crossing two support types:
- **External supports = literally Apple's Screen Time model:** a usage-stats dashboard + a time-limit dialog after 20 minutes.
- **Internal supports = redesign the experience:** custom lists, a recommended-tweets blocker, and a reading-progress indicator showing you've exhausted new content.

| Finding | Result |
|---|---|
| Internal supports on sense of agency | **Significant. M = .83 vs .60, t(29) = 2.82, p = .009, d = .51** |
| External supports on sense of agency | **Not significant** |
| Passive dashboard vs. active time-limit nudge | Dashboard won: **t(29) = 2.76, p = .005, d = .5** |
| **Usage time, all four conditions** | **F(3,30) = .434, p = .73 — nothing moved the clock** |

The time-limit dialog **"backfired at times and undermined their sense of agency."** And the adoption killer, in the authors' words: participants said external supports *"would be more helpful for other people than for themselves… others might need help… But they went on to say that their own self-control makes such support unnecessary."* The authors tie this directly to documented reluctance to adopt and tendency to abandon screen-time tools.

Note the honest complication: some participants used Chirp **more** after custom lists were added, because the experience got better — *"[it] actually helped me personally with not using Twitter beyond the point where I can say I'm getting something out of it."* **Users valued quality and agency over quantity of time.**

### Screen-time RCTs — the honest ceiling

**Allcott, Braghieri, Eichmeyer & Gentzkow (2020), *AER* 110(3), 629–676.** N = 1,661 in the impact sample, paid **$102** to deactivate Facebook for **4 weeks** before the 2018 midterms.
- Facebook time **−59.58 min/day (−1.59 SD)**; **no displacement** to other apps; freed time went offline (time with friends and family +0.16 SD).
- **Subjective well-being: +0.09 SD.** The authors' own benchmark: standard psychological interventions deliver **0.34 SD**. **So the most aggressive possible intervention — total removal, for a month, paid — buys about 25–40% of what therapy delivers.**
- Costs: news knowledge **−0.19 SD**; political polarization **−0.16 SD** (an 8% reduction, ~42% as large as the entire 1996–2016 rise).
- Valuation: median WTA **$100**/4 weeks; deactivation **reduced** post-experiment valuations.
- **⚠️ THE CAVEAT THAT MATTERS MOST.** Post-experiment use index −0.61 SD; at one month, self-reported use was **−12 min/day (−23%)**. **But restricted to iPhone users reporting their *Settings-app* figure rather than a guess, the reduction is less than half as large — 8% of the control mean — and NOT significant (t = −1.16). The famous persistence result is substantially a self-report artifact.**

**Allcott, Gentzkow & Song (2022), *AER* 112(7), 2424–2463 / NBER w28936, "Digital Addiction."** *"Temporary incentives to reduce social media use have persistent effects, suggesting social media are habit forming. **Allowing people to set limits on their future screen time substantially reduces use**, suggesting self-control problems… people are **inattentive to habit formation** and **partially unaware of self-control problems**… **self-control problems cause 31 percent of social media use.**"* → Demand for commitment is *revealed*, not merely stated. And note the ceiling: **~69% of use is not a mistake by the user's own standard**, which is exactly why blunt blocking generates reactance.

**Brailovskaia et al. (2022), *JEP: Applied* (DOI 10.1037/xap0000430) — reduction beats abstinence.** **N = 619**; abstinence (7 days, n = 200) vs. **reduction (−1 hr/day, n = 226)** vs. control (n = 193), measured at baseline, post, **1 month and 4 months**. Both arms reduced problematic use, depression and anxiety and raised life satisfaction and physical activity — but **"most effects were stronger and remained more stable over 4 months in the REDUCTION group."** Conclusion: *"a complete smartphone abstinence is not necessary."*

**Plackett, Blyth & Schartau (2023), *JMIR* 25, e44922.** 2,785 studies screened → **23 included**. Notably a **narrative synthesis *without* meta-analysis** — the field's heterogeneity and quality did not permit pooling, which is itself a finding. **9/23 (39%) improved wellbeing, 7/23 (30%) mixed, 7/23 (30%) no effect.** By type:

| Approach | Studies showing improvement |
|---|---|
| **Therapy/skills-based (CBT techniques)** | **5/6 = 83%** |
| Abstinence | 3/12 = 25% |
| **Limiting use** | **1/5 = 20%** |

**"Limiting use" — the entire premise of this app category — has the weakest evidence base of the three. Skill-building has four times the hit rate.**

**Two more worth knowing:** de Hesselle & Montag (2024), *BMC Psychology* (DOI 10.1186/s40359-024-01611-1) — 14-day abstinence; depression, anxiety, FoMO and loneliness fell in **both** arms with no between-group difference, and **problematic smartphone use was NOT associated with screen time.** Hunt et al. (2018), *JSCP* 37(10) — the field's most over-cited study (936 citations): N = 143 UPenn undergrads, 3 weeks, 10 min/platform/day; loneliness and depression fell vs. control, **but anxiety and FoMO fell equally in both groups**, which the authors attribute to self-monitoring alone.

**⚠️ And the measurement problem that undermines much of the above:** Parry et al. (2021), *Nature Human Behaviour* 5, 1535–1547 (DOI 10.1038/s41562-021-01117-5) — meta-analysis of discrepancies between logged and self-reported media use. **Do not evaluate Lumo on self-reported screen time, and discount any study that does.** Brailovskaia is entirely self-report; Hunt used battery screenshots; Allcott's persistence result collapses under objective measurement.

**Plus the nudge-inflation problem:** Maier, Bartoš, Stanley, Shanks, Harris & Wagenmakers (2022), *PNAS* 119(31), e2200300119 — *"No evidence for nudging after adjusting for publication bias."* After bias correction, the pooled nudge effect is **indistinguishable from zero**. Read alongside DellaVigna & Linos (2022) at the top of Task B.

### Synthesis: why screen-time apps fail

1. **They monitor instead of intervening.** Roffarello & De Russis: DSCTs are "self-monitoring in nature where people need to figure out causes and solutions themselves."
2. **They target the wrong cognitive system.** Lyngs 2019: tools address System 2 (goals, awareness) while the behavior is System 1 (cue-triggered habit). Dekker & Baumgartner is the proof — grayscale cut duration 20 min/day but **left unlocks completely unchanged.**
3. **They ignore the strongest lever.** Only ~4% of 367 tools exploited **delay** — and when someone finally did it properly (one sec, LocknType, InteractOut) it worked.
4. **They block but don't build.** Only 18% scaffold new habits. Suppression without replacement doesn't survive removal of the tool.
5. **Effects decay within weeks.** one sec: 43% → 32–34% in three weeks. Most studies run ~21 days and never see it.
6. **Users experience reactance and think the tools are "for other people."** Chirp's time-limit dialog *"backfired… and undermined their sense of agency."* A product premised on "you lack self-control" collides with everyone's self-image.
7. **Removing everything backfires.** Notifications-OFF produced **higher** anxiety and FoMO than notifications-on; newsfeed removal was most effective *and* most FoMO-inducing; reduction beat abstinence at 4 months.
8. **Blocking is too blunt for real intentions.** Users' definitions of distraction are **feature-level, not app-level.**
9. **Screen time is the wrong metric.** Problematic use wasn't even correlated with screen time (de Hesselle & Montag); Chirp moved agency but not minutes, and users cared more about agency.
10. **The evidence base is contaminated by self-report** (Parry et al.), and the upside is genuinely small (**+0.09 SD** for total removal).
11. **They fail on reliability, not psychology.** As Task C shows, the largest cluster of 1-star reviews across *every* competitor is "it stopped blocking" / "it blocked the wrong thing" / "I couldn't delete it."
12. **On iOS the platform makes the bad design easy and the good design hard** — Apple ships the dashboard-and-limit pattern with no efficacy evidence behind it.

**⚠️ There is no credible randomized evidence that any screen-time app durably improves wellbeing.** The best field study of a friction app has no control group. The best RCT of the underlying behavior yields +0.09 SD. "Limiting use" worked in one study out of five. Build accordingly — and market accordingly.

---

# TASK C — Competitive & Market Analysis

## C.0 ⚠️ THREE FINDINGS TO READ BEFORE ANYTHING ELSE

### 1. "Earn Your Scroll" is Unrot's own tagline — you cannot use it

Unrot's App Store description **opens with the literal sentence**:

> **"Unrot: Earn Your Scroll. Do the thing. Then scroll."**

Their App Store subtitle is **"Complete habits, then scroll."** Naming your app **"Lumo: Earn Your Scroll"** would adopt the market leader's own headline phrase, from a company with **56,593 ratings** and an active trademark interest. This is an ASO problem (you will rank underneath them for your own name), a legal risk, and an App Review 4.1 (Copycats) risk. **Change the tagline.**

### 2. The name "Lumo" is already crowded, and "Luma: Earn Screen Time" already exists

App Store search for "lumo" returns: Lumo: A Muslim Friend (4.79, 701 ratings) · **Lumo AI by Proton** · Lumo Music · Lumo Campus · Lumo: Couple Tests · Lumo Wallet · Lumo Secure · LumoGo. And in your exact category: **"Luma: Earn Screen Time"** (YASIN ERTEKIN, released 2026-07-26) — one letter away.

### 3. The "earn screen time" category is not a gap. It is a gold rush.

A single App Store search surfaced **40+ direct competitors**, most launched in the last 12 months:

| App | Developer | Rating (count) | Released |
|---|---|---|---|
| **Unrot: Earn your Screen Time** | Unrot OÜ | **4.68 (56,593)** | 2025-06-04 |
| BePresent: Screen Time Control | Screen Detox Inc | 4.84 (60,640) | 2022-09-29 |
| ScreenZen | ScreenZen LLC | 4.86 (46,632) | 2021-07-16 |
| **Brainrot: Screen Time Control** | Smolworks Inc | 4.54 (18,867) | 2025-05-20 |
| ClearSpace | Clearspace Technologies | 4.74 (8,758) | 2021-07-24 |
| Unglue: Screen Time Friend | Computer go beep AB | 4.69 (2,670) | 2026-01-05 |
| Roots | MWM | 4.76 (2,409) | 2023-08-28 |
| Journey: Screen Time Control | Brain Nourishment LLC | 4.78 (1,921) | 2025-09-29 |
| PushUp App Blocker | Diego Martinez White | 4.68 (1,335) | 2025-12-10 |
| One Thing: Earn Screen Time | One Thing App Ltd | 4.74 (878) | 2025-09-16 |
| ReBrain: unrot your brain | Uliana Korolova | 4.53 (276) | 2025-07-31 |
| Blocus: Earn Screen Time | Diyar Dirik | 4.55 (226) | 2026-02-25 |
| WillStone | Ningbo Qunniao | 4.55 (195) | 2024-04-04 |
| Unrot Social: brainrot refocus | Corte Madera Apps | 4.78 (126) | 2026-03-26 |
| LockedIn: Earn Screen Time | Jonathan Scholl | 4.53 (120) | 2025-12-13 |
| Waddles: Unrot Your Brain | Inventive Otters | 4.68 (68) | 2025-09-06 |
| One Life - Earn Screen Time | Ship Odyssey | 4.66 (67) | 2025-10-15 |
| Wyzly: Screen Time Earned | NRCH'D Holdings | 4.83 (59) | 2025-06-05 |
| Achieve! Earn Your Screen Time | Golden Labs | 4.43 (42) | 2023-11-05 |
| Merite, SweatPass, Tonic, Piggy, Koia, ScrollTax, Peep, OctoPass, TimeTrader, Well Earned, Focus Cat, Lockee, EndTheRot, Unhook, Hurdle, GoalLock, BrainTime, Time Wallet, Derot, Giraffocus, Fit Scroll… | various | mostly <30 ratings | 2025–2026 |

Plus a dedicated **"walk to unlock"** sub-niche: WalkLock (4.54, 28) · Steps Unlock (4.20, 127) · Stepsy · StepLock · StrideGate · StepKey · BlockWalk · StepItUp · Need for Steps · WalkBy · Lockt · **Steppin: Steps for Screen Time (4.48, 140)** · Walk to Unlock Screen Time · **FeedFare** · plus adjacent rewards apps Sweatcoin (4.53, 393,075) and WeWard (4.87, 105,178).

**And it isn't only the long tail.** Two established players run real earn-to-unlock economies, which I initially missed:
- **Clearspace** (4.74, 8,758) — YC launch copy: *"Every pushup you do earns a minute of scrolling, **which you can use now or save for later**."* That is a banked currency.
- **Jomo** (4.77, 2,275) — its own help center documents doing the dishes → 15 min of YouTube; 5,000 steps → Netflix.

**So there are at least three credible competitors on your core mechanic, not one.**

**🎯 The actual whitespace: only Unrot has a *fungible* wallet** — one currency, earned from any habit, spendable on any app. Clearspace ties push-ups to minutes; Jomo ties specific tasks to specific rewards. A genuine general-purpose currency with per-user baseline pricing (P1-6) is still unoccupied.

### Market size and who is actually making money

- **Opal: ~$10M ARR with 11 people and ~1M DAU (2025).** 85,214 ratings, $99.99/yr.
- **Finch: ~$30M ARR, bootstrapped, on a virtual pet.** 735,553 ratings.
- **⚠️ The pet is the bigger business — roughly 3× Opal's revenue, with no blocking technology at all, no entitlement dependency, and no platform-bug exposure.** That is a strategically significant fact for a product deciding how much of its identity to stake on shielding.
- **⚠️ No category TAM exists.** Sensor Tower does not track "screen time apps" as a category. Any market size must be built bottom-up from individual app estimates.
- **⚠️ Unrot OÜ corporate detail:** incorporated **2025-05-16**; ownership 67% Peak Potential Labs OÜ / 33% Magnus Holm; **the Estonian register carries a pending dissolution notice on the entity.** Verify independently before drawing conclusions, but it is worth watching — the category leader may be less stable than its 56,593 ratings suggest.

**Strategic read: the mechanic is commoditized. Unrot won on execution, onboarding, and marketing — not on the idea. There is no first-mover advantage available. Differentiation must come from the things every one of these apps does badly (see C.4) and from the platform bugs none of them fix (see C.5).**

## C.1 Unrot — the direct inspiration, dissected

**Identity.** Unrot OÜ (Estonia). Released **2025-06-04**. Version **3.2.14** (2026-08-02). **192.5 MB.** Minimum **iOS 18**. Productivity. Rating **4.676 / 56,593 ratings**.

**Positioning copy (verbatim from the App Store description) — this is genuinely excellent and worth studying:**
> "Do the thing. Then scroll... Walk. Read. Lift. Clean your room. Do the dishes you've been ignoring since Tuesday. Real life earns coins. Coins unlock TikTok, Instagram, YouTube, games, or any apps you choose. No coins? The apps stay locked."
> "**Why blocking doesn't last.** Other apps say 'stop.' But stopping isn't the whole point. Getting your life back is. And blocking doesn't last anyway. Your phone is right there. One tap, and you're back. **Unrot gives you a trade instead** — A walk for TikTok — A study session for YouTube — A clean room for Instagram — A workout for whatever app keeps stealing your night."
> "**Your buddy.** A cute little guy that lives in the app. It grows when you do stuff. **It loses energy when you scroll too much.**"

**Mechanics:** timer habits · photo habits · focus sessions · app locking · app unlocking with coins · virtual buddy · streaks · a **28-day challenge with 12 challenges** and bronze/silver/gold medals.

**Pricing (IAP tiers observed):** $4.99 · $9.99 · $13.99 · $29.99 · $34.99 · $69.99. Users report the real offers as **~$10/week, ~$35/year, ~$70/year**. **Hard paywall, no free trial.**

**Review distribution (490-review US sample): 1★ 145 · 2★ 34 · 3★ 39 · 4★ 24 · 5★ 248.** Sharply bimodal — roughly **37% at 1–2 stars** in this sample against a 4.68 lifetime average.

**Complaint taxonomy (by volume):**
1. **The paywall — overwhelmingly dominant.** Dozens of near-identical reviews: *"paywall after 10 mins of set up, thanks for wasting more of my time"* · *"advertised as free multiple times just to tell you that you have to pay $10 a week/$70 a year"* · *"Should not be labeled on the App Store as 'free'"* · *"No free version. No free trial. This app was marketed in ads to be free."*
2. **Forced rating before the paywall.** *"STOP MAKING US RATE THE APP BEFORE TELLING US WE HAVE TO PAY"* · *"It just floods you with 5 star reviews until you get to the payment screen."* **This is very likely why the lifetime average is 4.68 despite ~37% recent 1–2★ — they harvest ratings pre-paywall. It is also an App Store guideline risk.**
3. **Can't uninstall / trapped.** *"Impossible to delete: The app hides the delete button and sends to a feedback form instead. Very shady practice and I'm pretty sure against App Store policies!"* · *"I forgot it wasn't free and I locked almost all my apps and I can't go back"* · *"in order to delete it, the screen time password is required."*
4. **⚠️ SAFETY: it blocked a medical app.** *"I am a type [1] diabetic and it would block my pump up and my [Dexcom] because I spent 30–40 minutes on it... I can die from that because that's my insulin."* **This is a catastrophic-risk category and a plausible App Store removal trigger.**
5. **Shaming onboarding.** *"the beginning of the app basically says that I came to the app because I felt guilt... Then I realize it cost money after it had demolished my confidence"* · *"Calls me fat"* · *"it was trying to rage bait me."*
6. **Mechanic friction:** no timer pause (*"cheating the system by allowing the timer to run in the background"*); **no retroactive logging** (*"If you forget to start an Unrot task in the app—and then want to mark later—you can't"*); **coins reset if the phone is off for 2 days**; blocks utility apps you need mid-task (*"not able to use my unblocked apps (i.e. calculator or ANKI when I have the study Unrot going)"*); *"receipts and cards"* UI adds social friction (*"When I want to give someone my Instagram... I now embarrassingly have to go thru this lengthy process"*).
7. **Onboarding layout bugs on small screens** (iPhone SE, iPhone 16): content taller than the viewport with no scroll, hard-blocking signup.
8. **Refunds denied.**

**⚠️ DEMOGRAPHIC BOMBSHELL: a large share of reviewers are children.** *"I am BROKE IM JUST 9 YEARS OLD"* · *"I'm only 10"* · *"I'm 12 I thought I could be better"* · *"my mom said she is not going to pay."* Unrot's App Store age rating is **4+/9+**. The people most drawn to this mechanic largely **cannot pay**, which explains both the review bimodality and the aggressive monetization.

**Most-loved (from 4–5★ reviews):**
- *"**This one is actually sustainable.** Had this app for over 8 months and I'm actually able to stick with it! Tried a whole bunch of similar apps but all of them were **too easy to bypass or too limiting/strict or frustrating**. This is just the perfect balance! It's cute and feels like a game!"* ← **this is the positioning bullseye for the whole category**
- *"the developer is constantly adding improvements and features based on suggestions that users vote on"*
- *"My screen time has gone from four hours to half an hour"*
- *"I finally have to do a workout before I can get on my phone"*
- **Unmet demand for coin sinks:** *"I just wish I could spend my coins on customization and new widgets"* — repeatedly requested.
- **Unmet demand for granular earning:** *"you could earn a coin for every 10 seconds you're able to hold a plank"*

## C.2 The screen-time blocker set

| App | Developer | Rating (count) | Core mechanic | Earn-to-unlock? | Pet? | Pricing |
|---|---|---|---|---|---|---|
| **Opal** | Opal OS Corp | **4.73 (85,214)** | Scheduled blocking, sessions, leaderboards, "real time data" | No (rewards/gems only) | No | Weekly $4.99/$9.99 · Monthly $19.99 · **Yearly $99.99** · Pro $49.99 · Student weekly $9.99 |
| **one sec** | riedel.wtf apps S.L. | **4.83 (23,308)** | **Friction: breathing delay + deliberation + dismiss option** before app opens | No | No | Year $19.99 · **Lifetime $99.99** · Family year $29.99 · Family lifetime $149 · **1 app free forever** |
| **ScreenZen** | ScreenZen LLC | **4.86 (46,632)** | Delay before opening, escalating wait, intention prompts, session interrupts, settings lock, streaks | No | No | **Free. Tips only ($5/$10/$20/$40).** |
| **Jomo** | Jomo | 4.77 (2,275) | Blocking + schedules + strict modes + habits | **✅ YES** — its own help center documents dishes → 15 min YouTube; 5,000 steps → Netflix | No | Monthly $5.99 · Annual $29.99 · **Lifetime $99.99/$84.99** · Family |
| **Brick** | Brick LLC | **4.94 (48,723)** | **Physical NFC tile** — tap to brick/unbrick | No | No | **$59 hardware, app free lifetime, no subscription** |
| **Clearspace** | Clearspace Technologies | 4.74 (8,758) | Blocking + **push-ups to unlock** + challenges + accountability partners | **✅ YES — a full economy.** YC launch copy: *"Every pushup you do earns a minute of scrolling, which you can use now or save for later"* | No | Monthly $6.99 · Annual $44.99 · $49.99/$59.99 · Family $79.99 |
| **Refocus** | Labi LLC | 4.76 (10,704) | Strict Mode (passcode/NFC/wait/copy-text/Pomodoro), schedules, location blocks, macOS app | No | No | $7.99–$9.99 · $49.99 · $59.99 |
| **Roots** | MWM | 4.76 (2,409) | Limits, downtime, "Monk Mode," balance score, challenges with a Chief Science Officer (Tj Power) | No | No | Weekly $7.99 · Monthly $9.99 · **Annual $59.99** · Premium $39.99–$99.99 |
| **Freedom** | Freedom | 4.4 (5,600) | Cross-device blocking via **VPN**, locked mode, sessions | No | No | Monthly $8.99 · Yearly $39.99 · **Forever $199** · 7 free sessions |
| **AppBlock** | MobileSoft | 4.59 (6,409) | Profiles, schedules, Strict Mode (level 2 prevents uninstall) | No | No | Monthly $4.99 · Yearly $29.99 · **Lifetime $89.99** · 7-day trial |

**Notable claims from listings:** one sec advertises *"app usage drops by 57% on average"* citing Max Planck collaborations (the Grüning PNAS study — see B.15; the 57% is the 6-week combined figure). Opal claims *"Save 1 hour and 23 minutes per DAY,"* *"94% less distracted,"* *"120 million hours saved."* Brick claims 55,000+ 5-star reviews, *"95%+ feel less distracted,"* survey of 3,500+ users; press in WSJ, NYT Wirecutter, FT, TechCrunch; **HSA/FSA eligible**.

**Direct earn-to-unlock competitors worth studying closely:**
- **One Thing (4.74, 878):** *"Pick one activity every morning... Until it's done, distracting apps stay locked. No willpower needed. The environment does the work."* One block only — top feature request is multiple blocks.
- **One Life (4.66, 67):** pick 3 tasks, difficulty tiers (Standard/Hard/Extreme), tasks convert to redeemable minutes, **emergency unlock** ("Life happens. Use it sparingly, keep integrity").
- **LockedIn (4.53, 120):** pixel-art, coins for habits, spend to unlock. **~$2/month or $20/year** — dramatically cheaper than Unrot. Explicitly cites the mechanic: *"This app uses a proven behavioral approach: Do something good → earn what you want."*
- **Blocus (4.55, 226):** the most feature-aggressive — **Extreme Mode (irreversible)**, unlock tasks including steps/workouts/push-ups/squats/planks/Pomodoro/**Sudoku or math**/location-based/**pay-to-unlock**, and **PIN Code Mode where a trusted friend holds the unlock code.**
- **Unglue (4.69, 2,670):** block → set goals → earn screen time by completing habits. Free tier = 3 tasks.
- **Brainrot (4.54, 18,867):** a **decaying brain avatar** ("watch your cute brain avatar decay as you doom scroll") — no earning economy. Cheapest tier in the category ($3.99/month, $19.99/year). One Unrot reviewer noted the two apps share *"a lot of identical animation."*

## C.3 Habit, pet, and gamified apps

| App | Rating (count) | Mechanic | Pet? | Pricing |
|---|---|---|---|---|
| **Finch: Self-Care Pet** | **4.95 (735,553)** | Self-care tasks power a bird; journaling, mood, "Adventuring" | **Yes — and it cannot die** | Plus ~$40–70/yr; tiers $5.99–$69.99; Guardian $7.99; generous free tier |
| **Forest** | 4.81 (48,919) | Plant a tree during a focus session; **leave the app and it dies** | Tree (loss-framed) | Monthly $5.99 · Annual $32.49–35.99 · crystals $0.99–21.99 |
| **Habitica** | 4.2 (3K listing) / **450-review sample: 1★ 71, 2★ 45, 3★ 64, 4★ 81, 5★ 189** | RPG: HP/XP/gold, parties, guilds, boss fights | Avatar + pets | $4.99/mo · $14.99/3mo · $29.99/6mo · $47.99/yr · gems |
| **Focus Friend (Hank Green)** | 4.72 (4,176) | Focus sessions earn decorations for a Bean's room; **"If you interrupt your Bean, they'll be really really sad"** | Yes (Bean) | — |
| **Flora** | 4.76 (82,453) | Forest-alike | Tree | — |
| **Duolingo** | 500-review sample: 1★ 73, 2★ 40, 3★ 36, 4★ 72, 5★ 279 | Streaks, XP, leagues, **energy system** | Duo | — |

### Finch is the most important app in this dossier

**Scale and retention:** ~**10 million MAU**, **54% D1 / 37% D7 retention** — comparable to Duolingo (51%/35%) and beating Royal Match (40%/25%). **735,553 ratings at 4.95.** In a 400-review sample: **1★ 14, 2★ 1, 3★ 11, 4★ 32, 5★ 342.** That is an extraordinarily healthy distribution — compare Unrot's 145 one-stars in 490.

**The design decision that produces it, stated plainly in its own materials:**
> **"Your bird never dies if you skip a day, which removes the guilt that makes many wellness apps feel like another source of pressure."**
> **"Your bird never dies, streaks never punish you, and missing a day costs you nothing."**

**Why it works (from teardowns and user testimony):** *"Many people struggle to do healthy things for themselves but will reliably do them for someone, or something, that depends on them."* It converts self-discipline into **care**. A user: *"I was bedridden for a while because of mental health things... something about taking care of this bird motivated me."*

**Four widget mechanics driving retention:** (1) **living pet presence** — the pet "experiences a life even while you're away," with the user's customizations visible in the widget; (2) **appointment mechanics** — "Adventuring," a timer-based absence that creates "organic return windows without constant nagging"; (3) a **progress bar** turning abstract self-care into visible movement; (4) **micro-events** — morning check-ins, evening chats, random friend visits, described as **"anti-nag."**

**Finch's criticisms (still useful):** limited habit-tracking depth (no streaks, no heatmaps, no analytics); gamification "can become a chore" once novelty fades; all-or-nothing goal completion with no partial progress; steep learning curve from feature density; **paid items gated aggressively** (*"Free users are earning the same points in the same way as any user on Finch Plus"* but get the worst shop rolls); **billing bugs** (*"'Annual' subscription charged 5x in three months at multiple price points"*); support unresponsiveness; and the emotionally devastating failure mode — *"I had a two year streak with my birb jelly and they suddenly logged me out and I never could get back in... Finch broke my heart I cried for days."*

**Forest's counter-lesson.** Forest is the loss-aversion version: *"I just can't let my sweet little trees die."* It works — 48,919 ratings at 4.81 — and it plants real trees (**2M+ via Trees for the Future** across Kenya, Senegal, Tanzania, Uganda, Cameroon). **But its 498-review recent sample is 1★ 145, 2★ 41, 3★ 31, 4★ 42, 5★ 239** — and virtually every 1★ is about **converting a paid app into a subscription and running ads on it**: *"I paid $10 back in the day, and now they're paywalling basic features that used to be free"* · *"Getting ads after buying pro subscription"* · *"punished its earliest supporters."* **Monetization changes destroy goodwill faster than any feature.**

**Habitica's failure modes:** complexity and learning curve; easy to game (self-report); *"Pay to win"* on pets/gems; long-open bugs (*"This bug has reportedly been open for years"*); widgets not updating; and a punishment mechanic users hate — *"How did the entire dev team think that stripping players of their LEVELS when dying to a boss was a good idea?? You punish EVERYONE."* Also, a telling ADHD review: *"there was no consequence for losing 'health'... I didn't feel like I was accomplishing anything by completing tasks, nor did I feel any sense of failure."* **Arbitrary points without real contingency don't work.**

**Duolingo's streak lessons:** streak freeze is a *retention* feature (doubling equipped freezes → **+0.38% DAU**), but the emotional cost of streaks is loud in reviews: *"It is mostly all about the streak in duo that just gets you bored"* · *"I hate to abandon my 2286-day streak"* · users rage-quitting over the new **energy system**: *"my battery thingy is empty... And then I hafta lose my progress, and wait a WHOLE other day."* **Introducing a resource that gates progress is the single most reliably hated mechanic in this whole review corpus.**

## C.4 The universal complaint taxonomy — every competitor, ranked

Across ~3,500 reviews sampled from 12 apps, the complaints are remarkably uniform:

| # | Complaint | Evidence |
|---|---|---|
| **1** | **Paywall placed after a long onboarding, with no free trial** | Dominant 1★ theme for Unrot, Unglue, One Thing, Roots, AppBlock, Clearspace, Jomo. Jomo: *"Enshi*tified onboarding and dark patterns... railroads you straight into payment."* |
| **2** | **It stopped blocking / blocked the wrong thing** | Opal (*"unlock timers are inaccurate"*), Jomo (*"I've been a paying customer for 51 weeks and am not renewing... wildly inconsistent"*), Roots (*"the time blocking option just doesn't let me into those apps at all"*), AppBlock (*"blocks apps that are not on any list"*), Freedom (*"disabled my Reminders App"*), One Thing (*"randomly blocks it after over 8-9 hours"*), LockedIn (*"It would lock me out even when I trade in for time"*), Clearspace (*"glitches multiple times a day"*) |
| **3** | **Can't delete the app / trapped by the Screen Time passcode** | Unrot, Opal (*"You cant delete this app??????"*), Roots (*"Deleting this app has been restricted because it needs a screentime passcode"*), Unglue (*"Dangerous: gives full access to screen time and won't let you delete the app unless you put in screen time passcode so if you forget…"*), Freedom, one sec (a Russian reviewer: *"one of the most dangerous applications I have ever installed"*) |
| **4** | **Trivially bypassable** | Freedom: *"Can be undone through screen time. Pretty much just like all the other blockers."* AppBlock: *"You can't prevent Face ID from unlocking these settings. So no matter what, you can bypass the blocking. DO NOT BUY."* Unglue: *"at anytime I could make the app usable again just by unrestricting them."* |
| **5** | **Updates that remove loved features or add lag** | Opal (*"5 second click delay"*, *"Too many meaningless updates"*), Brick (**6 of 6 critical reviews are about removing the timer feature**), Forest (subscription conversion), Duolingo (energy system), Unrot (*"receipts and cards"*) |
| **6** | **Exercise/photo verification doesn't work** | Clearspace: *"it sucks at detecting push-ups"* · *"I did 20 push ups and it's not logged"* · *"Every time I do a push-up it don't register"* (repeated many times). One Thing's AI verification: *"it throws unnecessarily disrespectful insults at you"* when it wrongly detects lying. |
| **7** | **Privacy/intrusiveness of photo proof** | One Thing: *"Im not sending this app a photo of the work that I am doing every time…it's confidential. Also not showing myself working out meditating etc. It's too intrusive."* |
| **8** | **Support is unreachable** | Finch, Freedom (*"emailing for MONTHS... the ticket expires and I have to start all over"*), Jomo, Clearspace (*"an option in the settings to call a founder, which goes to voicemail every time"*), ScreenZen |
| **9** | **Billing failures / refused refunds** | Roots (*"signed up for a trial and it still charged me"*, *"$110"*), Finch (5 charges in 3 months), Unrot (refund denied), Clearspace (*"that page within the app is forever 'loading' so that you can never cancel"*) |

**The #1 and #2 items are not psychology problems. They are pricing and reliability problems. The category's biggest opportunity is an app that simply works and doesn't feel like a scam.**

## C.5 Apple platform and App Review reality

**⚠️ Guideline 4.10 — Monetizing Built-In Capabilities — is the single biggest regulatory risk to this business model.** Verbatim:

> **"4.10 Monetizing Built-In Capabilities.** You may not monetize built-in capabilities provided by the hardware or operating system, such as Push Notifications, the camera, or the gyroscope; or Apple services and technologies, such as Apple Music access, iCloud storage, or **Screen Time APIs**."

Every subscription screen-time app in this category is operating in tension with this rule; Apple's enforcement has evidently been permissive so far (Unrot, Opal, Roots et al. are all live and subscription-gated). **But the plain text means Apple can enforce at any time**, and it strongly implies that **a hard paywall around Screen Time functionality is the most exposed possible configuration.** A free, working core with paid *non-Screen-Time* value (cosmetics, insights, coaching, cross-device sync) is materially safer.

**Guideline 5.5 — Mobile Device Management.** Added **2019-06-03**, five weeks after the NYT story, and still cited by App Review today:
> *"Because MDM provides access to sensitive data, MDM apps must request the mobile device management capability, and may only be offered by commercial enterprises, such as business organizations, educational institutions, or government agencies, and, in limited cases, companies utilizing MDM for parental controls."*

MDM sits behind the **Apple Developer Enterprise Program**, which requires organizational enrollment with a **D-U-N-S number** — individual/sole-proprietor accounts cannot enroll. **This is precisely why the Screen Time API exists, and why Lumo must be built on FamilyControls, full stop.**

**Guideline 2.5.1** — "Apps should use APIs and frameworks for their intended purposes." **Guideline 5.4 (VPN)** — relevant only if you later add system-wide *website* blocking; several apps (Freedom openly documents this) run a local loopback VPN profile for that, and 5.4's disclosure requirements are a common rejection trigger.

### ⚠️⚠️ The entitlement is a schedule risk, not a checkbox

`com.apple.developer.family-controls` (Distribution) is requested via [developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution) or the Capability Requests tab. Five facts that will affect your plan:

1. **The entitlement must be requested separately for EVERY bundle ID** — main app *plus each extension* (DeviceActivityMonitor, DeviceActivityReport, ShieldAction, ShieldConfiguration). Miss one and code signing fails even after the main app is approved. (Apple Developer Forums threads 701874, 735888)
2. **Only the Account Holder can submit.** Admin-level team members cannot.
3. **🔴 TestFlight is NOT a workaround.** Apple DTS engineer, verbatim: *"No. TestFlight uses a distribution provisioning profile, just like the App Store. If you only have access to an entitlement for development, you can't use it in any channel that requires a distribution provisioning profile."* **You cannot beta-test with real users until Apple grants the entitlement.**
4. **The Simulator does not work** — device-only testing (developer consensus, no Apple guarantee either way).
5. **No SLA. Reported waits run 1 week to 5 months.**

| Source | Reported wait |
|---|---|
| Forum 725036 | 1 week – 4.5 weeks approved; 6+ weeks still waiting (Feb 2025) |
| Forum 744094 | 33–36 days; 5 weeks; 6 weeks; 2+ months |
| Forum 701874 | "Typically 3 weeks," some **2–5 months** |
| Forum 806301 (Mar 2026) | Silence until escalated via a **paid** code-level support ticket |
| Forum 818553 (May 2026) | 13+ days, zero communication |

> *"Every week I contact apple support to request an update and every week I am told that **there are no SLAs** for processing requests for the Family Controls entitlement."*
> *"after investing months of work building an app I have now been completely blocked on getting it live for > 2 months."*

**The one documented rejection-and-recovery:** a developer was **declined after ~2 weeks**, resubmitted *"a more sincere and detailed application,"* and was approved ~2 weeks later. **Lesson: write a substantive justification — bundle IDs, which frameworks, exactly what gets shielded, concrete user benefit.** Apple publishes no checklist; a 2026 forum thread asking what materials prove eligibility has **zero replies**.

**→ Submit the request the day you have a bundle ID, and build the honor-system version while you wait.** This is exactly what the FeedFare developer described doing on Hacker News (March 2026): shipped on an honor system while awaiting approval, noting *"The documentation on what Apple actually wants to see is basically nonexistent."*

### 🔴 The API is genuinely broken — and this explains your competitors' reviews

From riedel.wtf's "State of the Screen Time API" and Apple Developer Forums thread 823431, with open Feedback numbers:

| Issue | Detail |
|---|---|
| **6 MB memory ceiling** on `DeviceActivityMonitor` | Enforced by Jetsam kill; unchanged since iOS 15. *"The DeviceActivityMonitor extension frequently crashes due to memory pressure… Even highly optimized implementations struggle to stay within the 6 MB constraint."* **FB22279215, FB23081099 — still Open** |
| **🔴 iOS unpredictably reissues `ApplicationToken`s** | **FB14082790 / FB18764644.** Independently reported by the developers of **ScreenZen, Jomo, AND Opal** in the same thread. When tokens rotate, saved blocklists silently break. **This is almost certainly the root cause of the Jomo "certain apps never block," Roots "stopped working after update," and Opal "would not lock" complaint clusters in C.4.** |
| **50-application-token shielding limit** | Hard cap. Past 50 shielded apps you must fall back to category-based blocking (documented in one sec's public troubleshooting). **Design your app-picker UX around this ceiling now.** |
| No API to return the user to your app from a shield | **FB15079668.** Developers resort to *"unreliable workarounds using local push notifications"* — the kind of trick App Review dislikes. |
| **No way to launch a target app from an `ApplicationToken`** | **FB15500695.** ⚠️ **Directly affects Lumo: "spend coins → open TikTok" cannot be a single tap.** |
| No way to enforce a Screen Time settings passcode from a third-party app | **FB18794535.** **You cannot fully close the bypass loophole** — cf. the AppBlock review: *"no matter what, you can bypass the blocking."* |
| **iOS 26 regression** | `DeviceActivityEvent.didReachThreshold` fired **immediately** instead of at the real threshold. Shipped in iOS 26 beta 1 (~June 2025), persisted through **iOS 26.4**, fixed only in **iOS 26.5 beta (~April 2026)**. |
| Misc | `FamilyActivityPicker` crashes on search (workaround: dictation/paste); shields fire for the wrong app when Screen Time syncs across multiple Apple devices; "Block all" ignores exemption lists; apps get stuck showing "Restricted"; battery drain is inherent to the API, not your code. |

**Also structural (verify against Apple docs before speccing):** `ApplicationToken`s are **opaque** — you cannot recover a bundle ID or app name, only render them via SwiftUI `Label(token)` where the *system* draws the icon and name. `DeviceActivityReport` renders inside a separate extension whose view your host app **cannot read from**, so **raw per-app minutes cannot be extracted into your analytics or a backend.** Any concept requiring server-side usage data or ML on usage patterns is dead on iOS. Conversely, `ShieldConfiguration` + `ShieldAction` extensions let you fully customize the block screen and its two buttons — **that is your intervention-moment canvas, and per B.15 it is exactly where the "explicit dismiss" affordance belongs.**

**🎯 Strategic read: your competitors are all eating one-star reviews for platform bugs they did not cause and never explain.** A token-rotation self-heal plus honest in-app disclosure of known iOS limitations is real, defensible differentiation — and it directly attacks complaint cluster #2 from C.4.

### The 2019 removals, fully sourced

- **NYT, Jack Nicas, 2019-04-27:** Apple **removed or restricted 11 of the 17 most-downloaded** screen-time and parental-control apps over the prior year. (347 points on HN, 241 comments.)
- **Freedom** pulled **August 2018** at 770,000+ downloads. Fred Stutzman: *"Their incentives aren't really aligned for helping people solve their problem… Can you really trust that Apple wants people to spend less time on their phones?"* Apple's response: it *"treat[s] all apps the same, including those that compete with our own services."*
- **OurPact** pulled **2018-10-06**, and publicly contradicted Apple: no prior communication (against Apple's 30-day-notice claim); MDM was *"the only API available for the Apple platform that enables remote management of applications"*; and **Apple had approved their MDM usage 37 times between 2015 and 2018.** Reinstated **2019-07-10**. Mobicip restored 2019-10-26.
- **Tim Cook, House Judiciary Antitrust Subcommittee, 2020-07-29:** *"We were worried about the safety of kids… These apps were using an enterprise technology that provided them access to kids' highly sensitive personal data."*
- **TechCrunch, 2021-06-07:** "Apple finally launches a Screen Time API for app developers" — explicitly the sanctioned replacement, with opaque tokens designed to stop *"a shady company from building a Screen Time app only to collect troves of user data."*

### Antitrust: one real judgment, and the DMA is a dead end

- **Russia (FAS) — the only fully litigated outcome anywhere, and it was about a parental-control app.** Kaspersky complained 2019-03-19 after Apple blocked updates to Kaspersky Safe Kids. FAS ruled abuse of dominance 2020-08-10, fined Apple **906 million rubles (~$12M)** on 2021-04-26, upheld twice on appeal, affirmed by Russia's Supreme Court 2023-06-09.
- **EU:** Kidslox + Qustodio filed an Article 102 complaint April 2019 and refused to withdraw it after Apple's guideline change. **No evidence the Commission ever opened a formal investigation.** Apparently shelved.
- **DOJ v. Apple (March 2024):** screen-time apps are **not** among the five pillars (super apps, cloud gaming, smartwatches, digital wallets, messaging).
- **⚠️ DMA — clean negative finding.** Apple's December 2024 DMA Article 6(7) interoperability white paper is entirely about **Meta's 15+ requests** (AirPlay, CarPlay, iMessage, App Intents, Continuity Camera, notifications, iPhone Mirroring, Bluetooth, Wi-Fi). **Screen Time, Family Controls, DeviceActivity, ManagedSettings and parental controls appear nowhere. Do not expect DMA relief to open this API.**

### Has Apple loosened anything? No.

At **WWDC 2026** Apple announced a substantial redesign of *consumer* Screen Time for iOS 27 — "Ask to Browse" per-site Safari approval, "Time Allowances" category budgets, contact approval, expanded Communication Safety. The two new developer frameworks (**PermissionsKit**, updated **SensitiveContentAnalysis**) are voluntary age/content-safety signal APIs for platforms like Instagram and Snapchat — **not** an expansion of FamilyControls/DeviceActivity/ManagedSettings. ⚠️ A blog claim of a *"Screen Time API 3.0"* with expanded third-party powers **could not be corroborated anywhere and should be treated as false.**

**Net: Apple is investing heavily in its own first-party Screen Time while the third-party surface stays frozen at its 2021 shape, bugs and all.**

---

# Evidence-Backed Design Principles for Lumo

Prioritized. Each is tied to the evidence above. **P0 = do before launch.**

## P0-1. Rename. "Earn Your Scroll" is Unrot's own opening line.
Unrot's App Store description literally begins *"Unrot: Earn Your Scroll."* Using it invites an ASO disaster, a 4.1 Copycats rejection, and a trademark letter. "Lumo" also collides with several live apps and is one letter from **"Luma: Earn Screen Time."** Pick a distinct name and tagline before you write another line of code. *(C.0)*

## P0-2. Ship a genuinely usable free tier. The paywall is the category's #1 killer.
**Recent 1★ rates, driven almost entirely by hard paywalls: PushUp Time 39% · Pushscroll 34% · AppBlock 32% · Unglue 31% · Unrot 30% · Forest 29%.** The reviewers self-identify as teenagers without money.

Against that: **ScreenZen is free with optional tips and holds 4.86 across 46,632 ratings** — the highest quality score in the category. **Finch is free and ad-free with a cosmetic-only paid tier and holds 4.95 across 735,553 ratings with 37% D7 retention, beating Duolingo — on ~$30M ARR.** one sec gives **one app free forever**.

And Guideline **4.10** makes a hard paywall around Screen Time functionality the most legally exposed configuration available. **Free: the full earn→unlock loop for a limited number of apps/habits. Paid: cosmetics, coin sinks, insights, multi-device, family.** *(C.2, C.4, C.5)*

## P0-3. Never trap the user. Deletion and emergency exit must always work.
*"Impossible to delete: the app hides the delete button and sends to a feedback form"* (Unrot) · *"Deleting this app has been restricted because it needs a screentime passcode"* (Roots) · *"one of the most dangerous applications I have ever installed"* (one sec). Ship a permanent, obvious **"Unlock everything and remove Lumo"** path that does not require a Screen Time passcode the user may not have. This is an ethical requirement, a review-score requirement, and an App Review requirement. *(C.4)*

## P0-4. Never block safety-critical apps. Hard-code an allowlist.
An Unrot reviewer: *"I am a type [1] diabetic and it would block my pump... I can die from that."* Permanently exempt Phone, Messages, Maps, Wallet, and — critically — **Health & Medical category apps (CGM, insulin, medication reminders)**, plus anything the user explicitly marks essential. Surface this prominently during onboarding as a trust signal. *(C.1)*

## P0-5. Submit the Family Controls entitlement request TODAY. It gates TestFlight.
**No SLA; documented waits of 1 week to 5 months.** You cannot beta-test with real users without it — Apple DTS, verbatim: *"TestFlight uses a distribution provisioning profile, just like the App Store."* And it must be requested **separately for every bundle ID**, main app plus each of the four extensions; only the **Account Holder** can submit. Write a substantive justification (bundle IDs, frameworks, exactly what gets shielded, concrete benefit) — the one documented rejection was recovered by resubmitting *"a more sincere and detailed application."* **Build the honor-system version while you wait**, as FeedFare did. *(C.5)*

## P0-6. Reliability is the product — and most of the category's bugs are Apple's, which is your opening.
Complaint #2 across every competitor is "it stopped blocking / blocked the wrong thing / I bought time and couldn't get in." **The root cause is now identified: iOS unpredictably reissues `ApplicationToken`s (FB14082790/FB18764644), independently reported by the developers of ScreenZen, Jomo *and* Opal.** When tokens rotate, saved blocklists silently break.
→ **Build a token-rotation self-heal and a blocklist integrity check on every launch.** → Respect the **50-token shield cap** in your picker UX. → Keep the `DeviceActivityMonitor` extension under **6 MB** (Jetsam kills it otherwise). → **Be honest in-app about known iOS limitations.** Every competitor eats one-star reviews for platform bugs they never explain; explaining them is cheap, differentiating, and true. *(C.4, C.5)*

## P0-7. Design the economy around what the API actually permits.
- **⚠️ "Spend coins → open TikTok" cannot be one tap** — there is no way to launch a target app from an `ApplicationToken` (FB15500695). Design the redemption flow around unshield-then-user-navigates.
- **You cannot read raw per-app minutes** — `DeviceActivityReport` renders in an extension your host app can't read from. **Per-user baseline pricing (P1-6) must therefore be built on threshold events and your own in-app logging, not on queryable usage durations.** Spike this before committing to the economy.
- **You cannot enforce a Screen Time passcode** (FB18794535), so the shield is a speed bump, not a wall. Per B.15 (Brailovskaia; Fitz; Lyngs) that is arguably the correct design anyway — but do not market it as unbypassable.
- `ShieldConfiguration` + `ShieldAction` are fully customizable. **That is your intervention canvas — and per B.15 it is exactly where the "explicit dismiss" affordance belongs.** *(C.5)*

## P1-6. Price coins off each user's measured baseline, not a global table.
This is the **single strongest theoretical foundation available and no competitor does it.** The disequilibrium model (Jacobs et al. 2017) says the contingency only reinforces when **I/C > Oᵢ/O𝒸**. So:
- Run a **3–7 day observation window** before the economy activates, logging baseline minutes on target apps (O𝒸) and baseline habit minutes (Oᵢ).
- Set the initial exchange rate **just above** the baseline ratio, then escalate slowly.
- **If unlock time exceeds baseline scroll time, you have built nothing** — there is no deprivation.
- **⚠️ And if I/C falls below the baseline ratio, your contingency becomes a punisher and will suppress the habit.** A too-generous price is worse than no app.
- Guarantee **multiple earn→spend cycles per day** (the tutorial's heuristic: reinforcer earned ~4× per session). Saving up for three days to buy one unlock will fail.
- **Watch for ratio strain.** Jacobs et al. rejected a requirement ~6× baseline as likely to cause the behavior to "come to a stop just prior to accessing the contingent activity." Ratio strain is your #1 churn risk. *(B.6)*

Internally, say **"response deprivation,"** not "Premack." It forces the right question.

## P1-7. Build the recovery mechanic before the streak mechanic.
Three independent literatures converge here:
- The **#1 intervention out of 53 tested on 61,293 people** was a **bonus for returning after a missed workout** — and at **$0.09** it beat the **$1.75** condition (Milkman et al. 2021).
- Lally et al. (2010): **one missed day costs <0.5 automaticity points and recovers quickly.**
- CM's validated schedule is **escalation *with* a documented re-earning rule** (Higgins).
- The **what-the-hell / abstinence violation effect** says a harsh reset produces a binge, not a comeback.
- Duolingo's streak-freeze data: doubling equipped freezes → **+0.38% DAU**.

And the market confirms it: **Duolingo's June 2026 win-back campaign let anyone who once held a 30+ day streak restore it with 3 lessons — they called it "one of the most consistent requests" they hear.** Meanwhile their actual streak A/B wins are **sub-1% to 3.3%** — the streak is a compounding-margins mechanic, not a growth engine.

**Design: streak pauses rather than resets; a comeback bonus fires on the next completed session; escalating coin value with a "re-earn your tier in 3 clean days" rule; and a permanent "restore your old streak" path for lapsed users.** Never zero someone out.

**⚠️ And make forgiveness FREE.** Duolingo charges 200 gems per freeze/repair and caps freezes at 5. Chronically ill and disabled users defend these items as *accessibility features* — which means monetizing them taxes exactly the people who need them most. **Free, generous forgiveness is both the ethical choice and, per the +0.38% DAU result, worth more as retention than as revenue.** *(B.7, B.8, B.10, B.13)*

## P1-8. Mitigate the overjustification effect deliberately — this is your biggest scientific risk.
Deci, Koestner & Ryan (1999) is unambiguous: **expected, tangible, contingent rewards undermine intrinsic motivation** (composite **d = −0.24**; engagement-contingent **d = −0.40**). Lumo's coins sit in exactly that cell. Mitigations, each tied to a number:

| Mitigation | Evidence |
|---|---|
| **Pair every coin award with informational competence feedback**, not just a number going up | Positive feedback **d = +0.33 to +0.36** on free-choice behavior, **+0.31** on interest |
| **Use performance/standard-contingent rewards, not engagement-contingent** — reward *doing the thing well or completing a real standard*, never mere participation | −0.28 vs −0.40 |
| **Sprinkle unexpected bonus rewards** | Unexpected tangible rewards: **d = 0.01, no undermining** |
| 🔴 **Do NOT assume virtual currency dodges this** | DKR 1999: **symbolic rewards undermined as much as concrete ones — d = −0.42 vs −0.44, Q_b = 0.03, n.s.** "It's only points" is not a defense |
| **Maximize autonomy support** — the user authors the task list, sets the prices, picks the blocked apps | SDT core; also Cerasoli et al. 2014 on indirectly-salient incentives |
| **Do not attach coins to activities the user already loves.** Reserve the economy for genuinely low-intrinsic-motivation chores (dishes, cleaning, homework) | Undermining requires pre-existing intrinsic motivation to destroy |
| **Make some habits explicitly un-monetized** — a "for its own sake" list that earns no coins | Prevents crowding out the user's existing intrinsic drives |

⚠️ **Do not promise "and then you won't need the app."** Benishek: **d = −0.09 at 6 months.** Be honest that Lumo is an ongoing contingency. *(B.7, B.12)*

## P1-9. Copy Finch's emotional architecture, not Forest's or Unrot's.
Finch: **4.95 across 735,553 ratings, 54% D1 / 37% D7, ~10M MAU** — the best retention in this entire dossier — with the explicit design rule **"your bird never dies, streaks never punish you, and missing a day costs you nothing."** Unrot's buddy, by contrast, *"loses energy when you scroll too much"* — a guilt mechanic. Forest kills your tree.

**The entire category chose punishment: Unrot's buddy loses energy when you scroll, Brainrot's avatar visibly decays, Rewired's brain reflects your "damage." Habitica proves punishment churns users *and* fails to motivate ("there was no consequence… I didn't feel like I was accomplishing anything"). Duolingo proves guilt works but generates documented compulsion (Mogavi et al. 2022, 30,618 comments) and a CEO quote that reads badly in a headline. Finch proves the opposite works better on every metric that matters.**

Reinforced by Lyngs et al. (2022) on 53,978 reviews: punishment that reads as failure backfires — *"I hate the fact that we get a destroyed building… it is too punishing and almost says 'you've failed.'"*

**Recommendation: a companion you *help*, never one you hurt.** Steal Finch's four widget mechanics: **living presence, appointment mechanics (timed "adventures" that create organic return windows), a progress bar, and micro-events** — explicitly designed as **anti-nag**. And note the repeated Unrot request: ***"I just wish I could spend my coins on customization and new widgets."*** **Cosmetic coin sinks are the most-requested feature, the safest monetization surface under Guideline 4.10, and — per Finch's ~$30M ARR on a free, ad-free, cosmetic-only model — demonstrably the bigger business.** *(B.13, C.3, C.5)*

## P1-10. Frame the whole product as Behavioral Activation, not dopamine.
BA is the strongest evidence base you can legitimately claim: **SMD = −0.74 vs controls (k = 25, N = 1,088, NNT 2.5)**, **non-inferior to CBT** in the COBRA Lancet trial, and effective when delivered by non-specialists. "Do the thing, then scroll" *is* activity scheduling with a contingent reinforcer. Its components map 1:1: activity monitoring, activity scheduling, graded tasks, **values-based activity selection**, avoidance reduction. *(B.14)*

## P1-10b. Blocking has documented downsides. Pair it with breaks, and segment by self-control.
**Mark, Czerwinski & Iqbal (2018), CHI '18** — a week of blocked distractions raised focused immersion **but**: significantly **lower enjoyment**, less **temporal dissociation** (less flow), **higher workload for users already high in self-control**, and **longer stretches without physical breaks, with consequently higher stress**. Benefits concentrated in users *less* in control of their work.
→ **Ship enforced break prompts alongside blocking.** → **Ask about baseline self-control at onboarding and dial strictness accordingly** — the users who need Lumo least are actively harmed by the strict tier. → **Track enjoyment, not just compliance.** This also dovetails with Mark, Gudith & Klocke (2008): interrupted people *compress* rather than lose time, so **throughput metrics will not reveal the harm — only stress and enjoyment measures will.** *(B.4)*

## P2-11. Make the Dopamine Menu the onboarding, and wire it to the economy.
Unrot built the right conceptual frame as a **detached web toy** and never connected it. Their own categories already encode the science: **"Sides — pair with boring tasks"** is temptation bundling; **"Desserts — guilty pleasures, in moderation"** is the Premack contingency. Make the menu the user's **self-authored earn-task list** (autonomy support → mitigates overjustification), keep the free no-signup web version as an acquisition asset, and add "when depleted, don't decide — just pick" as a **decision-fatigue** intervention. *(A.6, B.12)*

## P2-12. Force if-then grammar, and bind the trigger to the app-open attempt.
Contingent if-then format is a *measured moderator* (Sheeran et al. 2024). Build structured pickers producing a literal sentence: `WHEN [after breakfast / when I get home / 7pm / when I open Instagram] THEN I WILL [walk 20 min / read 10 pages]`. **"When I reach for TikTok, then I will read for 10 minutes first" is simultaneously an implementation intention and a response-deprivation contingency.** Replay the sentence verbatim on the shield screen (rehearsal is a moderator). **Budget d ≈ 0.25, not 0.65** — the 642-test meta-analysis found substantial publication bias. *(B.9)*

## P2-13. Friction is cheap and evidence-backed — and almost nobody builds it.
Grüning et al. (2023) *PNAS*: **36% dismissal rate, 37% fewer open attempts, 57% combined reduction over 6 weeks** (N = 280). Component decomposition (N = 500 preregistered): **the option to dismiss was strongest; the time delay also worked; the deliberation message did nothing.** Lyngs et al. (2019) found **delay manipulation in only 4% of 367 tools** despite delay effects being "strong, reliable."
**So: put a delay + a prominent "actually, never mind" button on the shield screen. Skip the motivational text — it measurably doesn't work.** And plan for decay: their dismissal rate fell 43% → 33% over three weeks. *(B.15)*

## P2-14. Build habit scaffolding, the category's biggest documented gap.
Lyngs et al. (2019): **74% of 367 tools block; only 18% scaffold new habits**; self-efficacy is "barely addressed." Roffarello & De Russis (2019, N = 38 in the wild): digital wellbeing apps *"do not promote the formation of new habits."* And the intervention review is decisive: **skill/therapy-based interventions improved wellbeing in 83% (5/6) of studies vs 20% for limiting use and 25% for abstinence.** Blocking is table stakes; the habit-building half is where the differentiation and the efficacy both live. *(B.15)*

## P2-15. Design around cues, and target habit-discontinuity windows for acquisition.
Wood & Neal (2007): habits are context-cued dispositions that don't shift with goals. **Neal, Wood & Drolet (2013): depletion *increases* habit performance and is blind to whether the habit is good or bad** — which is exactly why 11pm doomscrolling beats intention, and the honest argument for structural pre-commitment over motivation. Track **context stability** (same time, same place, same preceding action) as a first-class metric alongside completion. For acquisition, ask about recent life changes at onboarding: movers, new students, new jobs, new parents are in an open window (Verplanken & Roy 2016) — **but it closes fast.** *(B.10)*

## P1-8b. Ship FEW mechanics, and only the two with moderator evidence.
Two independent meta-analyses found element count predicts nothing (Mazeas **b = .01, P = .91**; Bai et al., no moderation by count or type). Against your real comparator — a plain tracker — gamification is **g ≈ 0.23**, and it goes **NULL** under trim-and-fill (0.24, CI −0.24 to 0.73) and under high-rigor restriction (motivational g = .22 p = .20; behavioral g = .27 p = .22).

**Ship the two things with actual moderator evidence:**
- **Narrative / game fiction** — behavioral **g = .49 with** vs **.02 without**. (Your companion character is this, if you give it a story.)
- **Competition *combined with* collaboration** — **g = .52**, vs **.17 for competition alone (n.s.)** and **−.05 for no social layer.**

🔴 **Do not ship a standalone leaderboard.** Hanus & Fox: intrinsic motivation, satisfaction and empowerment all declined significantly over 16 weeks, with a significant negative indirect effect on exam performance (**ab = −1.38 [−4.38, −.05]**). Kirsch & Spreckelsen: participants rejected competition outright. Kwon & Özpolat: gamified assessment *lowered* knowledge. **If you want social, use small teams, and cap the visible comparison set so nobody renders at the bottom.**

**And note what no gamification element achieved:** Sailer et al. (2017) found badges/leaderboards/graphs support *competence* and avatars/story/teammates support *relatedness*, but **"perceived decision freedom could not be affected as intended" — no element supported autonomy.** Autonomy has to come from your information architecture (self-authored tasks, self-set prices), not from a game layer. *(B.12, B.13)*

## P1-8c. Copy ACTIVE REWARD's structure — it is the only loss-framed design whose effect survived the intervention.
Chokshi et al. (2018): a **weekly house-funded virtual account** ($14/wk, $2 deducted per missed day) **plus personalized goals ramping +15%/week from the user's own measured baseline** produced **+1,154 steps eight weeks after incentives stopped (P < .01)**. Patel 2016's fixed 7,000-step goal: effects gone at follow-up. STEP UP: mostly gone.

**→ Grant a weekly coin allowance from the house, deduct for misses, and ramp targets from each user's own baseline.** This is simultaneously the loss-framing spec, the response-deprivation spec (P1-6), and the graded-task-assignment component of Behavioral Activation (P1-10). Three literatures converge on one mechanic. *(B.6, B.13, B.14)*

## P2-16. Stake accrued benefits, never money. Cap self-imposed severity.
Schwartz et al. (2014) got **36% take-up** by staking an *existing* discount vs Giné et al.'s **11%** for a cash deposit. **Translation: let users stake earned coins, streak tiers, and unlocked privileges — never their credit card.** This also keeps you out of gambling-adjacent regulation.

**🔴 And be precise about *which* coins you can put at risk.** Halpern 2015 is the wall: ask a user to risk something that is *theirs* and **five out of six walk away** (13.7% vs 90.0% acceptance). But the two escape hatches are well evidenced — **house money** (Halpern 2018: $600 in redeemable funds, best result in a 6,006-person trial, no take-up penalty) and **an already-granted benefit** (Schwartz 2014: 36% acceptance).
→ **Deducting from a weekly house-granted allowance is a designed, anticipated, reference-point-resetting mechanic. Clawing back user-earned coins or a 60-day streak is a betrayal and will read as one** — Hamari and Thom et al. both document that removing earned points harms your *most engaged* users specifically, via loss aversion.

**And actively protect users from themselves.** John (2020): **55% of clients defaulted on self-designed commitment contracts and lost money** — "a majority chose a harmful contract." Carrera et al. (2022): **~half of takers accepted contracts pointing the wrong direction**, and the contracts **lowered consumer surplus** despite increasing exercise. Ariely & Wertenbroch: people set deadlines suboptimally.
→ **Enforce maximum block severity, mandatory emergency unlocks (One Life's framing is good: "Life happens. Use it sparingly, keep integrity"), and a cooling-off delay before any strictness increase takes effect.** *(B.11)*

## P3-17. Instrument for harm, not just engagement.
Carrera et al. (2022) is the alarm bell: an intervention that **measurably increased the target behavior still reduced welfare**. Track failure rates, forfeiture rates, self-reported frustration, and rage-uninstalls as **first-class metrics with hard thresholds**. If >50% of users on your strictest tier are failing their own contracts, you have built John (2020), not Higgins (1994).

## P3-18. Win on scientific honesty — it is a real differentiator and a legal shield.
Unrot's content is ~60% defensible, ~25% over-claimed, ~15% wrong (RAS pseudoscience, ego depletion, unsourced "$200B," causal claims on an **N = 22 correlational PET study**). Market to the **felt experience** — "you scroll for two hours and feel worse, not better" — which is rigorously explained by **wanting-vs-liking (Berridge & Robinson 2016)** and **opponent process (Solomon & Corbit 1974)**. You do not need brain-damage claims, and avoiding them protects you from App Store health-claim scrutiny. Note Oxford's own definition of brain rot contains the word **"supposed."** *(A.7, B.5)*

## P3-19. Copy Unrot's content funnel, fix its claims.
Their arc converts: **absolve → name the enemy as design → one named mechanism → symptom checklist → free protocol → "willpower alone fails, you need a system" → product → CTA ×2.** The highest-leverage borrowable asset is the **onboarding self-assessment quiz** built from a symptom checklist — it creates a baseline the app can then show improving. **But do not shame.** Unrot's own reviews: *"it had demolished my confidence"* · *"Calls me fat"* · *"it was trying to rage bait me."* *(A.4, A.8, C.1)*

## P3-20. Small mechanics that reviews say are missing everywhere
Cheap wins, each drawn from a competitor's complaint list:
- **Pause a running timer** (Unrot's most-requested; users currently "cheat the system").
- **Retroactive logging** — "if you forget to start a task you can't mark it later" drives churn.
- **Don't block the tools the task needs** — a study session must not block the calculator or Anki.
- **No hard-gated resource that stalls progress** — Duolingo's energy system is the most hated mechanic in the entire review corpus.
- **Endowed progress**: start users with 2 of 12 stamps filled. Kivetz et al. (2006) — pre-filled cards were completed faster; interpurchase times fall **20%** approaching a reward. **And expect a post-reward slump** — rates "reset to a lower level after the first reward is earned."
- **Manual/photo verification must be forgiving.** Clearspace's push-up detector is its single biggest complaint; One Thing's AI verifier *"throws unnecessarily disrespectful insults"* at false positives. Never accuse a user of cheating.
- **Photo proof is a privacy liability** — One Thing: *"I'm not sending this app a photo of the work that I am doing every time…it's confidential."* Make it optional and on-device.
- **Fresh-start re-engagement**: trigger win-backs on Mondays, month starts, birthdays, New Year (Dai et al. 2014).

## Mechanics the science says will BACKFIRE — do not build these

| ❌ Don't | Why |
|---|---|
| **Streak resets to zero** | What-the-hell effect / AVE; Lally (a missed day costs <0.5 points); megastudy (comeback bonus was #1 of 53) |
| **A pet that decays, sickens, or dies** | Finch's no-death rule accompanies the best retention in the dossier (4.95, 735K ratings, 37% D7). Unrot's buddy "loses energy when you scroll" and Unrot has 145 one-stars per 490 reviews |
| **Shaming onboarding / guilt-based copy** | Directly cited in Unrot 1–2★ reviews as the reason for uninstalling |
| **Engagement-contingent coins** (paid just to show up) | The most harmful cell in DKR 1999: **d = −0.40** |
| **Coins on activities the user already loves** | Overjustification requires existing intrinsic motivation to destroy |
| **Over-generous exchange rates** | Below the baseline ratio, the contingency becomes a **punisher** (disequilibrium model) |
| **Large rewards** | $0.09 beat $1.75 in the megastudy; magnitude saturates immediately |
| **Real-money stakes / deposits** | 11% take-up (Giné); 55% default with net harm (John 2020); gambling-adjacent regulatory exposure |
| **Irreversible "extreme" modes without a safety valve** | John 2020, Carrera 2022; plus the "can't delete the app" complaint cluster that damages every competitor |
| **Hard paywall on core Screen Time functionality** | Category's #1 complaint **and** Guideline **4.10** exposure |
| **Deliberation/motivational text on the shield** | Grüning et al.: the deliberation message was **not effective**; the dismiss option and the delay were |
| **A standalone leaderboard / naked competition** | Hanus & Fox: significant declines in intrinsic motivation (η² = .08), satisfaction (η² = .09) and empowerment, plus a significant negative indirect effect on exam performance (ab = −1.38). Sailer & Homner: competition alone **g = .17, n.s.** Kirsch & Spreckelsen: participants rejected it outright |
| **A gamification layer with no narrative** | Sailer & Homner behavioral outcomes: **g = .02 without game fiction** vs .49 with |
| **Clawing back user-earned coins or streaks** | Halpern 2015: risking users' own stake collapses acceptance to 13.7% (vs 90.0%). Hamari and Thom et al.: removing earned points harms your *most engaged* users specifically |
| **More game mechanics for their own sake** | Mazeas: element count did **not** predict effect (b = .01, p = .91). Bai et al.: no moderation by element type or count. Habitica churns on complexity |
| **Judging retention on a 2-week pilot** | Rodrigues et al. (N = 756, 14 wks): the effect **troughs at ~week 4** for 2–6 weeks, then partially self-recovers by weeks 6–10 |
| **Claiming "66 days to a habit" or "23 minutes to refocus" or "willpower is finite"** | Median of the 48% who fit the model (N=39); actually 25m26s from a 2006 press interview; ego depletion failed to replicate |

## Honest expectations

- **Realistic efficacy:** against your real comparator — a plain tracker — gamification is **g ≈ 0.23**, and it goes **null** under both trim-and-fill (0.24, CI −0.24 to 0.73) and high-rigor restriction (motivational **g = .22, p = .20**; behavioral **g = .27, p = .22**). DSCTs show significant effects in only 7 papers, all short-term. one sec's 57% is a 6-week *combined* figure from a self-selected sample with no control group and visible decay. **Then divide by ~6 for the publication-bias/scale discount.**
- **⚠️ The two forces may cancel.** Gamification's behavioral benefit (g ≈ 0.23 vs active control) and the overjustification penalty (**d = −0.36** for completion-contingent tangible rewards, which is exactly what a coin is) are **comparable in magnitude and opposite in sign.** The net effect on intrinsic motivation for the target habit is plausibly near zero or negative even where the behavioral effect is positive. This is why P1-8's mitigations are not optional polish — they are what makes the mechanic defensible at all.
- **Your strongest evidence is not gamification.** It is **temptation bundling** (+51% gym visits, Milkman 2014; +10–14% sustained to 17 weeks at N = 6,792, Kirgios 2020), **Behavioral Activation** (SMD −0.74 vs control), and **ACTIVE REWARD's weekly-allowance-plus-ramped-goals design** (+1,154 steps 8 weeks *after* incentives stopped). Build the product story around those three, not around points and badges.
- **Durability is the hard problem, and nobody has solved it.** Only 8% of megastudy interventions persisted; CM decays to d = −0.09 by 6 months. The **one** moderator that predicted durability was **length of exposure** (Ginley 2021) — which makes retention the mechanism, not just the metric. The one strong persistence result (Giné et al., +3–6pp at 12 months) came from an **11% self-selected** group with **their own money** at stake.
- **You are entering a crowded market against an incumbent with 56,593 ratings** whose only real weaknesses are price, trust, and reliability. Those are the three things to beat them on.

## Verification debts before you publish anything externally
### 🔴 Published errors and non-existent papers — corrected here
- **Patel et al. (2016)'s published abstract contains an impossible confidence interval** — "24 to 1,746" alongside P = 0.056. **Cite Table 4: 861 (−20 to 1,743), P = 0.056.**
- **"Halpern et al. (2018), *JAMA Internal Medicine*, weight loss" does not exist.** You likely want Halpern 2018 ***NEJM*** (smoking deposits), Volpp 2008 ***JAMA*** (weight-loss deposits), or Patel 2019 ***JAMA Intern Med*** (STEP UP).
- **"Amir & Ariely on goal proximity" could not be located.** Do not cite.
- **Ekers et al. (2014) BA-vs-CBT** — conflicting extractions; see B.14. Get the PDF.
- **Bai, Hew & Huang (2020)** is in ***Educational Research Review***, not "Educational Research and Reviews" — Semantic Scholar mislabels it.
- **⚠️ Unretrieved 2026 corrigendum to Mehr et al. (2025), *OBHDP* 193:104477** — check it before citing that paper's N.
- **FDA General Wellness guidance** could not be retrieved and must be confirmed with counsel before any health-adjacent marketing claim.

### ⚠️ Fabricated statistics circulating publicly — never use these
- **"28% of gamified app users experience streak anxiety"** — traced to a content farm, no real source.
- **"5 million Duolingo streak holders" (Q3 2025 press release)** — the release contains no streak statistics; an AI-summarization artifact.
- **"one sec won an Apple Design Award"** — actively disconfirmed; it does not exist.
- **"Screen Time API 3.0" at WWDC 2026** — uncorroborated blog claim; treat as false.
- **"$200 billion/year Big Tech engagement spend"** (Unrot) — unsourced.
- **"Journaling trains your reticular activating system"** (Unrot) — pseudoscience.

### Sources to obtain
- **Roffarello & De Russis (2023) TOCHI pooled effect size** — paywalled, not extracted. Get the PDF (DOI 10.1145/3571810).
- **Allcott, Gentzkow & Song "Digital Addiction"** — the 31% figure is from the abstract; get the full paper, it is your best market-thesis citation.
- **Leroy (2009) and Leroy & Schmidt (2016) exact effect sizes** — paywalled at Elsevier, abstracts publisher-elided, no OA copy. Direction verified, magnitudes not. Needs library access.
- **Milkman 2014 WTP figures** and **Ariely & Wertenbroch numeric results** — secondary sources only; **do not quote numbers.**
- **Gollwitzer & Sheeran exact N** — cite "N > 8,000," not 8,461.
- **Volkow/Martinez D2 downregulation percentages** and **Nutt et al. 2015 quotes** — via secondary summaries only.
- **Allcott et al. (2020) wellbeing effect magnitude** — abstract only; the ~0.09 SD figure is from memory of the literature, **verify before citing**.
- **Christopher Ferguson's meta-analytic effect sizes** and the **Haidt vs. Odgers/Przybylski debate numbers** — not retrieved (search budget exhausted). Ferguson's consistent published position is r < .10.
- **Publication-bias testing (funnel/Egger)** could not be verified for any of the three short-form-video meta-analyses.
- **WSJ "TikTok brain" (Jargon, ~April 2022)** — exact title/date unverified, paywalled.
- **iOS API structural constraints** (opaque tokens, unreadable `DeviceActivityReport`, 6 MB extension ceiling) — sourced from developer reports and framework documentation, **not confirmed against Apple's live docs in this session. Spike before speccing the economy** (C.5).
- **Clearspace's raise** ($500K vs ~$800K, aggregator-sourced), **Brick's revenue**, **Opal's Google Play numbers**, the **EU Kidslox/Qustodio complaint disposition**, and **Duolingo Max annual/family pricing** — unresolved rather than guessed.
- **Unrot OÜ pending dissolution notice** — from the Estonian register; verify independently before relying on it.
- **Gloria Mark's per-year attention figures** — only **47.0 s (2016)** is verified in a paper. **~150 s (2004) is retrospective rounding** (published: 2:52 PC/event, 2:11 any device) and **~75 s (2012) is in no published paper.** Cite the 2023 book for the trajectory.
- **"Ludic loop"** — not verified as a term inside Schüll's book. **"40%" and "23:15"** — confirmed *not* to be in any peer-reviewed paper (see B.4).
