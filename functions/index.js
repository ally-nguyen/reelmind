const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const AnthropicSdk = require("@anthropic-ai/sdk");
const Anthropic = AnthropicSdk.default ?? AnthropicSdk;
const axios = require("axios");

initializeApp();
const db = getFirestore();

// ── helpers ───────────────────────────────────────────────────────────────────

function parseJson(text) {
  // Strip markdown code fences if Claude wraps the JSON in ```json ... ```
  const cleaned = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "").trim();
  return JSON.parse(cleaned);
}

function extractHashtags(captions) {
  return [
    ...new Set(
      captions.flatMap((c) => (c.match(/#\w+/g) || []).map((h) => h.toLowerCase()))
    ),
  ].slice(0, 30);
}

function extractTopics(captions) {
  const wordFreq = {};
  captions.forEach((c) => {
    c.toLowerCase()
      .replace(/#\w+/g, "")
      .split(/\W+/)
      .filter((w) => w.length > 4)
      .forEach((w) => { wordFreq[w] = (wordFreq[w] || 0) + 1; });
  });
  return Object.entries(wordFreq)
    .filter(([, count]) => count >= 2)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 15)
    .map(([word]) => word);
}

// ── generateIdea ─────────────────────────────────────────────────────────────
// Called from Flutter when the user taps "Generate for me".
// Uses video-specific Instagram signals to generate a style-matched idea.
exports.generateIdea = onCall({ secrets: ["ANTHROPIC_API_KEY"] }, async (req) => {
  const { userId, tasteProfile } = req.data;
  if (!userId) throw new HttpsError("invalid-argument", "userId required");

  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY?.trim() });

  // Prefer video-specific signals; fall back to combined signals
  const videoTopics = tasteProfile?.videoTopics?.join(", ")
    || tasteProfile?.topics?.join(", ")
    || "lifestyle content";
  const videoHashtags = tasteProfile?.videoHashtags?.join(", ")
    || tasteProfile?.hashtags?.join(", ")
    || "general";
  const likedHashtags = tasteProfile?.likedHashtags?.join(", ") || "";
  const likedTopics = tasteProfile?.likedTopics?.join(", ") || "";
  const videoCount = tasteProfile?.videoCount ?? 0;
  const totalPosts = tasteProfile?.totalPostsAnalyzed ?? 0;

  const likedContext = (likedHashtags || likedTopics)
    ? `They engage with and like content about: ${likedTopics || likedHashtags}. Hashtags they interact with: ${likedHashtags}.`
    : "";

  const prompt = `You are a creative short-form video content strategist for Instagram Reels.

Creator profile based on their Instagram:
- Their own video content focuses on: ${videoTopics}
- Hashtags they use on videos: ${videoHashtags}
- They have posted ${videoCount} videos out of ${totalPosts} total posts
${likedContext}

Generate ONE compelling short-form video idea that authentically matches this creator's established style and audience. The bullets should be spoken talking points — key statements, facts, tips, or hooks the creator says out loud on camera. Not scene descriptions or camera directions. Respond in valid JSON only:
{
  "title": "<punchy video title, max 10 words>",
  "bullets": [
    "<talking point 1>",
    "<talking point 2>",
    "<talking point 3>",
    "<talking point 4>",
    "<talking point 5>"
  ]
}`;

  const response = await client.messages.create({
    model: "claude-opus-4-5",
    max_tokens: 1024,
    messages: [{ role: "user", content: prompt }],
  });

  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock) throw new HttpsError("internal", "No text response from Claude");

  const parsed = parseJson(textBlock.text);
  const now = FieldValue.serverTimestamp();

  const ideaRef = await db
    .collection("users")
    .doc(userId)
    .collection("ideas")
    .add({
      userId,
      title: parsed.title,
      bullets: parsed.bullets,
      status: "draft",
      source: "aiGenerated",
      createdAt: now,
      updatedAt: now,
    });

  return { id: ideaRef.id, title: parsed.title, bullets: parsed.bullets };
});

// ── generateBullets ──────────────────────────────────────────────────────────
// Called from the idea detail screen with a user-supplied title.
// Fetches the user's taste profile from Firestore and asks Claude to write
// bullet points that match their Instagram video style.
exports.generateBullets = onCall({ secrets: ["ANTHROPIC_API_KEY"] }, async (req) => {
  const { userId, title, userInput } = req.data;
  if (!userId || !title) throw new HttpsError("invalid-argument", "userId and title required");

  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY?.trim() });

  // Fetch taste profile directly from Firestore
  const userDoc = await db.collection("users").doc(userId).get();
  const tasteProfile = userDoc.exists ? (userDoc.data().tasteProfile || {}) : {};

  const videoTopics = tasteProfile.videoTopics?.join(", ") || tasteProfile.topics?.join(", ") || "general content";
  const videoHashtags = tasteProfile.videoHashtags?.join(", ") || tasteProfile.hashtags?.join(", ") || "";
  const likedTopics = tasteProfile.likedTopics?.join(", ") || "";

  const styleContext = (videoTopics || videoHashtags)
    ? `The creator's Instagram video style focuses on: ${videoTopics}. They use hashtags: ${videoHashtags}.${likedTopics ? ` They also engage with: ${likedTopics}.` : ""}`
    : "No Instagram data available yet — generate general video content bullet points.";

  const prompt = `You are a short-form video script strategist for Instagram Reels.

${styleContext}

The creator wants to make a video titled: "${title}"${userInput ? `\n\nThey want to talk about: "${userInput}"` : ""}

Write 5 spoken talking points for this specific video that match their established content style. Each bullet should be something the creator actually says out loud on camera — a key statement, fact, tip, or hook — not a scene description or camera direction.

Respond in valid JSON only:
{
  "bullets": [
    "<talking point 1>",
    "<talking point 2>",
    "<talking point 3>",
    "<talking point 4>",
    "<talking point 5>"
  ]
}`;

  const response = await client.messages.create({
    model: "claude-opus-4-5",
    max_tokens: 1024,
    messages: [{ role: "user", content: prompt }],
  });

  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock) throw new HttpsError("internal", "No text response from Claude");

  const parsed = parseJson(textBlock.text);
  return { bullets: parsed.bullets };
});

// ── connectInstagram ──────────────────────────────────────────────────────────
// Exchanges the OAuth code for a long-lived access token and stores it
// server-side. The token is NEVER returned to the client.
exports.connectInstagram = onCall({ secrets: ["INSTAGRAM_APP_ID", "INSTAGRAM_APP_SECRET"] }, async (req) => {
    const { uid, code } = req.data;
    if (!uid || !code)
      throw new HttpsError("invalid-argument", "uid and code required");

    const clientId = process.env.INSTAGRAM_APP_ID;
    const clientSecret = process.env.INSTAGRAM_APP_SECRET;
    const redirectUri = "reelmind://oauth/instagram";

    // Exchange short-lived code for token
    const tokenRes = await axios.post(
      "https://api.instagram.com/oauth/access_token",
      new URLSearchParams({ client_id: clientId, client_secret: clientSecret,
        grant_type: "authorization_code", redirect_uri: redirectUri, code }),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );

    const shortToken = tokenRes.data.access_token;
    const igUserId = tokenRes.data.user_id;

    // Exchange for long-lived token
    const longRes = await axios.get(
      `https://graph.instagram.com/access_token`,
      { params: { grant_type: "ig_exchange_token", client_secret: clientSecret,
          access_token: shortToken } }
    );

    const longToken = longRes.data.access_token;

    // Store token securely in Firestore (not exposed to client)
    await db.collection("instagram_tokens").doc(uid).set({
      accessToken: longToken,
      igUserId,
      updatedAt: FieldValue.serverTimestamp(),
    });

    await db.collection("users").doc(uid).update({
      instagramConnected: true,
    });

    return { success: true };
});

// ── syncInstagramFeed ─────────────────────────────────────────────────────────
// Fetches the user's own posts and liked content, builds a rich taste profile,
// and caches it in Firestore under the user doc.
exports.syncInstagramFeed = onCall(async (req) => {
  const { uid } = req.data;
  if (!uid) throw new HttpsError("invalid-argument", "uid required");

  const tokenDoc = await db.collection("instagram_tokens").doc(uid).get();
  if (!tokenDoc.exists)
    throw new HttpsError("not-found", "Instagram not connected");

  const { accessToken, igUserId } = tokenDoc.data();

  // ── 1. Fetch user's own posts (up to 50) ─────────────────────────────────
  const mediaRes = await axios.get(
    `https://graph.instagram.com/${igUserId}/media`,
    { params: {
        fields: "id,caption,media_type,timestamp",
        access_token: accessToken,
        limit: 50,
    }}
  );

  const allPosts = mediaRes.data.data || [];

  // Separate video posts (Reels) from everything else
  const videoPosts = allPosts.filter((p) => p.media_type === "VIDEO");
  const allCaptions = allPosts.map((p) => p.caption || "").filter(Boolean);
  const videoCaptions = videoPosts.map((p) => p.caption || "").filter(Boolean);

  const ownHashtags = extractHashtags(allCaptions);
  const ownTopics = extractTopics(allCaptions);
  const videoHashtags = extractHashtags(videoCaptions);
  const videoTopics = extractTopics(videoCaptions);

  // ── 2. Fetch liked media (requires user_liked_media scope) ────────────────
  // Gracefully skipped if the permission wasn't granted during OAuth.
  let likedHashtags = [];
  let likedTopics = [];
  try {
    const likedRes = await axios.get(
      `https://graph.instagram.com/me/liked_media`,
      { params: {
          fields: "id,caption,media_type",
          access_token: accessToken,
          limit: 50,
      }}
    );
    const likedCaptions = (likedRes.data.data || [])
      .map((p) => p.caption || "")
      .filter(Boolean);
    likedHashtags = extractHashtags(likedCaptions);
    likedTopics = extractTopics(likedCaptions);
  } catch (_) {
    // user_liked_media permission not granted — skip silently
  }

  // ── 3. Build combined signals (video-first priority) ─────────────────────
  const combinedHashtags = [
    ...new Set([...videoHashtags, ...ownHashtags, ...likedHashtags]),
  ].slice(0, 30);

  const combinedTopics = [
    ...new Set([...videoTopics, ...ownTopics, ...likedTopics]),
  ].slice(0, 20);

  // ── 4. Persist to Firestore ───────────────────────────────────────────────
  await db.collection("users").doc(uid).update({
    "tasteProfile.hashtags": combinedHashtags,
    "tasteProfile.topics": combinedTopics,
    "tasteProfile.ownHashtags": ownHashtags,
    "tasteProfile.ownTopics": ownTopics,
    "tasteProfile.videoHashtags": videoHashtags,
    "tasteProfile.videoTopics": videoTopics,
    "tasteProfile.likedHashtags": likedHashtags,
    "tasteProfile.likedTopics": likedTopics,
    "tasteProfile.videoCount": videoPosts.length,
    "tasteProfile.totalPostsAnalyzed": allPosts.length,
    "tasteProfile.lastSynced": FieldValue.serverTimestamp(),
  });

  return {
    videoCount: videoPosts.length,
    totalPostsAnalyzed: allPosts.length,
    videoTopics,
    likedHashtags,
  };
});
