export interface Platform {
  platformType: string;
  name: string;
  description: string;
  category?: 'hyperscaler' | 'european' | 'china' | 'devops' | 'private-cloud';
  logo: string;
  readme: string;
  terraformSnippet?: string;
}
