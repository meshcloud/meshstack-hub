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
 * Recursively find all README.md files in “buildingblock” folders
 */
function findReadmes(dir) {
  let results = [];
  const files = fs.readdirSync(dir, { withFileTypes: true });

  for (const file of files) {
    const fullPath = path.join(dir, file.name);

    if (file.isDirectory()) {
      results = results.concat(findReadmes(fullPath));
    } else if (file.name === "README.md" && dir.includes("buildingblock")) {
      results.push(fullPath);
    }
  }

  return results;
}

/**
 * Path to platform logo image 
 */
function findPlatformLogo(platform) {
  const platformDir = path.join(process.cwd(), platform);
  const logoFiles = [];

  if (fs.existsSync(platformDir)) {
    const files = fs.readdirSync(platformDir);

    files.forEach((file) => {
      if (file.endsWith(".png")) {
        const filePath = path.join(platformDir, file);
        // Entfernt führende Schrägstriche
        logoFiles.push(filePath.replace(process.cwd(), "").replace(/^\/+/, ""));
      }
    });
  }

  return logoFiles;
}

/**
 * Parse README.md and extract relevant data
 */
function parseReadme(filePath) {
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
  const logoPath = findPlatformLogo(platform);

  return {
    path: relativePath.replace(/^\/+/, ""),
    cleanPath,
    platform,
    logo: logoPath,
    githubUrls,
    ...data,
    howToUse: howToMatch ? howToMatch[1].trim() : null,
    resources: parseTable(resourcesMatch),
    inputs: parseTable(inputsMatch),
    outputs: parseTable(outputsMatch),
  };
}

const repoRoot = path.resolve(__dirname);
const readmeFiles = findReadmes(repoRoot);
const jsonData = readmeFiles.map((file) => parseReadme(file));

fs.writeFileSync("output.json", JSON.stringify(jsonData, null, 2));

console.log(`✅ JSON-Daten aus ${readmeFiles.length} READMEs gespeichert in output.json`);
