const fs = require("fs");
const path = require("path");
const matter = require("gray-matter");
const { execSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "modules");
const assetsDir = path.resolve(__dirname, "website/public/assets/logos");

function getGitHubRemoteUrl() {
  try {
    const remoteUrl = execSync("git config --get remote.origin.url")
      .toString()
      .trim()
      .replace(/https?:\/\/.*?@github\.com\//, "https://github.com/");
    return remoteUrl.replace(/\.git$/, "");
  } catch (error) {
    console.error("Error getting GitHub remote URL:", error.message);
    return null;
  }
}

function getBuildingBlockFolderUrl(filePath) {
  const remoteUrl = getGitHubRemoteUrl();
  if (!remoteUrl) return null;

  const relativePath = filePath
    .replace(path.resolve(__dirname, "modules"), "")
    .replace(/\/README\.md$/, "");
  return `${remoteUrl}/tree/main/modules${relativePath}`;
}

function findReadmes(dir){
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((file) => {
    const fullPath = path.join(dir, file.name);
    if (file.isDirectory()) {
      return file.name === ".github" ? [] : findReadmes(fullPath);
    }
    return file.name === "README.md" && dir.includes("buildingblock")
      ? [fullPath]
      : [];
  });
}

function findPlatforms(): Platform[] {
  fs.mkdirSync(assetsDir, { recursive: true });

  return fs.readdirSync(repoRoot, { withFileTypes: true })
    .filter((dirent) => dirent.isDirectory() && dirent.name !== ".github")
    .map((dir) => {
      const platformDir: string = path.join(repoRoot, dir.name);
      const platformLogo = getPlatformLogoOrThrow(platformDir, dir.name);
      const platformReadme = getPlatformReadmeOrThrow(platformDir);
      const { name, description, category, content } = extractReadmeFrontMatter(platformReadme);
      const terraformSnippet = getTerraformSnippet(platformDir);

      return {
        platformType: dir.name,
        name,
        description,
        category,
        logo: platformLogo,
        readme: content,
        terraformSnippet
      };
    });
}

// Finds the logo, copies it to website assets and returns the path.
function getPlatformLogoOrThrow(platformDir: string, platformType: string): string {
  const logoFile = fs.readdirSync(platformDir).find(f => f.endsWith('.png') || f.endsWith('.svg'));
  if (logoFile) {
    const sourcePath = path.join(platformDir, logoFile);
    const destPath = path.join(assetsDir, `${platformType}${path.extname(logoFile)}`);
    fs.copyFileSync(sourcePath, destPath);
    return destPath.replace(path.resolve(__dirname, "website/public"), "").replace(/^\/+/g, "");
  }

  throw new Error(`Logo file not found for platform: ${platformType} in directory: ${platformDir}. Each platform should have a logo.`);
}

function getPlatformReadmeOrThrow(platformDir: string) {
  try {
    return fs.readFileSync(path.join(platformDir, "README.md"), "utf-8");
  } catch {
    throw new Error(`Platform README.md not found for ${platformDir}. Each platform should have a README.md file.`);
  }
}

function extractReadmeFrontMatter(platformReadme: string): { name: string; description: string; category?: string; content: string } {
  const { data, content } = matter(platformReadme);

  const name = data.name;
  if (!name) {
    throw new Error('Property "name" is missing in the front matter of the platform README.md. Each platform README.md should have a name defined in the front matter.');
  }

  const description = data.description;
  if (!description) {
    throw new Error('Property "description" is missing in the front matter of the platform README.md. Each platform README.md should have a description defined in the front matter.');
  }

  const category = data.category;

  return {
    name,
    description,
    content,
    category
  }
}

function getTerraformSnippet(platformDir: string): string | null {
  try {
    return fs.readFileSync(path.join(platformDir, "meshstack_integration.tf"), "utf-8")
  } catch {
    return null;
  }
}

function copyBuildingBlockLogoToAssets(buildingBlockDir) {
  const assetsDir = path.resolve(
    __dirname,
    "website/public/assets/building-block-logos"
  );

  const logoFile = fs
    .readdirSync(buildingBlockDir)
    .find((file) => file.endsWith(".png"));

  if (!logoFile) return null;

  const { id } = getIdAndPlatform(buildingBlockDir);
  const sourcePath = path.join(buildingBlockDir, logoFile);
  const destinationPath = path.join(assetsDir, `${id}${path.extname(logoFile)}`);

  fs.mkdirSync(assetsDir, { recursive: true });
  fs.copyFileSync(sourcePath, destinationPath);

  return destinationPath
    .replace(path.resolve(__dirname, "website/public"), "")
    .replace(/^\/+/g, "");
}

function parseReadme(filePath) {
  const buildingBlockDir = path.dirname(filePath);
  const content = fs.readFileSync(filePath, "utf-8");
  const { data, content: body } = matter(content);
  const { id, platform } = getIdAndPlatform(buildingBlockDir);

  const extractSection = (regex) =>
    body.match(regex)?.[1]?.trim() || null;

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

  const buildingBlockUrl = getBuildingBlockFolderUrl(filePath);
  const buildingBlockLogoPath = copyBuildingBlockLogoToAssets(buildingBlockDir);

  const backplaneDir = path.join(buildingBlockDir, "../backplane");
  const backplaneUrl =
    fs.existsSync(backplaneDir) && fs.statSync(backplaneDir).isDirectory()
      ? getBuildingBlockFolderUrl(backplaneDir)
      : null;

  const terraformSnippetDir = path.join(buildingBlockDir, "..");
  const terraformSnippet = getTerraformSnippet(terraformSnippetDir);

  return {
    id,
    platformType: platform,
    logo: buildingBlockLogoPath,
    buildingBlockUrl,
    backplaneUrl,
    terraformSnippet,
    ...data,
    howToUse: extractSection(/## How to Use([\s\S]*?)(##|$)/),
    resources: parseTable(body.match(/## Resources([\s\S]*)/)),
    inputs: parseTable(body.match(/## Inputs([\s\S]*?)## Outputs/)),
    outputs: parseTable(body.match(/## Outputs([\s\S]*)/))
  };
}

function getIdAndPlatform(filePath) {
  const relativePath = filePath
    .replace(process.cwd(), "")
    .replace(/\\/g, "/");
  const pathParts = relativePath.split(path.sep).filter(Boolean);
  const id = pathParts.slice(1, pathParts.length - 1).join("-");
  const platform = pathParts[1] || "unknown";

  return { id, platform };
}

// Main execution
function main() {
  const platforms = findPlatforms();
  fs.writeFileSync(
    "website/public/assets/platform.json",
    JSON.stringify(platforms, null, 2)
  );
  console.log(
    `✅ Successfully processed ${platforms.length} platforms. Output saved to platform.json`
  );

  const readmeFiles = findReadmes(repoRoot);
  const jsonData = readmeFiles.map(parseReadme);
  fs.writeFileSync(
    "website/public/assets/templates.json",
    JSON.stringify({ templates: jsonData }, null, 2)
  );
  console.log(
    `✅ Successfully processed ${readmeFiles.length} README.md files. Output saved to templates.json`
  );
}

main();

export interface Platform {
  platformType: string;
  name: string;
  description: string;
  logo: string;
  readme: string;
  category?: string;
  terraformSnippet?: string;
}
