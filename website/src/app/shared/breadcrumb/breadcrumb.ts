export interface BreadcrumbItem {
  label: string;
  routePath?: string; // optional, in case some breadcrumbs are not links
}