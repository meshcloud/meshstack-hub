import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: 'template/:id', loadComponent: () => import('./features/template-details').then(m => m.TemplateDetailsComponent) },
  { path: ':type', loadComponent: () => import('./features/template-gallery').then(m => m.TemplateGalleryComponent) },
  { path: '', redirectTo: '/all', pathMatch: 'full' }
];