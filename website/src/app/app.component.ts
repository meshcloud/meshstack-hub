import { CommonModule, isPlatformBrowser } from '@angular/common';
import { Component, Inject, PLATFORM_ID } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { NgbModule } from '@ng-bootstrap/ng-bootstrap';

import { HeaderComponent } from 'app/shared/header/header.component';

import { FooterComponent } from './shared/footer';

@Component({
  selector: 'mst-root',
  imports: [CommonModule, RouterOutlet, HeaderComponent, FooterComponent, NgbModule],
  templateUrl: './app.component.html',
  standalone: true
})
export class AppComponent {
  constructor(@Inject(PLATFORM_ID) private platformId: Object) {
    this.loadPlausible();
  }

  loadPlausible() {
    // Ensure we are in the browser (not SSR)
    if (isPlatformBrowser(this.platformId)) {
      const script = document.createElement('script');
      script.src = 'https://plausible.cluster.dev.meshcloud.io/js/script.js';
      script.setAttribute('data-domain', 'hub.meshcloud.io');
      script.defer = true;
      document.head.appendChild(script);
    }
  }
}
