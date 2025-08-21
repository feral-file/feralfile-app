import StyleDictionary from "style-dictionary";
import { register } from "@tokens-studio/sd-transforms";
import { expandTypesMap } from "@tokens-studio/sd-transforms";
import fs from "fs";
import path from "path";

register(StyleDictionary, {
  excludeParentKeys: true,
  withSDBuiltins: true,
  "ts/color/modifiers": {
    format: "hex",
  },
});

StyleDictionary.registerTransform({
  name: `dart/size/number`,
  type: `value`,
  transitive: true,
  filter: (token) => {
    return (
      [
        "fontSize",
        "dimension",
        "border",
        "typography",
        "shadow",
        "letterSpacing",
      ].includes(token.$type) &&
      (token.$value.endsWith("px") || token.$value.endsWith("em"))
    );
  },
  transform: (token) => {
    return Number(token.$value.replace(/px|em/g, ""));
  },
});

StyleDictionary.registerTransform({
  name: `dart/none/null`,
  type: `value`,
  transitive: true,
  filter: (token) => {
    return token.$value === "none";
  },
  transform: (token) => {
    return null;
  },
});

const tokensDir = "lib/design/tokens";
let files = [];

if (fs.existsSync(tokensDir)) {
  files = fs
    .readdirSync(tokensDir)
    .filter((file) => file.endsWith(".json"))
    .map((file) => path.basename(file, ".json"));
  console.log("Found token files:", files);
} else {
  console.error("Tokens directory not found");
  process.exit(1);
}

const sd = new StyleDictionary({
  source: ["lib/design/tokens/*.json"],
  preprocessors: ["tokens-studio"],
  platforms: {
    flutter: {
      buildPath: "lib/design/build/",
      files: [...generateGlobalFiles(), ...generateComponentFiles()],
      transformGroup: "tokens-studio",
      transforms: [
        "attribute/cti",
        "color/hex8flutter",
        "content/flutter/literal",
        "asset/flutter/literal",
        "dart/size/number",
        "dart/none/null",
      ],
    },
  },
  expand: {
    typesMap: expandTypesMap,
  },
});

await sd.cleanAllPlatforms();
await sd.buildAllPlatforms();

function isComponentFile(filePath) {
  return !(filePath.includes("primitives") || filePath.includes("typography"));
}

function generateGlobalFiles() {
  const globalFiles = files.filter((file) => !isComponentFile(file));
  return globalFiles.map((file) => ({
    destination: `${file}.dart`,
    format: "flutter/class.dart",
    filter: (token) => token.filePath.includes(file),
    options: {
      className: `${file.charAt(0).toUpperCase() + file.slice(1)}Tokens`,
    },
  }));
}

function generateComponentFiles() {
  const componentFiles = files.filter(isComponentFile);

  return componentFiles.map((comp) => ({
    destination: `/components/${comp}.dart`,
    format: "flutter/class.dart",
    filter: (token) => token.filePath.includes(comp),
    options: {
      className: `${comp.charAt(0).toUpperCase() + comp.slice(1)}Tokens`,
    },
  }));
}
