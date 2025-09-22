/*
npx esbuild ./extract-identities.js \
--bundle \
--format=iife \
--global-name=IdentityUtils \
--outfile=./bundle.js
* */

// Standalone extractIdentities utility
// Copy this single file into other projects to reuse the identity extraction logic.
//
// It normalizes input text (lowercase, diacritics and punctuation removal), tokenizes
// by whitespace, and filters out stopwords and empty tokens.
//
// Usage:
//   import { extractIdentities, DEFAULT_STOPWORDS } from './extract-identities';
//   const identities = extractIdentities("Show me works by Refik Anadol", DEFAULT_STOPWORDS);
//   // identities => ["Refik", "Anadol"] (substrings from the original command)
//   // or with default internal stopwords:
//   const identities2 = extractIdentities("Display artwork by artist Refik and Dmitri");
//   // identities2 => ["Refik", "Dmitri"]
//
// Notes:
// - You can provide your own stopword list; if omitted, a built-in English list is used.
// - The function preserves the original tokens sequence after normalization.

/**
 * A default English stopwords list for convenience when no custom list is provided.
 * You can replace or extend this list in your project as needed.
 */
const DEFAULT_STOPWORDS: string[] = [
  // Common verbs and commands
  'show', 'display', 'play', 'find', 'search', 'get', 'give', 'tell', 'list', 'see',
  'want', 'need', 'like', 'love', 'hate', 'prefer', 'choose', 'select', 'pick',
  'start', 'stop', 'pause', 'resume', 'continue', 'begin', 'end', 'finish',
  'can', 'could', 'would', 'should', 'will', 'may', 'might',

  // Common nouns
  'artwork', 'artworks', 'art', 'works', 'pieces', 'items', 'work', 'piece', 'image', 'picture', 'photo', 'video',
  'series', 'collection', 'exhibition', 'show', 'gallery', 'museum',
  'artist', 'artists', 'creator', 'maker', 'author', 'designer', 'playlist', 'playlists',

  // Pronouns, articles, prepositions
  'i', 'you', 'he', 'she', 'it', 'we', 'they', 'me', 'him', 'her', 'us', 'them',
  'my', 'your', 'his', 'her', 'its', 'our', 'their', 'mine', 'yours', 'theirs',
  'the', 'a', 'an', 'this', 'that', 'these', 'those', 'some', 'any', 'all',
  'in', 'on', 'at', 'by', 'for', 'with', 'from', 'to', 'of', 'about', 'into',
  'through', 'during', 'before', 'after', 'above', 'below', 'up', 'down',
  'and', 'or', 'but', 'so', 'yet', 'nor', 'if', 'when', 'where', 'why', 'how',
  'what', 'which', 'who', 'whom', 'whose', 'that', 'than', 'as', 'like',

  // Adjectives / fillers
  'new', 'old', 'good', 'bad', 'big', 'small', 'large', 'little', 'great',
  'best', 'worst', 'first', 'last', 'next', 'previous', 'current', 'recent',
  'something', 'beautiful', 'amazing', 'cool', 'nice', 'awesome', 'wonderful', 'fantastic',

  // Device/location words
  'kitchen', 'bedroom', 'living', 'room', 'bathroom', 'office', 'study',
  'dining', 'hallway', 'basement', 'attic', 'garage', 'garden', 'patio',
  'tv', 'television', 'screen', 'monitor', 'display', 'device', 'player',

  // Time-related words
  'today', 'tomorrow', 'yesterday', 'now', 'later', 'soon', 'then',
  'morning', 'afternoon', 'evening', 'night', 'day', 'week', 'month', 'year',

  // Question words and responses
  'yes', 'no', 'maybe', 'ok', 'okay', 'sure', 'please', 'thanks', 'thank',
  'hello', 'hi', 'hey', 'goodbye', 'bye', 'sorry', 'excuse'
];

/**
 * Normalizes a string by lowercasing and removing diacritics and selected punctuation.
 * Punctuation removal keeps the hash character (#) to preserve tokens like edition tags.
 */
// normalize function (keep your implementation)
function normalizeForTokens(text) {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[.,\/!$%\^&\*;:{}=\-_`~()"?]/g, '');
}

// extractIdentities function (keep your implementation)
function extractIdentities(command, stopwords) {
  const stopwordSet = new Set((stopwords && stopwords.length > 0) ? stopwords : DEFAULT_STOPWORDS);
  const rawTokens = command.split(/\s+/);
  const stripPunctuationOnly = (s) => s.replace(/[.,\/!$%\^&\*;:{}=\-_`~()"?]/g, '');
  const results = [];

  for (const raw of rawTokens) {
    const cleanedForReturn = stripPunctuationOnly(raw);
    if (cleanedForReturn.length === 0) continue;

    const normalizedForFilter = cleanedForReturn
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');

    if (normalizedForFilter.length > 0 && !stopwordSet.has(normalizedForFilter)) {
      results.push(cleanedForReturn);
    }
  }

  return results;
}

// make it accessible globally
globalThis.extractIdentities = extractIdentities;
globalThis.DEFAULT_STOPWORDS = DEFAULT_STOPWORDS;


