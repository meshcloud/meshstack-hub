const fs = require("fs");
const path = require("path");
const matter = require("gray-matter");
const { execSync } = require("child_process");

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

function copyFilesToAssets(
  sourceDir,
  destinationDir,
  fileFilter
){
  const copiedFiles = {};

  fs.readdirSync(sourceDir, { withFileTypes: true })
    .filter((dirent) => dirent.isDirectory() && dirent.name !== ".github")
    .forEach((dir) => {
      const platformDir = path.join(sourceDir, dir.name);
      fs.readdirSync(platformDir)
        .filter(fileFilter)
        .forEach((file) => {
          const sourcePath = path.join(platformDir, file);
          const destinationPath = path.join(
            destinationDir,
            `${dir.name}${path.extname(file)}`
          );

          fs.mkdirSync(destinationDir, { recursive: true });
          fs.copyFileSync(sourcePath, destinationPath);

          copiedFiles[dir.name] = destinationPath
            .replace(path.resolve(__dirname, "website/public"), "")
            .replace(/^\/+/g, "");
        });
    });

  return copiedFiles;
}

function copyPlatformLogosToAssets() {
  const modulesDir = path.resolve(__dirname, "modules");
  const assetsDir = path.resolve(__dirname, "website/public/assets/logos");
  return copyFilesToAssets(modulesDir, assetsDir, (file) =>
    file.endsWith(".png") || file.endsWith(".svg")
  );
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

  return {
    id,
    platformType: platform,
    logo: buildingBlockLogoPath,
    buildingBlockUrl,
    backplaneUrl,
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
  const repoRoot = path.resolve(__dirname, "modules");

  const platformLogos = copyPlatformLogosToAssets();
  fs.writeFileSync(
    "website/public/assets/platform-logos.json",
    JSON.stringify(platformLogos, null, 2)
  );
  console.log(
    `✅ Successfully processed ${Object.entries(platformLogos).length} platform logos. Output saved to platform-logos.json`
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
