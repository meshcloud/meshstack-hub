export interface Template {
    name: string;
    id: string;
    description: string;
    platformType: PlatformType;
}

export type PlatformType = 'azure' | 'aws' | 'gcp';