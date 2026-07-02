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
  sourceUrl: string | null;
  // True when this reference architecture ships its own meshstack_integration.tf and can be
  // imported into meshStack directly, the same way a building block is imported.
  hasCode: boolean;
  integrationSourceUrl: string | null;
  folderUrl: string | null;
  modulePath: string | null;
}

