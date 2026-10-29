# Frontend design fundamentals

These apply to every treatment, from an admin table to a launch page. SKILL.md's studio stance and process sit on top of them; where the two seem to disagree, the precedence below decides.

## Respect what already exists

Look for an existing design system first: CLAUDE.md, a tokens or theme file, existing component styles, the component library the project already uses. When one exists, apply it; everything else in this skill fills gaps and never overrides. Precedence is always the user's own words, then the project's existing system, then your choices.

- Use the system's tokens, never a value the system already names: `var(--space-md)` or `spacing-md`, not `16px`; the brand color's token, not its hex. A value the system lacks becomes a new token in the system's own format, not a one-off literal.
- Before adding a component, check whether an existing one covers the need or can take a new variant. A near-duplicate splits the system.
- Inside an existing product, consistency beats creativity: the product's identity is the identity, and a new screen should look like it was always there. The distinct-identity stance applies to the axes the user and the system leave free.
- Add a library only when it does substantial work for the page; in an existing project, use the stack it already depends on.

## Decide the treatment

Designing is a given; the treatment is the decision. A doc gets the same craft as a landing page; only the treatment differs.

Many requests call for a utilitarian treatment: a plan, a memo, a doc, a demo, a dashboard, an internal tool, a settings screen. Make it polished, with real typographic hierarchy, considered spacing, and a proper palette, but avoid over-designing. Most pages don't need a flashy, gigantic hero. Keep flourishes tasteful and limited.

Some requests call for an expressive treatment: a landing page, a game, an app or tool people will keep or share. There SKILL.md's stance applies in full: opinionated choices, and aesthetic risk where it is justified. Match complexity to the vision: maximalist directions need elaborate execution; minimal directions need precision in spacing, type, and detail.

If unsure: a well-composed page is always acceptable; an over-designed visual identity sometimes isn't.

SKILL.md's token plan applies to both treatments; its review of the plan for generic defaults matters most for expressive work. Whatever the treatment, include at least one detail only this subject would have (its real units and scales, its document conventions, its terms of art) as content rather than ornament; it costs nothing even on a plain page. Use real content throughout and never lorem ipsum.

## When the page is a UI (dashboard, tool)

It is scanned and operated instead of read top to bottom, so the craft shifts from typography to information design.

- Put the summary before the detail.
- Encode state in form as well as in numbers (a pill, a chip, a severity stripe) so that whatever needs attention is visible at a glance.
- Semantic color (good / warning / critical) is separate from the accent hue and doesn't count as your accent.
- Interactive elements should look interactive.
- Open with big-number tiles only when those figures are the point of the page.
- Border, fill, radius, and shadow each mark an element as a separate object. Apply them by role, to set off the element that needs it; the same treatment on every block flattens the hierarchy.

## Make the page complete at rest

Everything meant to be read is visible once the page has loaded, with no scrolling to trigger it; that first still frame is what a thumbnail, a shared link, and a skimming reader all see. A section may animate in, but from a visible resting state, never left at `opacity: 0` waiting for an observer. Size a hero to its content instead of to the viewport; a `100vh` opener pushes the rest of the page out of that first frame.

A tool or app opens in a realistic working state: the user's real data where it exists, otherwise example rows, a loaded sample, or a plausibly filled form, clearly marked as examples and never presented as the user's own figures. The first view shows what the tool does; an empty shell waiting for input shows nothing. When data arrives asynchronously, the first frame renders before it does: make that frame a designed loading or empty state that names what will appear and how to add the first entry, then fill it.

## Design both themes

New UI follows the viewer's OS theme unless the project is single-theme (precedence) or the design deliberately commits to one visual world. Structure the CSS at the token level:

- The bare `:root` block declares every token with the light palette (for a dark-first design, swap light and dark consistently through this pattern).
- `@media (prefers-color-scheme: dark)` redefines only the tokens.
- If the product has a theme toggle, an explicit choice must override the OS in both directions: guard the media block as `:root:not([data-theme="light"])` and redefine the tokens again under `:root[data-theme="dark"]`, using whatever attribute or class the project already uses. The default "system" state sets nothing, so it is the one most viewers see.
- Wherever the dark palette applies, set `color-scheme: dark` so native form controls and scrollbars follow it.

Style components through the tokens, never directly inside a media or theme block: a color defined only inside a theme block never applies in the other state, and the page then shows one theme's text on the other theme's background. Set `body`'s `background` explicitly from a token (a transparent body shows whatever is behind it, such as an embedding host). Every element that sets a color takes it from the same token set as the surface behind it, never from a literal that works in only one theme. Give the second theme the same care as the first: don't simply invert it; keep contrast legible and keep the accent working on both backgrounds. A design that stays single-theme still sets the background and every color explicitly, by choice, never by omission.

## Color and type details

- A pure mid-grey looks unconsidered; a grey with a slight hue bias toward the page's accent looks intentional. Pure white and near-black are fine backgrounds when chosen, not inherited.
- If the accent clashes with the background, shift it toward an analogous hue or desaturate it instead of replacing it.
- A webfont that fails to load (blocked host, wrong URL, a weight that was never requested) falls back silently. Declare a real fallback stack and confirm the intended face actually rendered.
- Give headings `text-wrap: balance`. Use `font-variant-numeric: tabular-nums` wherever digits line up in columns.

## Layout

- Lay out sibling groups with flex or grid and `gap` instead of per-element margins, which collapse or double without warning.
- Keep a side gutter of at least 16px at every width, set once on `body` or one outer wrapper (where colored bands span the width, on each band's inner wrapper).
- Let rows wrap or stack to one column at phone width (about 400px). Give images and any `aspect-ratio` box `max-width: 100%`, and don't give anything a `min-width` wider than the screen. Only wide tables, code, and diagrams may exceed it; give each `overflow-x: auto` on its own container so the page body never scrolls sideways.
- A page that opts into `viewport-fit=cover` must keep content clear of the phone's system bars: write the gutter as `padding-left: max(16px, env(safe-area-inset-left, 0px))` (and the same for the right), let anything fixed to a screen edge add that edge's inset to its padding, and give a sticky header `top: env(safe-area-inset-top, 0px)`.
- A one-screen app avoids `100vh`, which on mobile browsers is taller than the visible area; use `100dvh` or `height: 100%` on `html` and `body`.
- Make repeated elements consistent: cards in a row, label/value pairs down a list, or badges on sibling items share edges, baselines, and inner padding, and a recurring element sits in the same place on each. Let content set a container's height and pick a column count the items fill, so nothing stretches over empty space or sits alone in a row.
- Text that can outgrow its track wraps or scrolls in its own container; clipped text is a bug.
- Watch for overlapping elements. For generative or decorative graphics, use Canvas or WebGL instead of hand-writing long SVG path data.

## States and edge cases

Build and check every state, not only the default a mockup shows: default, hover, focus, active, disabled, loading, error, empty. Then push the content: minimum and maximum content (one item and several hundred; a two-character name and a sixty-character one), longer international strings, slow connections (the loading state is designed, not a flash), and missing data (null fields, a failed image). Decide per field whether long content wraps or truncates, and when it truncates, keep the full value reachable.

## Accessibility floor

The floor is WCAG 2.2 level AA:

- Text contrast at least 4.5:1, or 3:1 for large text (18pt / 24 CSS px, or 14pt / about 18.7px bold) (1.4.3). Check it in both themes.
- Non-text contrast at least 3:1 against adjacent colors for what identifies a control and its state (borders of inputs, focus indicators, toggles) and for graphics needed to understand the content (1.4.11).
- Color is never the only signal of state or meaning (1.4.1).
- Everything works from the keyboard (2.1.1), focus moves in a logical order (2.4.3), the focus indicator is visible (2.4.7), and a focused element is never entirely hidden under a sticky header or footer (2.4.11).
- Inputs have labels or instructions (3.3.2), errors are identified and described in text (3.3.1), meaningful images have alt text (1.1.1), and every custom control exposes a name, role, and value (4.1.2); a native element gets this for free.
- Text resizes to 200% without loss of content or function (1.4.4), and content reflows at 320 CSS px wide without scrolling in two directions (1.4.10).
- Pointer targets are at least 24×24 CSS px, or spaced so that a 24px circle centered on each touches no other target (2.5.8); targets inside a sentence are exempt. 44×44 is criterion 2.5.5, level AAA: a good size for primary touch controls, not the AA floor.

An automated scan catches only part of these; a keyboard pass and a 200% zoom pass by hand catch much of the rest.

## Charts

For any chart, graph, sparkline, stat tile or KPI row, or choice of chart colors, invoke `Skill: "dataviz"` before writing chart code. It is a Claude Code built-in; if it resolves in no form, say so and continue unguided rather than substituting another skill.

## More generated-design tells

Add these to SKILL.md's calibration list; like those, they are defaults rather than choices, and precedence still applies:

- a purple-to-blue gradient hero on white;
- Inter or Space Grotesk as the "safe" face;
- emoji as section markers;
- everything centered;
- an accent bar or rail down the side of rounded cards.

Copy has its own tells: asides set off by em dashes, "not X, but Y" framing, colon-then-reveal sentences, scare quotes around invented labels, and stock phrases such as "worth noting" or "honest caveat". A page or screen title is a name, a short noun phrase specific to the subject, never a caption with an explanation appended after a dash or colon.

## Check

Look at the result at desktop and phone width, in light and dark, where the environment allows: overflow and sideways scroll, colors that ignore the theme, overlapping elements, a font that silently fell back, console errors. Tab through it once.
