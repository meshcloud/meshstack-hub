import { Routes } from '@angular/router';
import { AppComponent } from './app.component';

export const routes: Routes = [
    { path: ':type', loadComponent: () => import('./features/template-card-grid').then(m => m.TemplateOverviewComponent) },
];
