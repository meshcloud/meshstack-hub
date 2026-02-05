export interface DefinitionCard {
  cardLogo: string | null;
  title: string;
  description: string | null;
  routePath: string;
  supportedPlatforms: { platformType: string; imageUrl: string }[];
}
