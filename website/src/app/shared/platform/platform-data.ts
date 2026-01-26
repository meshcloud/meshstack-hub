export interface PlatformLogoData {
	[key: string]: string;
}

export interface PlatformData {
	[key: string]: Platform;
}

export interface Platform {
	name: string;
	logo: string;
	description?: string;
	category?: 'hyperscaler' | 'european' | 'china' | 'devops' | 'private-cloud';
}
