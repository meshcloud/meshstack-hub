const fs = require("fs");
const path = require("path");
const matter = require("gray-matter");
const { execSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "modules");
const refArchRoot = path.resolve(__dirname, "reference-architectures");
const assetsDir = path.resolve(__dirname, "website/public/assets/logos");
const refArchAssetsDir = path.resolve(__dirname, "website/public/assets/reference-architecture-logos");
const refArchDiagramAssetsDir = path.resolve(__dirname, "website/public/assets/reference-architecture-diagrams");
const hubRef = getHubRef();

function getHubRef() {
  try {
    return execSync("git rev-parse HEAD")
      .toString()
      .trim();
  } catch {
    return "main";
  }
}

function getGitHubRemoteUrl() {
  try {
    const remoteUrl = execSync("git config --get remote.origin.url")
      .toString()
      .trim()
      .replace(/https?:\/\/.*?@github\.com\//, "https://github.com/")
      // scp-style SSH remotes (git@github.com:owner/repo) would otherwise leak into every
      // generated link, which breaks local runs of this script in an SSH clone.
      .replace(/^(?:ssh:\/\/)?git@github\.com[:/]/, "https://github.com/");
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
  return `${remoteUrl}/tree/${hubRef}/modules${relativePath}`;
}

// Directories that never contain hub modules but do contain vendored copies of them.
// `terraform init` mirrors the whole repo into `.terraform/modules/...`, so recursing into
// these would count every module once per initialized module directory.
function isIgnoredDir(name: string): boolean {
  return name.startsWith(".") || name === "node_modules";
}

function findReadmes(dir){
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((file) => {
    const fullPath = path.join(dir, file.name);
    if (file.isDirectory()) {
      return isIgnoredDir(file.name) ? [] : findReadmes(fullPath);
    }
    return file.name === "README.md" && dir.includes("buildingblock")
      ? [fullPath]
      : [];
  });
}

function findPlatforms(): Platform[] {
  fs.mkdirSync(assetsDir, { recursive: true });

  return fs.readdirSync(repoRoot, { withFileTypes: true })
    .filter((dirent) => dirent.isDirectory() && !isIgnoredDir(dirent.name))
    .map((dir) => {
      const platformDir: string = path.join(repoRoot, dir.name);
      const platformLogo = getPlatformLogoOrThrow(platformDir, dir.name);
      const platformReadme = getPlatformReadmeOrThrow(platformDir);
      const { name, description, category, benefits, content, official } = extractReadmeFrontMatter(platformReadme);
      const terraformSnippet = getTerraformSnippet(platformDir);
      const integrationSourceUrl = getPlatformIntegrationSourceUrl(platformDir);

      return {
        platformType: dir.name,
        name,
        description,
        category,
        benefits,
        logo: platformLogo,
        readme: content,
        integrationSourceUrl,
        terraformSnippet,
        official
      };
    });
}

function getPlatformIntegrationSourceUrl(platformDir: string): string | null {
  const remoteUrl = getGitHubRemoteUrl();
  if (!remoteUrl) return null;

  const tfFile = path.join(platformDir, "meshstack_integration.tf");
  if (!fs.existsSync(tfFile)) return null;

  const relativePath = platformDir
    .replace(path.resolve(__dirname, "modules"), "")
    .replace(/\\/g, "/");

  return `${remoteUrl}/blob/${hubRef}/modules${relativePath}/meshstack_integration.tf`;
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

function extractReadmeFrontMatter(platformReadme: string): { name: string; description: string; category?: string; benefits?: string[]; content: string; official: boolean } {
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
  const benefits = data.benefits;

  return {
    name,
    description,
    content,
    category,
    benefits,
    official: data.official === true
  }
}

function getTerraformSnippet(platformDir: string): string | null {
  const tfFile = path.join(platformDir, "meshstack_integration.tf");
  if (!fs.existsSync(tfFile)) return null;

  try {
    const renderTool = path.resolve(__dirname, "tools/render-meshstack-integration-tf/render-meshstack-integration-tf");
    return execSync(`${renderTool} ${tfFile}`, { encoding: "utf-8" });
  } catch (error) {
    console.error(`Error rendering terraform snippet for ${platformDir}:`, error.message);
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

// --- Reference Architectures ---

interface ReferenceArchitectureBuildingBlock {
  path: string;
  role: string;
}

export interface ReferenceArchitecture {
  id: string;
  name: string;
  description: string;
  cloudProviders: string[];
  buildingBlocks: ReferenceArchitectureBuildingBlock[];
  body: string;
  // Own logo, when one is committed for this architecture. Null means the website falls back
  // to the logos of the architecture's cloud providers.
  logo: string | null;
  sourceUrl: string | null;
  // Set when the reference architecture ships its own meshstack_integration.tf and can be
  // imported into meshStack directly, the same way a building block is imported.
  integrationSourceUrl: string | null;
  folderUrl: string | null;
  modulePath: string | null;
}

// Copies images referenced by relative markdown links into the website assets and rewrites the
// links to the served path. Diagrams are committed next to their README so a relative link renders
// on GitHub, but the website serves this body from its own origin where a repo-relative path
// resolves to nothing. Serving our own copy — rather than a github.com/raw link pinned to the built
// commit — also keeps diagrams rendering for commits that are not (yet) pushed, and for files that
// moved since the last commit.
function localizeImageLinks(body: string, archDir: string, id: string): string {
  return body.replace(
    /(!\[[^\]]*\]\()(?!https?:\/\/|\/|#)([^)\s]+)(\))/g,
    (match, prefix, target, suffix) => {
      const sourcePath = path.join(archDir, target.replace(/^\.\//, ""));
      if (!fs.existsSync(sourcePath)) {
        console.warn(`⚠️  Reference architecture ${id} links a missing image: ${target}`);
        return match;
      }

      const destDir = path.join(refArchDiagramAssetsDir, id);
      const fileName = path.basename(sourcePath);
      fs.mkdirSync(destDir, { recursive: true });
      fs.copyFileSync(sourcePath, path.join(destDir, fileName));

      return `${prefix}assets/reference-architecture-diagrams/${id}/${fileName}${suffix}`;
    }
  );
}

// Reference architectures colocate their logo as `logo.png|svg`, the same way a building block
// does. Copies it to the website assets under the architecture id and returns the served path.
function copyReferenceArchitectureLogoToAssets(archDir: string, id: string): string | null {
  const logoFile = ["logo.png", "logo.svg"]
    .find(file => fs.existsSync(path.join(archDir, file)));

  if (!logoFile) return null;

  fs.mkdirSync(refArchAssetsDir, { recursive: true });
  fs.copyFileSync(
    path.join(archDir, logoFile),
    path.join(refArchAssetsDir, `${id}${path.extname(logoFile)}`)
  );

  return `assets/reference-architecture-logos/${id}${path.extname(logoFile)}`;
}

// Parses a reference architecture from the `README.md` of its directory. The directory is also
// checked for a `meshstack_integration.tf` that makes this reference architecture importable,
// the same way a building block is imported.
function parseReferenceArchitecture(archDir: string, id: string): ReferenceArchitecture {
  const filePath = path.join(archDir, "README.md");
  const raw = fs.readFileSync(filePath, "utf-8");
  const { data, content } = matter(raw);
  const body = localizeImageLinks(content, archDir, id);

  if (!data.name) {
    throw new Error(`Reference architecture ${id} is missing "name" in front-matter.`);
  }
  if (!data.description) {
    throw new Error(`Reference architecture ${id} is missing "description" in front-matter.`);
  }
  if (!data.buildingBlocks || !Array.isArray(data.buildingBlocks)) {
    throw new Error(`Reference architecture ${id} is missing "buildingBlocks" list in front-matter.`);
  }

  const remoteUrl = getGitHubRemoteUrl();
  const relativeFilePath = filePath
    .replace(path.resolve(__dirname), "")
    .replace(/\\/g, "/");
  const sourceUrl = remoteUrl ? `${remoteUrl}/blob/${hubRef}${relativeFilePath}` : null;

  const hasCode = fs.existsSync(path.join(archDir, "meshstack_integration.tf"));
  const integrationSourceUrl = hasCode && remoteUrl
    ? `${remoteUrl}/blob/${hubRef}/reference-architectures/${id}/meshstack_integration.tf`
    : null;
  const folderUrl = hasCode && remoteUrl
    ? `${remoteUrl}/tree/${hubRef}/reference-architectures/${id}`
    : null;
  const modulePath = hasCode ? `reference-architectures/${id}` : null;

  return {
    id,
    name: data.name,
    description: data.description,
    cloudProviders: data.cloudProviders || [],
    buildingBlocks: data.buildingBlocks,
    body,
    logo: copyReferenceArchitectureLogoToAssets(archDir, id),
    sourceUrl,
    integrationSourceUrl,
    folderUrl,
    modulePath,
  };
}

function findReferenceArchitectures(): ReferenceArchitecture[] {
  if (!fs.existsSync(refArchRoot)) return [];

  // Every reference architecture is a directory named after its id, holding a README.md, an
  // optional logo and diagram, and optional code (meshstack_integration.tf + buildingblock/)
  // that can be imported into meshStack.
  return fs.readdirSync(refArchRoot, { withFileTypes: true })
    .filter(entry => entry.isDirectory() && !isIgnoredDir(entry.name))
    .flatMap((entry): ReferenceArchitecture[] => {
      const archDir = path.join(refArchRoot, entry.name);
      if (!fs.existsSync(path.join(archDir, "README.md"))) return [];

      return [parseReferenceArchitecture(archDir, entry.name)];
    });
}

// Main execution
function main() {
  const generatedDir = "website/src/generated";
  fs.mkdirSync(generatedDir, { recursive: true });

  const platforms = findPlatforms();
  fs.writeFileSync(
    `${generatedDir}/platform.json`,
    JSON.stringify(platforms, null, 2)
  );
  console.log(
    `✅ Successfully processed ${platforms.length} platforms. Output saved to ${generatedDir}/platform.json`
  );

  const readmeFiles = findReadmes(repoRoot);
  const jsonData = readmeFiles.map(parseReadme);
  fs.writeFileSync(
    `${generatedDir}/templates.json`,
    JSON.stringify({ templates: jsonData }, null, 2)
  );
  console.log(
    `✅ Successfully processed ${readmeFiles.length} README.md files. Output saved to ${generatedDir}/templates.json`
  );

  const refArchs = findReferenceArchitectures();
  fs.writeFileSync(
    `${generatedDir}/reference-architectures.json`,
    JSON.stringify({ referenceArchitectures: refArchs }, null, 2)
  );
  console.log(
    `✅ Successfully processed ${refArchs.length} reference architectures. Output saved to ${generatedDir}/reference-architectures.json`
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
  benefits?: string[];
  integrationSourceUrl?: string | null;
  terraformSnippet?: string;
  official?: boolean;
}
