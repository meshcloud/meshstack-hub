export interface Template {
    icon: string;
    name: string;
    id: string;
    description: string;
    type: PlatformType;
}

export type PlatformType = 'AZURE' | 'AWS' | 'GCP';