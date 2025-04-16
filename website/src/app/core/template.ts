export interface Template {
	name: string;
	id: string;
	logo: string;
	description: string;
	platformType: PlatformType;
	howToUse: string;
	buildingBlockUrl: string;
	backplaneUrl: string | null;
	supportedPlatforms: PlatformType[];
}

export type PlatformType = 'azure' | 'aws' | 'gcp' | 'github';