import { Routes } from '@angular/router';

const loadTemplateGallery = () => import('./features/template-gallery').then(m => m.TemplateGalleryComponent);
const loadTemplateDetails = () => import('./features/template-details').then(m => m.TemplateDetailsComponent);
const loadPlatformView = () => import('./features/platform-view').then(m => m.PlatformViewComponent);
const loadPlatformIntegration = () => import('./features/platform-integration').then(m => m.PlatformIntegrationComponent);

export const routes: Routes = [
  {
    path: '',
    loadComponent: loadTemplateGallery
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
