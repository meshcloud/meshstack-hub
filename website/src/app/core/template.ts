export interface Template {
	name: string;
	id: string;
	description: string;
	platformType: PlatformType;
	howToUse: string;
	githubUrls: {
		ssh: string;
		https: string;
	}
}

export type PlatformType = 'azure' | 'aws' | 'gcp';