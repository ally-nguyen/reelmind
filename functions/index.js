const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const Anthropic = require("@anthropic-ai/sdk");
const axios = require("axios");

initializeApp();
const db = getFirestore();

// ── generateIdea ─────────────────────────────────────────────────────────────
// Called from Flutter when the user taps "Generate for me".
// Reads the user's taste profile from Firestore, builds a prompt, calls Claude,
// and saves the new VideoIdea to Firestore.
exports.generateIdea = onCall({ secrets: ["ANTHROPIC_API_KEY"] }, async (req) => {
  const { userId, tasteProfile } = req.data;
  if (!userId) throw new HttpsError("invalid-argument", "userId required");

  const client = new Anthropic.default({ apiKey: process.env.ANTHROPIC_API_KEY });

  const hashtagStr = tasteProfile?.hashtags?.join(", ") || "general content";
  const topicStr = tasteProfile?.topics?.join(", ") || "lifestyle";

  const prompt = `You are a creative video content strategist.
A creator is interested in: ${topicStr}.
Their audience engages with hashtags like: ${hashtagStr}.

Generate ONE compelling short-form video idea. Respond in valid JSON only:
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
    model: "claude-opus-4-6",
    max_tokens: 1024,
    thinking: { type: "adaptive" },
    messages: [{ role: "user", content: prompt }],
  });

  const textBlock = response.content.find((b) => b.type === "text");
  if (!textBlock) throw new HttpsError("internal", "No text response from Claude");

  const parsed = JSON.parse(textBlock.text);
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

// ── connectInstagram ──────────────────────────────────────────────────────────
// Exchanges the OAuth code for a long-lived access token and stores it
// server-side. The token is NEVER returned to the client.
exports.connectInstagram = onCall(
  { secrets: ["INSTAGRAM_APP_SECRET"] },
  async (req) => {
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
  }
);

// ── syncInstagramFeed ─────────────────────────────────────────────────────────
// Fetches the user's recent media, extracts hashtags/topics, and updates
// their tasteProfile in Firestore.
exports.syncInstagramFeed = onCall(async (req) => {
  const { uid } = req.data;
  if (!uid) throw new HttpsError("invalid-argument", "uid required");

  const tokenDoc = await db.collection("instagram_tokens").doc(uid).get();
  if (!tokenDoc.exists)
    throw new HttpsError("not-found", "Instagram not connected");

  const { accessToken, igUserId } = tokenDoc.data();

  const mediaRes = await axios.get(
    `https://graph.instagram.com/${igUserId}/media`,
    { params: { fields: "id,caption,media_type,timestamp",
        access_token: accessToken, limit: 20 } }
  );

  const captions = mediaRes.data.data
    .map((m) => m.caption || "")
    .filter(Boolean);

  // Extract hashtags from captions
  const hashtags = [
    ...new Set(
      captions.flatMap((c) => (c.match(/#\w+/g) || []).map((h) => h.toLowerCase()))
    ),
  ].slice(0, 30);

  // Simple keyword extraction: words > 4 chars that appear 2+ times
  const wordFreq = {};
  captions.forEach((c) => {
    c.toLowerCase().split(/\W+/).filter((w) => w.length > 4).forEach((w) => {
      wordFreq[w] = (wordFreq[w] || 0) + 1;
    });
  });
  const topics = Object.entries(wordFreq)
    .filter(([, count]) => count >= 2)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 15)
    .map(([word]) => word);

  await db.collection("users").doc(uid).update({
    "tasteProfile.hashtags": hashtags,
    "tasteProfile.topics": topics,
    "tasteProfile.lastSynced": FieldValue.serverTimestamp(),
  });

  return { hashtags, topics };
});
