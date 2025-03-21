const fs = require("fs");
const path = require("path");
const matter = require("gray-matter");
const { execSync } = require("child_process");

/**
 * Convert git remote URL to HTTP URL
 */
function convertGitToHttpUrl(gitUrl) {
  if (gitUrl.startsWith("git@github.com:")) {
    return gitUrl.replace("git@github.com:", "https://github.com/");
  }
  return gitUrl;
}

/**
 * Get GitHub remote URLs in HTTP and SSH format
 */
function getGithubRemoteUrls() {
  try {
    const remoteUrl = execSync("git config --get remote.origin.url").toString().trim();
    const httpUrl = convertGitToHttpUrl(remoteUrl);
    return {
      ssh: remoteUrl,
      https: httpUrl
    };
  } catch (error) {
    console.error("Error getting GitHub remote URL:", error.message);
    return null;
  }
}

/**
 * Recursively find all README.md files in “buildingblock” folders, excluding .github
 */
function findReadmes(dir) {
  let results = [];
  const files = fs.readdirSync(dir, { withFileTypes: true });

  for (const file of files) {
    const fullPath = path.join(dir, file.name);

    if (file.isDirectory()) {
      if (file.name === ".github") continue;
      results = results.concat(findReadmes(fullPath));
    } else if (file.name === "README.md" && dir.includes("buildingblock")) {
      results.push(fullPath);
    }
  }

  return results;
}

/**
 * Path to platform logo image, excluding .github
 */
function findPlatformLogos() {
  const platformLogos = {};
  const rootDir = process.cwd();
  const dirs = fs.readdirSync(rootDir, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory() && dirent.name !== ".github");

  dirs.forEach((dir) => {
    const platformDir = path.join(rootDir, dir.name);
    const files = fs.readdirSync(platformDir);

    files.forEach((file) => {
      if (file.endsWith(".png")) {
        platformLogos[dir.name] = path.join(platformDir, file).replace(rootDir, "").replace(/^\/+/g, "");
      }
    });
  });

  return platformLogos;
}

/**
 * Path to buildingblock logo image in the same directory as README.md
 */
function findBuildingBlockLogo(buildingBlockDir) {
  const logoFiles = [];
  const files = fs.readdirSync(buildingBlockDir);

  files.forEach((file) => {
    if (file.endsWith(".png")) {
      const filePath = path.join(buildingBlockDir, file);
      logoFiles.push(filePath.replace(process.cwd(), "").replace(/^\/+/g, ""));
    }
  });

  return logoFiles.length > 0 ? logoFiles[0] : null;
}

/**
 * Parse README.md and extract relevant data
 */
function parseReadme(filePath, platformLogos) {
  const content = fs.readFileSync(filePath, "utf-8");
  const { data, content: body } = matter(content);
  const relativePath = filePath.replace(process.cwd(), "").replace(/\\/g, "/");
  const pathParts = relativePath.split(path.sep).filter(Boolean);
  const cleanPath = pathParts.slice(0, pathParts.length - 1).join("/");
  const platform = pathParts.length > 1 ? pathParts[0] : "unknown";
  const howToMatch = body.match(/## How to Use([\s\S]*?)(##|$)/);
  const resourcesMatch = body.match(/## Resources([\s\S]*)/);
  const inputsMatch = body.match(/## Inputs([\s\S]*?)## Outputs/);
  const outputsMatch = body.match(/## Outputs([\s\S]*)/);

  const parseTable = (match) =>
    match
      ? match[1]
          .split("\n")
          .filter((line) => line.startsWith("| <a name"))
          .map((line) => line.split("|").map((s) => s.trim()))
          .map(([name, description, type, _default, required]) => ({
            name: name.replace(/<a name=".*?_(.*?)".*?>/, "$1"),
            description,
            type,
            required: required === "yes",
          }))
      : [];

  const githubUrls = getGithubRemoteUrls();
  const buildingBlockLogoPath = findBuildingBlockLogo(path.dirname(filePath));

  return {
    path: relativePath.replace(/^\/+/g, ""),
    cleanPath,
    platform,
    platformLogo: platformLogos[platform] || null,
    buildingBlockLogo: buildingBlockLogoPath,
    githubUrls,
    ...data,
    howToUse: howToMatch ? howToMatch[1].trim() : null,
    resources: parseTable(resourcesMatch),
    inputs: parseTable(inputsMatch),
    outputs: parseTable(outputsMatch),
  };
}

const repoRoot = path.resolve(__dirname);
const platformLogos = findPlatformLogos();
const readmeFiles = findReadmes(repoRoot);
const jsonData = readmeFiles.map((file) => parseReadme(file, platformLogos));

const outputData = {
  platformLogos,
  buildingBlocks: jsonData,
};

fs.writeFileSync("output.json", JSON.stringify(outputData, null, 2));

console.log(`✅ JSON-Daten aus ${readmeFiles.length} READMEs gespeichert in output.json`);
