import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { Observable, map } from 'rxjs';

import { CardComponent } from '../card';
import { LogoCircleComponent } from '../logo-circle/logo-circle.component';
import { PlatformService } from '../platform-logo';

interface PlatformCard {
  cardLogo: string | null;
  title: string;
  routePath: string;
}

@Component({
  selector: 'mst-navigation',
  imports: [CommonModule, CardComponent, LogoCircleComponent],
  templateUrl: './navigation.component.html',
  styleUrl: './navigation.component.scss',
  standalone: true
})
export class NavigationComponent implements OnInit {
  public cards$!: Observable<PlatformCard[]>;

  constructor(private readonly platformService: PlatformService) {}

  public ngOnInit(): void {
    this.cards$ = this.platformService.getAllPlatformData()
      .pipe(
        map((logos) => this.mapLogosToPlatformCards(logos))
      );
  }

  private mapLogosToPlatformCards(logos: Record<string, { name: string; logo: string }>): PlatformCard[] {
    return Object.entries(logos)
      .map(([key, platform]) =>
        this.createPlatformCard(platform.name, platform.logo, `/platforms/${key}`)
      );
  }

  private createPlatformCard(title: string, logoUrl: string, routePath: string): PlatformCard {
    return { cardLogo: logoUrl, title, routePath };
  }
}
