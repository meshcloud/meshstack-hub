export interface Template {
	name: string;
	id: string;
	logo: string;
	description: string;
	platformType: PlatformType;
	howToUse: string;
	githubUrls: {
		ssh: string;
		https: string;
	},
	supportedPlatforms: PlatformType[];
}

export type PlatformType = 'azure' | 'aws' | 'gcp' | 'github';