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
function getGithubRemoteUrls(filePath) {
  try {
    const remoteUrl = execSync("git config --get remote.origin.url").toString().trim().replace(/https?:\/\/.*?@github\.com\//, "https://github.com/");
    const httpUrl = convertGitToHttpUrl(remoteUrl).replace(
      /\.git$/,
      `/tree/main/modules${filePath.replace(path.resolve(__dirname, 'modules'), '').replace(/\/README\.md$/, '')}`
    );
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
  const modulesDir = path.resolve(__dirname, 'modules');
  const assetsDir = path.resolve(__dirname, 'website/public/assets/logos');
  const dirs = fs.readdirSync(modulesDir, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory() && dirent.name !== ".github");

  dirs.forEach((dir) => {
    const platformDir = path.join(modulesDir, dir.name);
    const files = fs.readdirSync(platformDir);

    files.forEach((file) => {
      if (file.endsWith(".png") || file.endsWith(".svg")) {
        const sourcePath = path.join(platformDir, file);
        const destinationPath = path.join(assetsDir, `${dir.name}${path.extname(file)}`);

        fs.mkdirSync(assetsDir, { recursive: true });

        fs.copyFileSync(sourcePath, destinationPath);

        platformLogos[dir.name] = destinationPath.replace(path.resolve(__dirname, 'website/public'), "").replace(/^\/+/g, "");
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
  const assetsDir = path.resolve(__dirname, 'website/public/assets/building-block-logos');
  const files = fs.readdirSync(buildingBlockDir);

  files.forEach((file) => {
    if (file.endsWith(".png") || file.endsWith(".svg")) {
      const { id, platform } = getIdAndPlatform(buildingBlockDir);
      const sourcePath = path.join(buildingBlockDir, file);
      const destinationPath = path.join(assetsDir, `${id}${path.extname(file)}`);

      fs.mkdirSync(assetsDir, { recursive: true });
      fs.copyFileSync(sourcePath, destinationPath);

      logoFiles.push(destinationPath.replace(path.resolve(__dirname, 'website/public'), "").replace(/^\/+/g, ""));
    }
  });

  return logoFiles.length > 0 ? logoFiles[0] : null;
}

/**
 * Parse README.md and extract relevant data
 */
function parseReadme(filePath) {
  const buildingBlockDir = path.dirname(filePath);
  const content = fs.readFileSync(filePath, "utf-8");
  const { data, content: body } = matter(content);
  const { id, platform } = getIdAndPlatform(buildingBlockDir);
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

  const githubUrls = getGithubRemoteUrls(filePath);
  console.log(`🔗 GitHub remote URLs: ${JSON.stringify(githubUrls)}`);
  console.log(`🔗 File path: ${filePath}`);

  const buildingBlockLogoPath = findBuildingBlockLogo(buildingBlockDir);

  return {
    id: id,
    platformType: platform,
    logo: buildingBlockLogoPath,
    githubUrls,
    ...data,
    howToUse: howToMatch ? howToMatch[1].trim() : null,
    resources: parseTable(resourcesMatch),
    inputs: parseTable(inputsMatch),
    outputs: parseTable(outputsMatch),
  };
}

/**
 * This returns the id and platform type from the file path.
 *
 * @param filePath The buildingblock directory
 */
function getIdAndPlatform(filePath) {
  const relativePath = filePath.replace(process.cwd(), "").replace(/\\/g, "/");
  const pathParts = relativePath.split(path.sep).filter(Boolean);
  // pathParts = [modules, <platform>, <module-name>, buildingblock]
  const id = pathParts.slice(1, pathParts.length - 1).join("-");
  const platform = pathParts.length > 1 ? pathParts[1] : "unknown";

  return { id, platform };
}

const repoRoot = path.resolve(__dirname, 'modules');
const platformLogos = findPlatformLogos();
const readmeFiles = findReadmes(repoRoot);
const jsonData = readmeFiles.map((file) => parseReadme(file));

const templatesData = {
  templates: jsonData,
};

fs.writeFileSync("website/public/assets/templates.json", JSON.stringify(templatesData, null, 2));
console.log(`✅ Successfully processed ${readmeFiles.length} README.md files. Output saved to templates.json`);

fs.writeFileSync("website/public/assets/platform-logos.json", JSON.stringify(platformLogos, null, 2));
console.log(`✅ Successfully processed ${Object.entries(platformLogos).length} platform logos. Output saved to platform-logos.json`);
