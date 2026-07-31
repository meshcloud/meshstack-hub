export interface ReferenceArchitectureBuildingBlock {
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
  // Own logo, when one is committed for this architecture. Null means the cloud provider logos
  // are shown instead.
  logo: string | null;
  sourceUrl: string | null;
  // Set when this reference architecture ships its own meshstack_integration.tf and can be
  // imported into meshStack directly, the same way a building block is imported.
  integrationSourceUrl: string | null;
  folderUrl: string | null;
  modulePath: string | null;
}

