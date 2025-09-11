const fs = require("fs");
const path = require("path");

function templateToRegex(template) {
  const placeholderRegex = /\{(\w+)\}/g;
  const placeholders = [];

  // Build pattern by walking through the template and escaping only literals
  let lastIndex = 0;
  let patternBody = "";
  let match;

  while ((match = placeholderRegex.exec(template)) !== null) {
    const [placeholder, name] = match;
    const literalBefore = template.slice(lastIndex, match.index);
    // Escape literal segment
    patternBody += literalBefore.replace(/[-\/\\^$*+?.()|[\]{}]/g, "\\$&");
    // Add non-greedy capture group for the placeholder
    patternBody += "(.+?)";
    // If this placeholder is at the end of the template (no literal after),
    // add a lookahead to stop before punctuation or end (allow spaces and capitals in names)
    const afterIndex = match.index + placeholder.length;
    const hasTrailingLiteral = afterIndex < template.length;
    if (!hasTrailingLiteral) {
      patternBody += "(?=$|[?.!,;:])";
    }
    placeholders.push(name);
    lastIndex = match.index + placeholder.length;
  }

  // Append remaining literal and escape it
  const remaining = template.slice(lastIndex);
  patternBody += remaining.replace(/[-\/\\^$*+?.()|[\]{}]/g, "\\$&");

  // Return regex without anchors so it can match as a substring
  const pattern = `${patternBody}`;
  return { template, regex: pattern, placeholders };
}

function main() {
  // ✅ Always use script’s directory
  const filePath = path.join(__dirname, "templates.json");

  const templates = JSON.parse(fs.readFileSync(filePath, "utf8"));
  const converted = templates.map(templateToRegex);

  const outPath = path.join(__dirname, "templates_enriched.json");
  fs.writeFileSync(outPath, JSON.stringify(converted, null, 2));

  console.log("✅ templates_enriched.json generated in", __dirname);
}

main();
