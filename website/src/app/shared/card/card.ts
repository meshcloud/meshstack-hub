import { PlatformType } from 'app/core';

export interface Card {
  cardLogo: string | null;
  title: string;
  description: string | null;
  routePath: string;
  supportedPlatforms: { platformType: PlatformType; imageUrl: string }[];
}

export interface CardConfig {
  titleNextToLogo: boolean;
  showFooter: boolean;
  borderDominantColorOfLogo: boolean;
}
