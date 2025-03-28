import { PlatformType } from 'app/core';

export interface Card {
  cardLogo: string | null;
  title: string;
  description: string;
  detailsRoute: string;
  supportedPlatforms: { platformType: PlatformType; imageUrl: string }[];
}
