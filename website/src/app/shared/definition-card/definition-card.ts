import { PlatformType } from 'app/core';

export interface DefinitionCard {
  cardLogo: string | null;
  title: string;
  description: string | null;
  routePath: string;
  supportedPlatforms: { platformType: PlatformType; imageUrl: string }[];
}