export interface PlatformCard {
    cardLogo: string | null;
    title: string;
    routePath: string;
    description?: string;
    buildingBlockCount?: number;
    category?: 'hyperscaler' | 'european' | 'china' | 'devops' | 'private-cloud';
  }
