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

export type PlatformType = 'aks' | 'aws' | 'azure' | 'azuredevops' | 'cloudfoundry' | 'datadog' | 'gcp' | 'github' | 'ionos' | 'kubernetes' | 'oci' | 'openshift' | 'openstack' | 'ovh' | 'sapbtp' | 'stackit' | 'tencentcloud';