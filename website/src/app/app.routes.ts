import { Routes } from '@angular/router';

const loadTemplateGallery = () => import('./features/template-gallery').then(m => m.TemplateGalleryComponent);
const loadTemplateDetails = () => import('./features/template-details').then(m => m.TemplateDetailsComponent);
const loadPlatformView = () => import('./features/platform-view').then(m => m.PlatformViewComponent);
const loadPlatformIntegration = () => import('./features/platform-integration').then(m => m.PlatformIntegrationComponent);
const loadRefArchList = () => import('./features/reference-architecture-list').then(m => m.ReferenceArchitectureListComponent);
const loadRefArchDetail = () => import('./features/reference-architecture-detail').then(m => m.ReferenceArchitectureDetailComponent);

export const routes: Routes = [
  {
    path: '',
    loadComponent: loadTemplateGallery
  },
  {
    path: 'reference-architectures',
    loadComponent: loadRefArchList
  },
  {
    path: 'reference-architectures/:id',
    loadComponent: loadRefArchDetail
  },
  {
    path: 'platforms/:type',
    loadComponent: loadPlatformView,
  },
  {
    path: 'platforms/:type/integrate',
    loadComponent: loadPlatformIntegration
  },
  {
    path: 'platforms/:type/definitions/:id',
    loadComponent: loadTemplateDetails
  },
  {
    path: 'definitions/:id',
    loadComponent: loadTemplateDetails
  },
  { path: 'all', redirectTo: '', pathMatch: 'full' },
];
