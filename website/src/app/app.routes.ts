import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: ':type', loadComponent: () => import('./features/template-gallery').then(m => m.TemplateGalleryComponent) },
  { path: '', loadComponent: () => import('./features/template-gallery').then(m => m.TemplateGalleryComponent) }
];