import { provideHttpClient, withFetch } from '@angular/common/http';
import { bootstrapApplication, provideClientHydration } from '@angular/platform-browser';
import { provideRouter } from '@angular/router';

import { AppComponent } from './app/app.component';
import { routes } from './app/app.routes';

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes), // Provide routes in the bootstrapping process
    provideHttpClient(withFetch()),
    provideClientHydration()
  ]
})
  .catch(err => console.error(err));
