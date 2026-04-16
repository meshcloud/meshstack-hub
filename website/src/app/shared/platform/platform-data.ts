export interface Platform {
  platformType: string;
  name: string;
  description: string;
  category?: 'hyperscaler' | 'european' | 'china' | 'devops' | 'private-cloud';
  benefits?: string[];
  logo: string;
  readme: string;
  integrationSourceUrl?: string | null;
  terraformSnippet?: string;
  official?: boolean;
}
