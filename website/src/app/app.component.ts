import { CommonModule, isPlatformBrowser } from '@angular/common';
import { Component, HostListener, Inject, PLATFORM_ID } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { HeaderComponent } from 'app/shared/header/header.component';

import { ReferrerService } from './referrer.service';
import { FooterComponent } from './shared/footer';

@Component({
  selector: 'mst-root',
  imports: [CommonModule, RouterOutlet, HeaderComponent, FooterComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.scss',
  standalone: true
})
export class AppComponent {
  constructor(
    @Inject(PLATFORM_ID) private platformId: object,
    private referrerService: ReferrerService
  ) {
    // Ensure we are in the browser (not SSR)
    if (isPlatformBrowser(this.platformId)) {
      this.loadPlausible();
    }
  }

  public loadPlausible() {
    const script = document.createElement('script');
    script.src = 'https://plausible.cluster.dev.meshcloud.io/js/script.js';
    script.setAttribute('data-domain', 'hub.meshcloud.io');
    script.defer = true;
    document.head.appendChild(script);
  }

  @HostListener('window:message', ['$event'])
  public handleWindowMessage(event: MessageEvent): void {
    const originUrl = event.data.originUrl;

    if (typeof originUrl === 'string') {
      this.referrerService.saveMeshstackUrl(originUrl);
    }
  }
}
