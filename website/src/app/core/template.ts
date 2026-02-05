export interface Template {
	name: string;
	id: string;
	logo: string;
	description: string;
	platformType: string;
	howToUse: string;
	buildingBlockUrl: string;
	backplaneUrl: string | null;
	supportedPlatforms: string[];
}
