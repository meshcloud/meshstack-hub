export interface Template {
    icon: string;
    name: string;
    id: string;
    description: string;
    platformType: PlatformType;
}

export type PlatformType = 'AZURE' | 'AWS' | 'GCP';