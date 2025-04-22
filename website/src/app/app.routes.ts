import { Routes } from '@angular/router';

const loadTemplateGallery = () => import('./features/template-gallery').then(m => m.TemplateGalleryComponent);
const loadTemplateDetails = () => import('./features/template-details').then(m => m.TemplateDetailsComponent);
const loadPlatformView = () => import('./features/platform-view').then(m => m.PlatformViewComponent);

export const routes: Routes = [
  {
    path: 'all',
    loadComponent: loadTemplateGallery
  },
  {
    path: 'platforms/:type',
    loadComponent: loadPlatformView,
  },
  {
    path: 'platforms/:type/definitions/:id',
    loadComponent: loadTemplateDetails
  },
  {
    path: 'definitions/:id',
    loadComponent: loadTemplateDetails
  },
  { path: '', redirectTo: '/all', pathMatch: 'full' },
];