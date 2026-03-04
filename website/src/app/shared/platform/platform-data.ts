export interface Platform {
  platformType: string;
  name: string;
  description: string;
  category?: 'hyperscaler' | 'european' | 'china' | 'devops' | 'private-cloud';
  benefits?: string[];
  logo: string;
  readme: string;
  terraformSnippet?: string;
}
