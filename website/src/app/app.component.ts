import { CommonModule, isPlatformBrowser } from '@angular/common';
import { Component, Inject, OnDestroy, PLATFORM_ID } from '@angular/core';
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
export class AppComponent implements OnDestroy{
  constructor(@Inject(PLATFORM_ID) private platformId: Object) {
    // Ensure we are in the browser (not SSR)
    if (isPlatformBrowser(this.platformId)) {
      this.loadPlausible();
      this.setupMessageListener();
    }
  }

  public ngOnDestroy(): void {
    this.removeMessageListener();
  }

  public loadPlausible() {
    const script = document.createElement('script');
    script.src = 'https://plausible.cluster.dev.meshcloud.io/js/script.js';
    script.setAttribute('data-domain', 'hub.meshcloud.io');
    script.defer = true;
    document.head.appendChild(script);
  }

  private setupMessageListener(): void {
    if (isPlatformBrowser(this.platformId)) {
      window.addEventListener('message', this.handleMessage.bind(this), false);
    }
  }

  private removeMessageListener(): void {
    if (isPlatformBrowser(this.platformId)) {
      window.removeEventListener('message', this.handleMessage.bind(this), false);
    }
  }

  private handleMessage(event: MessageEvent): void {
    const originUrl = event.data.originUrl;

    if (typeof originUrl === 'string') {
      localStorage.setItem('referrerUrl', originUrl);
    }
  }
}
