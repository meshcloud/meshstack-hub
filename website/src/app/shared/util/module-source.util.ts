function sanitizeModuleName(modulePath: string): string | null {
  const moduleName = modulePath.split('/')
    .pop()
    ?.replace(/[^a-zA-Z0-9_]/g, '_');

  return moduleName ?? null;
}

export function extractHubModulePath(source: string): string | null {
  const modulesMarker = '/modules/';
  const modulesStart = source.indexOf(modulesMarker);

  if (modulesStart === -1) {
    return null;
  }

  const tail = source.slice(modulesStart + 1)
    .split(/[?#]/)[0];
  const segments = tail.split('/')
    .filter(Boolean);

  if (segments[0] !== 'modules' || segments.length < 2) {
    return null;
  }

  if (segments.length === 2 || segments[2].endsWith('.tf')) {
    return segments.slice(0, 2)
      .join('/');
  }

  return segments.slice(0, 3)
    .join('/');
}

export function extractHubGitRef(source: string): string | null {
  const treeMarker = '/tree/';
  const blobMarker = '/blob/';
  const modulesMarker = '/modules/';
  const treeIndex = source.indexOf(treeMarker);
  const blobIndex = source.indexOf(blobMarker);
  const markerIndex = treeIndex !== -1 ? treeIndex : blobIndex;
  const markerLength = treeIndex !== -1 ? treeMarker.length : blobMarker.length;

  if (markerIndex === -1) {
    return null;
  }

  const refStart = markerIndex + markerLength;
  const refEnd = source.indexOf(modulesMarker, refStart);

  if (refEnd === -1 || refEnd <= refStart) {
    return null;
  }

  return source.slice(refStart, refEnd);
}

export function buildHubModuleCodeSnippet(source: string | null | undefined): string | null {
  if (!source) {
    return null;
  }

  const modulePath = extractHubModulePath(source);
  const ref = extractHubGitRef(source);

  if (!modulePath || !ref) {
    return null;
  }

  const moduleName = sanitizeModuleName(modulePath);

  if (!moduleName) {
    return null;
  }

  return `module "${moduleName}" {
  source = "github.com/meshcloud/meshstack-hub//${modulePath}?ref=${ref}"
  # Define input variables here
}`;
}
